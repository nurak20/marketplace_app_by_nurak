import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'profile_provider.dart';
import 'session_store.dart';

/// The app-wide API singleton. All feature screens use the same Dio client.
final Api api = Api.instance;

class Api {
  Api._()
    : dio = Dio(
        BaseOptions(baseUrl: _baseUrl, headers: {'Accept': 'application/json'}),
      ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = SessionStore.instance.token;
          if (token != null && !options.path.startsWith('/auth/')) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) {
          if (error.response?.statusCode == 401 &&
              !error.requestOptions.path.startsWith('/auth/')) {
            unawaited(SessionStore.instance.clear());
          }
          handler.next(error);
        },
      ),
    );
  }

  static final Api instance = Api._();
  static const _baseUrlKey = 'marketplace.api_base_url';
  final Dio dio;
  final Map<int, Future<String?>> _primaryProductImages = {};
  final Map<int, Future<UserProfile?>> _profileCache = {};

  static String get _baseUrl {
    const configured = String.fromEnvironment('API_BASE_URL');
    if (configured.isNotEmpty) return configured;
    return 'http://${!kIsWeb && defaultTargetPlatform == TargetPlatform.android ? '10.0.2.2' : 'localhost'}:8081/api/v1';
  }

  String get baseUrl => dio.options.baseUrl;

  Future<void> initialize() async {
    if (!kDebugMode) return;
    final preferences = await SharedPreferences.getInstance();
    final saved = preferences.getString(_baseUrlKey);
    final validSaved = saved == null ? null : validateBaseUrl(saved);
    if (validSaved != null) dio.options.baseUrl = validSaved;
  }

  Future<void> configureBaseUrl(String value) async {
    final validated = validateBaseUrl(value);
    if (validated == null) throw const FormatException('Invalid API URL');

    dio.options.baseUrl = validated;
    _primaryProductImages.clear();
    _profileCache.clear();

    if (kDebugMode) {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_baseUrlKey, validated);
    }
  }

  static String? validateBaseUrl(String value) {
    final trimmed = value.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri == null ||
        !const {'http', 'https'}.contains(uri.scheme.toLowerCase()) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      return null;
    }

    final path = uri.path.replaceFirst(RegExp(r'/+$'), '');
    return uri.replace(scheme: uri.scheme.toLowerCase(), path: path).toString();
  }

  String resolveUrl(String path) {
    if (path.startsWith('http')) return path;
    return Uri.parse(dio.options.baseUrl).resolve(path).toString();
  }

  Future<Object?> _request(Future<Response<dynamic>> Function() call) async =>
      _unwrap((await call()).data);

  Object? _unwrap(Object? value) =>
      value is Map && value.containsKey('data') ? value['data'] : value;

  Future<String> _token(String path, JsonMap body) async {
    final response = await dio.post(path, data: body);
    return '${_unwrap(response.data) is Map ? (_unwrap(response.data) as Map)['token'] : ''}';
  }

  Future<String> login(String email, String password) =>
      _token('/auth/login', {'email': email, 'password': password});

  Future<String> register({
    required String username,
    required String fullName,
    required String email,
    required String password,
  }) => _token('/auth/register', {
    'username': username,
    'fullName': fullName,
    'email': email,
    'password': password,
  });

  Future<Account> me() async {
    final account = Account.fromJson(
      asJsonMap(await _request(() => dio.get('/users/me'))),
    );
    profileProvider.setAccount(account);
    return account;
  }

  Future<Account> uploadAvatar(XFile image) async {
    final bytes = await image.readAsBytes();
    final response = await _request(
      () => dio.post(
        '/users/me/avatar',
        data: FormData.fromMap({
          'file': MultipartFile.fromBytes(bytes, filename: image.name),
        }),
      ),
    );
    final account = Account.fromJson(asJsonMap(response));
    profileProvider.setAccount(account);
    _profileCache.remove(account.profile.id);
    return account;
  }

  Future<JsonMap> profile(int userId) async =>
      asJsonMap(await _request(() => dio.get('/users/$userId')));

  Future<UserProfile?> profileSummary(int userId) =>
      _profileCache.putIfAbsent(userId, () async {
        try {
          return UserProfile.fromJson(await profile(userId));
        } catch (_) {
          return null;
        }
      });

  Future<ApiPage<Product>> products({
    String? keyword,
    String? category,
    int? sellerId,
  }) async {
    final query = <String, dynamic>{
      'page': 0,
      'size': 30,
      'sort': 'createdAt,desc',
    };
    if (keyword?.trim().isNotEmpty == true) query['keyword'] = keyword!.trim();
    if (category != null && category != 'All') query['category'] = category;
    if (sellerId != null) query['sellerId'] = sellerId;
    return ApiPage.fromJson(
      asJsonMap(
        await _request(() => dio.get('/products', queryParameters: query)),
      ),
      Product.fromJson,
    );
  }

  Future<Product> product(int id) async => Product.fromJson(
    asJsonMap(await _request(() => dio.get('/products/$id'))),
  );

  Future<Product> createProduct(JsonMap body) async => Product.fromJson(
    asJsonMap(await _request(() => dio.post('/products', data: body))),
  );

  Future<void> uploadProductImage(int productId, XFile image) async {
    final bytes = await image.readAsBytes();
    await _request(
      () => dio.post(
        '/products/$productId/images',
        data: FormData.fromMap({
          'file': MultipartFile.fromBytes(bytes, filename: image.name),
        }),
      ),
    );
    _primaryProductImages.remove(productId);
  }

  Future<void> setProductStatus(int id, String status) async {
    await _request(
      () => dio.patch('/products/$id/status', data: {'status': status}),
    );
  }

  Future<List<ProductImage>> images(int id) async =>
      ((await _request(() => dio.get('/products/$id/images')) as List?) ??
              const [])
          .whereType<Map>()
          .map((item) => ProductImage.fromJson(Map<String, dynamic>.from(item)))
          .toList();

  Future<String?> primaryProductImage(int productId) =>
      _primaryProductImages.putIfAbsent(productId, () async {
        try {
          final productImages = await images(productId);
          if (productImages.isEmpty) return null;
          return productImages
              .firstWhere(
                (image) => image.primary,
                orElse: () => productImages.first,
              )
              .url;
        } catch (_) {
          return null;
        }
      });

  Future<ApiPage<Review>> reviews(int id) async => ApiPage.fromJson(
    asJsonMap(
      await _request(
        () => dio.get(
          '/products/$id/reviews',
          queryParameters: {'page': 0, 'size': 30},
        ),
      ),
    ),
    Review.fromJson,
  );

  Future<ApiPage<MarketplacePost>> posts({int size = 50}) async =>
      ApiPage.fromJson(
        asJsonMap(
          await _request(
            () => dio.get(
              '/posts',
              queryParameters: {
                'page': 0,
                'size': size,
                'sort': 'createdAt,desc',
              },
            ),
          ),
        ),
        MarketplacePost.fromJson,
      );

  Future<void> reactToPost(int id) async {
    await _request(
      () => dio.put('/posts/$id/reaction', data: {'reactionType': 'LIKE'}),
    );
  }

  Future<void> unreactToPost(int id) async {
    await _request(() => dio.delete('/posts/$id/reaction'));
  }

  Future<void> reactToPostProduct(int postId, int productId) async {
    await _request(
      () => dio.put(
        '/posts/$postId/products/$productId/reaction',
        data: {'reactionType': 'LIKE'},
      ),
    );
  }

  Future<void> unreactToPostProduct(int postId, int productId) async {
    await _request(
      () => dio.delete('/posts/$postId/products/$productId/reaction'),
    );
  }

  Future<int?> postIdForProduct(int productId, int sellerId) async {
    final posts = ApiPage.fromJson(
      asJsonMap(
        await _request(
          () => dio.get(
            '/posts',
            queryParameters: {
              'userId': sellerId,
              'page': 0,
              'size': 100,
              'sort': 'createdAt,desc',
            },
          ),
        ),
      ),
      MarketplacePost.fromJson,
    );
    for (final post in posts.items) {
      if (post.products.any((product) => product.id == productId)) {
        return post.id;
      }
    }
    return null;
  }

  Future<void> createListingPost(List<int> productIds, String content) async {
    await _request(
      () => dio.post(
        '/posts',
        data: {'content': content, 'productIds': productIds},
      ),
    );
  }

  Future<ApiPage<PostComment>> postComments(int postId) async =>
      ApiPage.fromJson(
        asJsonMap(
          await _request(
            () => dio.get(
              '/posts/$postId/comments',
              queryParameters: {'page': 0, 'size': 50},
            ),
          ),
        ),
        PostComment.fromJson,
      );

  Future<ApiPage<PostComment>> productPostComments(
    int postId,
    int productId,
  ) async => ApiPage.fromJson(
    asJsonMap(
      await _request(
        () => dio.get(
          '/posts/$postId/products/$productId/comments',
          queryParameters: {'page': 0, 'size': 50},
        ),
      ),
    ),
    PostComment.fromJson,
  );

  Future<void> addPostComment(
    int postId,
    String content, {
    int? parentId,
  }) async {
    final body = <String, dynamic>{'content': content};
    if (parentId != null) body['parentId'] = parentId;
    await _request(() => dio.post('/posts/$postId/comments', data: body));
  }

  Future<void> addProductPostComment(
    int postId,
    int productId,
    String content, {
    int? parentId,
  }) async {
    final body = <String, dynamic>{'content': content};
    if (parentId != null) body['parentId'] = parentId;
    await _request(
      () => dio.post('/posts/$postId/products/$productId/comments', data: body),
    );
  }

  Future<void> addReview(int productId, int rating, String comment) async {
    await _request(
      () => dio.post(
        '/products/$productId/reviews',
        data: {'rating': rating, 'comment': comment},
      ),
    );
  }

  Future<ApiPage<Product>> wishlist() async => ApiPage.fromJson(
    asJsonMap(
      await _request(
        () => dio.get('/wishlist', queryParameters: {'page': 0, 'size': 30}),
      ),
    ),
    Product.fromJson,
  );

  Future<void> saveProduct(int id) async {
    await _request(() => dio.put('/wishlist/$id'));
  }

  Future<void> removeSavedProduct(int id) async {
    await _request(() => dio.delete('/wishlist/$id'));
  }

  Future<List<MarketplaceMessage>> inbox() async =>
      ((await _request(() => dio.get('/messages')) as List?) ?? const [])
          .whereType<Map>()
          .map(
            (item) =>
                MarketplaceMessage.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();

  Future<ApiPage<MarketplaceMessage>> conversation(int userId) async =>
      ApiPage.fromJson(
        asJsonMap(
          await _request(
            () => dio.get(
              '/messages/$userId',
              queryParameters: {
                'page': 0,
                'size': 100,
                'sort': 'createdAt,desc',
              },
            ),
          ),
        ),
        MarketplaceMessage.fromJson,
      );

  Future<void> sendMessage(int userId, String content, {int? productId}) async {
    final body = <String, dynamic>{'content': content};
    if (productId != null) body['productId'] = productId;
    await _request(() => dio.post('/messages/$userId', data: body));
  }

  Future<void> markConversationRead(int userId) async {
    await _request(() => dio.patch('/messages/$userId/read'));
  }

  Future<ApiPage<MarketplaceNotification>> notifications() async =>
      ApiPage.fromJson(
        asJsonMap(
          await _request(
            () => dio.get(
              '/notifications',
              queryParameters: {'page': 0, 'size': 30},
            ),
          ),
        ),
        MarketplaceNotification.fromJson,
      );

  Future<void> markNotificationRead(int id) async {
    await _request(() => dio.patch('/notifications/$id/read'));
  }

  static String errorMessage(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map) {
        final message = data['message'] ?? data['error'];
        if (message != null && '$message'.trim().isNotEmpty) {
          return '$message';
        }
      }
      if (data is String &&
          data.trim().isNotEmpty &&
          data.trim().length <= 180 &&
          !data.trimLeft().startsWith('<')) {
        return data.trim();
      }
      if (error.response == null) {
        return 'Could not connect to the marketplace API.';
      }
      final statusCode = error.response?.statusCode ?? 'unknown';
      return 'Request failed (HTTP $statusCode). Please try again.';
    }
    final detail = error.toString().trim();
    if (detail.isNotEmpty && !detail.startsWith('Instance of ')) {
      return detail.length <= 180 ? detail : '${detail.substring(0, 177)}...';
    }
    return 'Something went wrong. Please try again.';
  }
}
