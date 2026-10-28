import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'components/global_popup_dialog.dart';
import 'models.dart';
import 'singleton.dart';
import 'session_store.dart';

/// The app-wide API singleton. All feature screens use the same Dio client.
final Api api = Api.instance;

class Api {
  static const _loadingHandleExtra = '_marketplace_loading_handle';

  Api._() : dio = Dio(BaseOptions(headers: {'Accept': 'application/json'})) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = SessionStore.instance.token;
          if (token != null && !_isPublicAuthPath(options.path)) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          if (options.extra['loading'] != false) {
            final content = options.extra['loadingContent'];
            options.extra[_loadingHandleExtra] =
                GlobalPopupDialog.showRequestLoading(
                  content: content is String ? content : 'Loading....',
                );
          }
          handler.next(options);
        },
        onResponse: (response, handler) {
          _finishLoading(response.requestOptions);
          handler.next(response);
        },
        onError: (error, handler) {
          _finishLoading(error.requestOptions);
          if (error.response?.statusCode == 401 &&
              !_isPublicAuthPath(error.requestOptions.path)) {
            unawaited(SessionStore.instance.clear());
          }
          handler.next(error);
        },
      ),
    );
  }

  static const _publicAuthPaths = {'/auth/login', '/auth/register'};

  static bool _isPublicAuthPath(String path) => _publicAuthPaths.contains(path);

  void _finishLoading(RequestOptions options) {
    final handle = options.extra.remove(_loadingHandleExtra);
    if (handle is LoadingDialogHandle) handle.close();
  }

  static final Api instance = Api._();
  final Dio dio;
  List<String>? _marketplaceCategoryNames;
  List<String>? _marketplaceConditionCodes;

  String get baseUrl => dio.options.baseUrl;
  List<String>? get marketplaceCategoryNames => _marketplaceCategoryNames;
  List<String>? get marketplaceConditionCodes => _marketplaceConditionCodes;

  void updateMarketplaceCategoryNames(Iterable<String> names) {
    _marketplaceCategoryNames = names.toList(growable: false);
  }

  void updateMarketplaceConditionCodes(Iterable<String> codes) {
    _marketplaceConditionCodes = codes.toList(growable: false);
  }

  Future<void> initialize() async {
    final environmentBaseUrl = await _loadEnvironmentBaseUrl();
    final baseUrl = environmentBaseUrl == null
        ? null
        : validateBaseUrl(environmentBaseUrl);
    if (baseUrl == null) {
      throw const FormatException(
        'API_BASE_URL is missing or invalid in the root .env file.',
      );
    }
    dio.options.baseUrl = _androidHostAlias(baseUrl);
  }

  Future<String?> _loadEnvironmentBaseUrl() async {
    try {
      final contents = await rootBundle.loadString('.env');
      for (final line in contents.split(RegExp(r'\r?\n'))) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
        final separator = trimmed.indexOf('=');
        if (separator < 0 ||
            trimmed.substring(0, separator).trim() != 'API_BASE_URL') {
          continue;
        }
        var value = trimmed.substring(separator + 1).trim();
        if (value.length >= 2 &&
            ((value.startsWith('"') && value.endsWith('"')) ||
                (value.startsWith("'") && value.endsWith("'")))) {
          value = value.substring(1, value.length - 1).trim();
        }
        return value.isEmpty ? null : value;
      }
    } catch (_) {
      // Return null so initialize() can report a clear configuration error.
    }
    return null;
  }

  Future<void> configureBaseUrl(String value) async {
    final validated = validateBaseUrl(value);
    if (validated == null) throw const FormatException('Invalid API URL');

    dio.options.baseUrl = _androidHostAlias(validated);
  }

  /// The Android emulator reaches the host machine through 10.0.2.2, so a
  /// localhost base URL would otherwise point at the emulator itself.
  static String _androidHostAlias(String value) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return value;
    }
    final uri = Uri.tryParse(value);
    if (uri == null || (uri.host != 'localhost' && uri.host != '127.0.0.1')) {
      return value;
    }
    return uri.replace(host: '10.0.2.2').toString();
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
    Singleton.instance.setAccount(account);
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
    Singleton.instance.setAccount(account);
    return account;
  }

  Future<JsonMap> profile(int userId, {bool silent = false}) async => asJsonMap(
    await _request(
      () => dio.get(
        '/users/$userId',
        options: silent ? Options(extra: {'loading': false}) : null,
      ),
    ),
  );

  Future<Account> updateProfile({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
  }) async {
    final response = asJsonMap(
      await _request(
        () => dio.patch(
          '/users/me',
          data: {
            'firstName': firstName,
            'lastName': lastName,
            'email': email,
            'phone': phone,
          },
        ),
      ),
    );
    final account = Account.fromJson(
      asJsonMap(response['account'] ?? response),
    );
    final token = response['token'];
    if (token is String && token.isNotEmpty) {
      await SessionStore.instance.saveToken(token, notify: false);
    }
    Singleton.instance.setAccount(account);
    return account;
  }

  Future<ApiPage<Account>> managementUsers() async => ApiPage<Account>.fromJson(
    asJsonMap(
      await _request(
        () =>
            dio.get('/admin/users', queryParameters: {'page': 0, 'size': 100}),
      ),
    ),
    Account.fromJson,
  );

  Future<Account> createManagementUser({
    required String username,
    required String email,
    required String password,
    required String roleName,
    String? fullName,
  }) async => Account.fromJson(
    asJsonMap(
      await _request(
        () => dio.post(
          '/admin/users',
          data: {
            'username': username,
            'email': email,
            'password': password,
            'fullName': fullName,
            'roleName': roleName,
          },
        ),
      ),
    ),
  );

  Future<Account> setUserSelling(int userId, bool canSell) async =>
      Account.fromJson(
        asJsonMap(
          await _request(
            () => dio.patch(
              '/admin/users/$userId/selling',
              data: {'canSell': canSell},
            ),
          ),
        ),
      );

  Future<Account> setUserActive(int userId, bool active) async =>
      Account.fromJson(
        asJsonMap(
          await _request(
            () => dio.patch(
              '/admin/users/$userId/active',
              data: {'active': active},
            ),
          ),
        ),
      );

  Future<Account> setUserStaffRole(int userId, String roleName) async =>
      Account.fromJson(
        asJsonMap(
          await _request(
            () => dio.patch(
              '/admin/users/$userId/staff-role',
              data: {'roleName': roleName},
            ),
          ),
        ),
      );

  Future<List<ManagementCategory>> managementCategories() async =>
      _listResponse(
        await _request(() => dio.get('/admin/categories')),
        ManagementCategory.fromJson,
      );

  Future<ManagementCategory> createManagementCategory(String name) async =>
      ManagementCategory.fromJson(
        asJsonMap(
          await _request(
            () => dio.post('/admin/categories', data: {'name': name}),
          ),
        ),
      );

  Future<ManagementCategory> renameManagementCategory(
    int id,
    String name,
  ) async => ManagementCategory.fromJson(
    asJsonMap(
      await _request(
        () => dio.put('/admin/categories/$id', data: {'name': name}),
      ),
    ),
  );

  Future<ManagementCategory> setManagementCategoryActive(
    int id,
    bool active,
  ) async => ManagementCategory.fromJson(
    asJsonMap(
      await _request(
        () =>
            dio.patch('/admin/categories/$id/active', data: {'active': active}),
      ),
    ),
  );

  Future<ManagementCategory> archiveManagementCategory(int id) async =>
      ManagementCategory.fromJson(
        asJsonMap(await _request(() => dio.delete('/admin/categories/$id'))),
      );

  Future<ManagementCondition> createManagementCondition(String name) async =>
      ManagementCondition.fromJson(
        asJsonMap(
          await _request(
            () => dio.post('/admin/conditions', data: {'code': name}),
          ),
        ),
      );

  Future<List<ManagementCondition>> managementConditions() async =>
      _listResponse(
        await _request(() => dio.get('/admin/conditions')),
        ManagementCondition.fromJson,
      );

  Future<ManagementCondition> setManagementConditionActive(
    String code,
    bool active,
  ) async => ManagementCondition.fromJson(
    asJsonMap(
      await _request(
        () => dio.patch(
          '/admin/conditions/${Uri.encodeComponent(code)}/active',
          data: {'active': active},
        ),
      ),
    ),
  );

  Future<ManagementCondition> renameManagementCondition(
    String code,
    String name,
  ) async => ManagementCondition.fromJson(
    asJsonMap(
      await _request(
        () => dio.put(
          '/admin/conditions/${Uri.encodeComponent(code)}',
          data: {'code': name},
        ),
      ),
    ),
  );

  Future<ManagementCondition> archiveManagementCondition(String code) async =>
      ManagementCondition.fromJson(
        asJsonMap(
          await _request(
            () => dio.delete('/admin/conditions/${Uri.encodeComponent(code)}'),
          ),
        ),
      );

  Future<ApiPage<ManagementPost>> managementPosts() async =>
      ApiPage<ManagementPost>.fromJson(
        asJsonMap(
          await _request(
            () => dio.get(
              '/admin/posts',
              queryParameters: {
                'page': 0,
                'size': 100,
                'sort': 'createdAt,desc',
              },
            ),
          ),
        ),
        ManagementPost.fromJson,
      );

  Future<ManagementPost> setManagementPostAvailable(
    int postId,
    bool available,
  ) async => ManagementPost.fromJson(
    asJsonMap(
      await _request(
        () => dio.patch(
          '/admin/posts/$postId/availability',
          data: {'available': available},
        ),
      ),
    ),
  );

  List<T> _listResponse<T>(Object? response, T Function(JsonMap) parse) {
    Object? value = response;
    while (value is Map && value['data'] != null) {
      value = value['data'];
    }
    if (value is Map) {
      value = value['items'] ?? value['content'] ?? value['results'];
    }
    return (value as List? ?? const [])
        .whereType<Map>()
        .map((item) => parse(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<ApiPage<Product>> products({
    String? keyword,
    String? category,
    int? sellerId,
    String? status,
  }) async {
    final query = <String, dynamic>{
      'page': 0,
      'size': 30,
      'sort': 'createdAt,desc',
    };
    if (keyword?.trim().isNotEmpty == true) query['keyword'] = keyword!.trim();
    if (category != null && category != 'All') query['category'] = category;
    if (sellerId != null) query['sellerId'] = sellerId;
    if (status != null) query['status'] = status;
    final response = asJsonMap(
      await _request(
        () => dio.get(
          '/products',
          queryParameters: query,
          options: Options(extra: {'loading': false}),
        ),
      ),
    );
    _captureMarketplaceOptions(response);
    return ApiPage<Product>.fromJson(response, Product.fromJson);
  }

  Future<Product> product(int id, {int? postId}) async => Product.fromJson(
    asJsonMap(
      await _request(
        () => dio.get('/products/$id', queryParameters: {'postId': ?postId}),
      ),
    ),
  );

  Future<Product> createProduct(JsonMap body) async => Product.fromJson(
    asJsonMap(await _request(() => dio.post('/products', data: body))),
  );

  Future<MarketplaceOptions> marketplaceOptions() async {
    final options = MarketplaceOptions.fromJson(
      asJsonMap(await _request(() => dio.get('/marketplace/options'))),
    );
    _marketplaceCategoryNames = options.categories;
    _marketplaceConditionCodes = options.conditions;
    return options;
  }

  Future<MarketplaceImage?> uploadProductImage(
    int productId,
    XFile image,
  ) async {
    final bytes = await image.readAsBytes();
    final response = await _request(
      () => dio.post(
        '/products/$productId/images',
        data: FormData.fromMap({
          'file': MultipartFile.fromBytes(bytes, filename: image.name),
        }),
      ),
    );
    return MarketplaceImage.fromResponse(response);
  }

  Future<void> setProductStatus(int id, String status) async {
    await _request(
      () => dio.patch('/products/$id/status', data: {'status': status}),
    );
  }

  Future<List<MarketplaceImage>> images(int id) async =>
      MarketplaceImage.listFromResponse(
        await _request(
          () => dio.get(
            '/products/$id/images',
            options: Options(extra: {'loading': false}),
          ),
        ),
      );

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

  Future<ApiPage<MarketplacePost>> posts({int size = 50, int? userId}) async {
    final query = <String, dynamic>{
      'page': 0,
      'size': size,
      'sort': 'createdAt,desc',
    };
    if (userId != null) query['userId'] = userId;
    final response = asJsonMap(
      await _request(() => dio.get('/posts', queryParameters: query)),
    );
    _captureMarketplaceOptions(response);
    return ApiPage<MarketplacePost>.fromJson(
      response,
      MarketplacePost.fromJson,
    );
  }

  void _captureMarketplaceOptions(JsonMap response) {
    final categories = response['categories'];
    final conditions = response['conditions'];
    if (categories is List) {
      _marketplaceCategoryNames = categories.map((value) => '$value').toList();
    }
    if (conditions is List) {
      _marketplaceConditionCodes = conditions.map((value) => '$value').toList();
    }
  }

  Future<MarketplacePost> post(int id) async => MarketplacePost.fromJson(
    asJsonMap(await _request(() => dio.get('/posts/$id'))),
  );

  Future<void> reactToPost(int id) async {
    await _request(
      () => dio.put(
        '/posts/$id/reaction',
        data: {'reactionType': 'LIKE'},
        options: Options(extra: {'loading': false}),
      ),
    );
  }

  Future<void> unreactToPost(int id) async {
    await _request(
      () => dio.delete(
        '/posts/$id/reaction',
        options: Options(extra: {'loading': false}),
      ),
    );
  }

  Future<void> reactToPostProduct(int postId, int productId) async {
    await _request(
      () => dio.put(
        '/posts/$postId/products/$productId/reaction',
        data: {'reactionType': 'LIKE'},
        options: Options(extra: {'loading': false}),
      ),
    );
  }

  Future<void> unreactToPostProduct(int postId, int productId) async {
    await _request(
      () => dio.delete(
        '/posts/$postId/products/$productId/reaction',
        options: Options(extra: {'loading': false}),
      ),
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

  Future<MarketplacePost> createListing(
    JsonMap payload,
    List<({String name, Uint8List bytes})> images,
  ) async {
    final form = FormData();
    form.files.add(
      MapEntry(
        'payload',
        MultipartFile.fromString(
          jsonEncode(payload),
          contentType: DioMediaType.parse('application/json'),
        ),
      ),
    );
    for (final image in images) {
      form.files.add(
        MapEntry(
          'files',
          MultipartFile.fromBytes(image.bytes, filename: image.name),
        ),
      );
    }

    return MarketplacePost.fromJson(
      asJsonMap(await _request(() => dio.post('/posts/listing', data: form))),
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

  Future<ApiPage<Product>> wishlist() async {
    return ApiPage<Product>.fromJson(
      asJsonMap(
        await _request(
          () => dio.get('/wishlist', queryParameters: {'page': 0, 'size': 30}),
        ),
      ),
      Product.fromJson,
    );
  }

  Future<void> saveProduct(int id) async {
    await _request(() => dio.put('/wishlist/$id'));
  }

  Future<void> removeSavedProduct(int id) async {
    await _request(() => dio.delete('/wishlist/$id'));
  }

  Future<List<MarketplaceMessage>> inbox() async =>
      ((await _request(
                    () => dio.get(
                      '/messages',
                      options: Options(extra: {'loading': false}),
                    ),
                  )
                  as List?) ??
              const [])
          .whereType<Map>()
          .map(
            (item) =>
                MarketplaceMessage.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();

  Future<ApiPage<MarketplaceMessage>> conversation(
    int userId, {
    bool silent = false,
  }) async => ApiPage.fromJson(
    asJsonMap(
      await _request(
        () => dio.get(
          '/messages/$userId',
          queryParameters: {'page': 0, 'size': 100, 'sort': 'createdAt,desc'},
          options: silent ? Options(extra: {'loading': false}) : null,
        ),
      ),
    ),
    MarketplaceMessage.fromJson,
  );

  Future<void> sendMessage(int userId, String content, {int? productId}) async {
    final body = <String, dynamic>{'content': content};
    if (productId != null) body['productId'] = productId;
    await _request(
      () => dio.post(
        '/messages/$userId',
        data: body,
        options: Options(extra: {'loading': false}),
      ),
    );
  }

  Future<void> markConversationRead(int userId) async {
    await _request(() => dio.patch('/messages/$userId/read'));
  }

  Future<ApiPage<MarketplaceNotification>> notifications({
    int size = 50,
    bool silent = false,
  }) async => ApiPage.fromJson(
    asJsonMap(
      await _request(
        () => dio.get(
          '/notifications',
          queryParameters: {'page': 0, 'size': size},
          options: silent ? Options(extra: {'loading': false}) : null,
        ),
      ),
    ),
    MarketplaceNotification.fromJson,
  );

  Future<int> unreadNotificationCount({bool silent = false}) async {
    final data = asJsonMap(
      await _request(
        () => dio.get(
          '/notifications/unread-count',
          options: silent ? Options(extra: {'loading': false}) : null,
        ),
      ),
    );
    final count = data['count'];
    return count is num ? count.toInt() : int.tryParse('$count') ?? 0;
  }

  Future<void> markNotificationRead(int id, {bool silent = false}) async {
    await _request(
      () => dio.patch(
        '/notifications/$id/read',
        options: silent ? Options(extra: {'loading': false}) : null,
      ),
    );
  }

  Future<void> markAllNotificationsRead({bool silent = false}) async {
    await _request(
      () => dio.patch(
        '/notifications/read-all',
        options: silent ? Options(extra: {'loading': false}) : null,
      ),
    );
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _request(
      () => dio.post(
        '/auth/change-password',
        data: {'currentPassword': currentPassword, 'newPassword': newPassword},
      ),
    );
  }

  // ── Payroll ────────────────────────────────────────────────────────────────

  Future<ApiPage<EmployeeProfile>> payrollEmployees({
    String? status,
    String? department,
    String? query,
  }) async {
    final params = <String, dynamic>{
      'page': 0,
      'size': 100,
      'sort': 'employeeCode,asc',
    };
    if (status != null && status.isNotEmpty && status != 'ALL') {
      params['status'] = status;
    }
    if (department?.trim().isNotEmpty == true) {
      params['department'] = department!.trim();
    }
    if (query?.trim().isNotEmpty == true) params['q'] = query!.trim();
    return ApiPage<EmployeeProfile>.fromJson(
      asJsonMap(
        await _request(
          () => dio.get(
            '/payroll/employees',
            queryParameters: params,
            options: Options(extra: {'loading': false}),
          ),
        ),
      ),
      EmployeeProfile.fromJson,
    );
  }

  Future<EmployeeProfile> payrollEmployee(int userId) async =>
      EmployeeProfile.fromJson(
        asJsonMap(
          await _request(
            () => dio.get(
              '/payroll/employees/$userId',
              options: Options(extra: {'loading': false}),
            ),
          ),
        ),
      );

  Future<EmployeeProfile> enrollPayrollEmployee(JsonMap body) async =>
      EmployeeProfile.fromJson(
        asJsonMap(
          await _request(() => dio.post('/payroll/employees', data: body)),
        ),
      );

  Future<EmployeeProfile> updatePayrollEmployee(
    int userId,
    JsonMap body,
  ) async => EmployeeProfile.fromJson(
    asJsonMap(
      await _request(() => dio.put('/payroll/employees/$userId', data: body)),
    ),
  );

  Future<EmployeeProfile> setPayrollEmployeeStatus(
    int userId,
    String status,
  ) async => EmployeeProfile.fromJson(
    asJsonMap(
      await _request(
        () => dio.patch(
          '/payroll/employees/$userId/status',
          data: {'status': status},
        ),
      ),
    ),
  );

  Future<ApiPage<PayrollRun>> payrollRuns() async =>
      ApiPage<PayrollRun>.fromJson(
        asJsonMap(
          await _request(
            () => dio.get(
              '/payroll/runs',
              queryParameters: {'page': 0, 'size': 100, 'sort': 'id,desc'},
              options: Options(extra: {'loading': false}),
            ),
          ),
        ),
        PayrollRun.fromJson,
      );

  Future<PayrollRun> payrollRun(int id) async => PayrollRun.fromJson(
    asJsonMap(
      await _request(
        () => dio.get(
          '/payroll/runs/$id',
          options: Options(extra: {'loading': false}),
        ),
      ),
    ),
  );

  Future<PayrollRun> createPayrollRun(JsonMap body) async =>
      PayrollRun.fromJson(
        asJsonMap(await _request(() => dio.post('/payroll/runs', data: body))),
      );

  Future<PayrollRun> regeneratePayrollRun(int id) async => PayrollRun.fromJson(
    asJsonMap(await _request(() => dio.post('/payroll/runs/$id/regenerate'))),
  );

  Future<ApiPage<Payslip>> payrollRunPayslips(int runId) async =>
      ApiPage<Payslip>.fromJson(
        asJsonMap(
          await _request(
            () => dio.get(
              '/payroll/runs/$runId/payslips',
              queryParameters: {'page': 0, 'size': 200},
              options: Options(extra: {'loading': false}),
            ),
          ),
        ),
        Payslip.fromJson,
      );

  Future<Payslip> payrollPayslip(int id) async => Payslip.fromJson(
    asJsonMap(
      await _request(
        () => dio.get(
          '/payroll/payslips/$id',
          options: Options(extra: {'loading': false}),
        ),
      ),
    ),
  );

  Future<Payslip> updatePayrollPayslip(int id, JsonMap body) async =>
      Payslip.fromJson(
        asJsonMap(
          await _request(() => dio.patch('/payroll/payslips/$id', data: body)),
        ),
      );

  Future<PayrollRun> approvePayrollRun(int id) async => PayrollRun.fromJson(
    asJsonMap(await _request(() => dio.post('/payroll/runs/$id/approve'))),
  );

  Future<PayrollRun> payPayrollRun(int id) async => PayrollRun.fromJson(
    asJsonMap(await _request(() => dio.post('/payroll/runs/$id/pay'))),
  );

  Future<PayrollRun> cancelPayrollRun(int id) async => PayrollRun.fromJson(
    asJsonMap(await _request(() => dio.post('/payroll/runs/$id/cancel'))),
  );

  Future<EmployeeProfile> myPayrollProfile() async => EmployeeProfile.fromJson(
    asJsonMap(
      await _request(
        () => dio.get(
          '/payroll/me/profile',
          options: Options(extra: {'loading': false}),
        ),
      ),
    ),
  );

  Future<ApiPage<Payslip>> myPayslips() async => ApiPage<Payslip>.fromJson(
    asJsonMap(
      await _request(
        () => dio.get(
          '/payroll/me/payslips',
          queryParameters: {'page': 0, 'size': 100, 'sort': 'id,desc'},
          options: Options(extra: {'loading': false}),
        ),
      ),
    ),
    Payslip.fromJson,
  );

  Future<Payslip> myPayslip(int id) async => Payslip.fromJson(
    asJsonMap(
      await _request(
        () => dio.get(
          '/payroll/me/payslips/$id',
          options: Options(extra: {'loading': false}),
        ),
      ),
    ),
  );

  // ── Reports ────────────────────────────────────────────────────────────────

  List<T> _reportList<T>(Object? value, T Function(JsonMap) parse) =>
      (value as List? ?? const [])
          .whereType<Map>()
          .map((item) => parse(asJsonMap(item)))
          .toList();

  Future<Object?> _report(String path, [Map<String, dynamic>? query]) =>
      _request(
        () => dio.get(
          path,
          queryParameters: query,
          options: Options(extra: {'loading': false}),
        ),
      );

  Future<ReportOverview> reportOverview() async =>
      ReportOverview.fromJson(asJsonMap(await _report('/reports/overview')));

  Future<List<ProductStatusReport>> reportProductStatus() async => _reportList(
    await _report('/reports/product-status'),
    ProductStatusReport.fromJson,
  );

  Future<List<CategoryReport>> reportCategories() async => _reportList(
    await _report('/reports/categories'),
    CategoryReport.fromJson,
  );

  Future<List<MonthlyActivityReport>> reportMonthlyActivity({
    int months = 12,
  }) async => _reportList(
    await _report('/reports/monthly-activity', {'months': months}),
    MonthlyActivityReport.fromJson,
  );

  Future<List<EngagementReport>> reportEngagement({int months = 12}) async =>
      _reportList(
        await _report('/reports/engagement', {'months': months}),
        EngagementReport.fromJson,
      );

  Future<List<TopSellerReport>> reportTopSellers({int limit = 8}) async =>
      _reportList(
        await _report('/reports/top-sellers', {'limit': limit}),
        TopSellerReport.fromJson,
      );

  Future<List<PayrollDepartmentReport>> reportPayrollDepartments() async =>
      _reportList(
        await _report('/reports/payroll/departments'),
        PayrollDepartmentReport.fromJson,
      );

  Future<List<PayrollRunReport>> reportPayrollRuns({int limit = 12}) async =>
      _reportList(
        await _report('/reports/payroll/runs', {'limit': limit}),
        PayrollRunReport.fromJson,
      );

  Future<List<HeadcountReport>> reportHeadcount() async => _reportList(
    await _report('/reports/payroll/headcount'),
    HeadcountReport.fromJson,
  );

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
