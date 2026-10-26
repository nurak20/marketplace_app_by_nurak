typedef JsonMap = Map<String, dynamic>;

int _int(Object? value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;
double _double(Object? value) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

class ApiPage<T> {
  const ApiPage({required this.items, this.page = 0, this.totalPages = 0});
  final List<T> items;
  final int page;
  final int totalPages;

  ApiPage<T> withItems(List<T> value) =>
      ApiPage<T>(items: value, page: page, totalPages: totalPages);

  factory ApiPage.fromJson(JsonMap json, T Function(JsonMap) parse) {
    var payload = json;
    while (payload['data'] is Map) {
      payload = Map<String, dynamic>.from(payload['data'] as Map);
    }

    final pageable = payload['pageable'] is Map
        ? Map<String, dynamic>.from(payload['pageable'] as Map)
        : const <String, dynamic>{};
    final rawItems =
        payload['items'] ?? payload['content'] ?? payload['results'];

    return ApiPage<T>(
      items: (rawItems as List? ?? const [])
          .whereType<Map>()
          .map((item) => parse(Map<String, dynamic>.from(item)))
          .toList(),
      page: _int(
        payload['page'] ?? payload['number'] ?? pageable['pageNumber'],
      ),
      totalPages: _int(payload['totalPages']),
    );
  }
}

class Product {
  const Product({
    required this.id,
    required this.sellerId,
    required this.title,
    required this.price,
    required this.status,
    this.description,
    this.category,
    this.condition = 'GOOD',
    this.location,
    this.images = const [],
    this.seller,
    this.isSaved = false,
  });

  final int id;
  final int sellerId;
  final String title;
  final double price;
  final String status;
  final String? description;
  final String? category;
  final String condition;
  final String? location;
  final List<MarketplaceImage> images;
  final UserProfile? seller;
  final bool isSaved;

  MarketplaceImage? get primaryImage {
    for (final image in images) {
      if (image.label.toLowerCase() == 'primary' && image.url.isNotEmpty) {
        return image;
      }
    }
    for (final image in images) {
      if (image.url.isNotEmpty) return image;
    }
    return null;
  }

  factory Product.fromJson(JsonMap json) => Product(
    id: _int(json['id']),
    sellerId: _int(json['sellerId']),
    title: '${json['title'] ?? ''}',
    price: _double(json['price']),
    status: '${json['status'] ?? 'AVAILABLE'}',
    description: json['description'] as String?,
    category: json['category'] as String?,
    condition: '${json['condition'] ?? 'GOOD'}',
    location: json['location'] as String?,
    images: _productImagesFromJson(json),
    seller: (json['seller'] ?? json['user']) is Map
        ? UserProfile.fromJson(
            Map<String, dynamic>.from((json['seller'] ?? json['user']) as Map),
          )
        : null,
    isSaved: json['isSaved'] == true,
  );
}

List<MarketplaceImage> _productImagesFromJson(JsonMap json) {
  final images = MarketplaceImage.listFromResponse(json['images']);
  final direct = MarketplaceImage.tryParse(
    json['image'] ?? json['imageUrl'] ?? json['primaryImageUrl'],
    type: '${json['imageType'] ?? json['type'] ?? ''}',
    label: '${json['label'] ?? 'primary'}',
  );
  if (direct != null && !images.any((image) => image.url == direct.url)) {
    images.insert(0, direct);
  }
  final primaryIndex = images.indexWhere(
    (image) => image.label.toLowerCase() == 'primary',
  );
  if (primaryIndex > 0) images.insert(0, images.removeAt(primaryIndex));
  return images;
}

class MarketplaceImage {
  const MarketplaceImage({
    required this.url,
    required this.type,
    required this.label,
  });

  final String url;
  final String type;
  final String label;

  factory MarketplaceImage.fromJson(JsonMap json) {
    final url = '${json['url'] ?? json['imageUrl'] ?? ''}'.trim();
    return MarketplaceImage(
      url: url,
      type: _imageType(
        json['type'] ?? json['mimeType'] ?? json['contentType'],
        url,
      ),
      label: '${json['label'] ?? (json['isPrimary'] == true ? 'primary' : '')}',
    );
  }

  static MarketplaceImage? tryParse(
    Object? value, {
    String type = '',
    String label = '',
  }) {
    if (value is Map) {
      final image = MarketplaceImage.fromJson(Map<String, dynamic>.from(value));
      return MarketplaceImage(
        url: image.url,
        type: image.type.isNotEmpty ? image.type : _imageType(type, image.url),
        label: image.label.isNotEmpty ? image.label : label,
      );
    }
    if (value is String && value.trim().isNotEmpty) {
      final url = value.trim();
      return MarketplaceImage(
        url: url,
        type: _imageType(type, url),
        label: label,
      );
    }
    return null;
  }

  static MarketplaceImage? fromResponse(Object? value) {
    if (value is Map) {
      final json = Map<String, dynamic>.from(value);
      for (final key in const ['image', 'item']) {
        if (json[key] != null &&
            json['url'] == null &&
            json['imageUrl'] == null) {
          return fromResponse(json[key]);
        }
      }
      for (final key in const ['images', 'items']) {
        final items = json[key];
        if (items is List && items.isNotEmpty) return fromResponse(items.first);
        if (items is Map) return fromResponse(items);
      }
      final image = tryParse(json);
      if (image == null || image.url.isEmpty) return null;
      return image;
    }
    return tryParse(value);
  }

  static List<MarketplaceImage> listFromResponse(Object? value) {
    if (value is List) {
      return value.map(fromResponse).whereType<MarketplaceImage>().toList();
    }
    if (value is Map) {
      final json = Map<String, dynamic>.from(value);
      for (final key in const ['images', 'items']) {
        if (json[key] != null) return listFromResponse(json[key]);
      }
      final image = fromResponse(json);
      return image == null || image.url.isEmpty ? [] : [image];
    }
    return [];
  }

  JsonMap toJson() => {'url': url, 'type': type, 'label': label};
}

String _imageType(Object? value, String url) {
  final type = value is String ? value.trim() : '';
  if (type.isNotEmpty) return type;
  final path = Uri.tryParse(url)?.path ?? url.split('?').first;
  final dot = path.lastIndexOf('.');
  return dot < 0 ? '' : path.substring(dot + 1).toLowerCase();
}

class Review {
  const Review({
    required this.id,
    required this.rating,
    this.comment,
    this.buyerId = 0,
  });
  final int id;
  final int rating;
  final int buyerId;
  final String? comment;

  factory Review.fromJson(JsonMap json) => Review(
    id: _int(json['id']),
    rating: _int(json['rating']),
    buyerId: _int(json['buyerId']),
    comment: json['comment'] as String?,
  );
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.username,
    this.fullName,
    this.avatar,
    this.location,
    this.bio,
    this.email,
    this.phone,
  });
  final int id;
  final String username;
  final String? fullName;
  final MarketplaceImage? avatar;
  final String? location;
  final String? bio;
  final String? email;
  final String? phone;

  String get displayName {
    final name = fullName?.trim();
    if (name?.isNotEmpty == true) return name!;
    final handle = username.trim();
    return handle.isNotEmpty ? handle : 'Member #$id';
  }

  factory UserProfile.fromJson(JsonMap json) {
    final nestedProfile = json['profile'] ?? json['user'];
    final profile = nestedProfile is Map
        ? Map<String, dynamic>.from(nestedProfile)
        : json;
    return UserProfile(
      id: _int(profile['id']),
      username: '${profile['username'] ?? ''}',
      fullName: profile['fullName'] as String?,
      avatar: MarketplaceImage.tryParse(
        profile['avatar'] ?? profile['avatarUrl'],
        type: '${profile['avatarType'] ?? ''}',
        label: 'avatar',
      ),
      location: profile['location'] as String?,
      bio: profile['bio'] as String?,
      email: profile['email'] as String?,
      phone: profile['phone'] as String?,
    );
  }
}

class Account {
  const Account({
    required this.profile,
    this.email,
    this.phone,
    this.roles = const [],
  });
  final UserProfile profile;
  final String? email;
  final String? phone;
  final List<String> roles;

  factory Account.fromJson(JsonMap json) => Account(
    profile: UserProfile.fromJson(
      Map<String, dynamic>.from(json['profile'] as Map? ?? const {}),
    ),
    email: json['email'] as String?,
    phone: json['phone'] as String?,
    roles: (json['roles'] as List? ?? const []).map((role) => '$role').toList(),
  );
}

class MarketplaceMessage {
  const MarketplaceMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.content,
    this.productId,
    this.isRead = false,
    this.sender,
    this.receiver,
    this.product,
  });
  final int id;
  final int senderId;
  final int receiverId;
  final int? productId;
  final String content;
  final bool isRead;
  final UserProfile? sender;
  final UserProfile? receiver;
  final Product? product;

  UserProfile? contactFor(int userId) => senderId == userId ? receiver : sender;

  factory MarketplaceMessage.fromJson(JsonMap json) {
    final sender = json['sender'] ?? json['senderProfile'];
    final receiver = json['receiver'] ?? json['receiverProfile'];
    final product = json['product'];
    return MarketplaceMessage(
      id: _int(json['id']),
      senderId: _int(json['senderId']),
      receiverId: _int(json['receiverId']),
      productId: json['productId'] == null ? null : _int(json['productId']),
      content: '${json['content'] ?? ''}',
      isRead: json['isRead'] == true,
      sender: sender is Map
          ? UserProfile.fromJson(Map<String, dynamic>.from(sender))
          : null,
      receiver: receiver is Map
          ? UserProfile.fromJson(Map<String, dynamic>.from(receiver))
          : null,
      product: product is Map
          ? Product.fromJson(Map<String, dynamic>.from(product))
          : null,
    );
  }
}

class MarketplaceNotification {
  const MarketplaceNotification({
    required this.id,
    required this.type,
    required this.message,
    required this.isRead,
    this.refId,
  });
  final int id;
  final String type;
  final String message;
  final bool isRead;
  final int? refId;

  MarketplaceNotification withRead(bool value) => MarketplaceNotification(
    id: id,
    type: type,
    message: message,
    isRead: value,
    refId: refId,
  );

  factory MarketplaceNotification.fromJson(JsonMap json) =>
      MarketplaceNotification(
        id: _int(json['id']),
        type: '${json['type'] ?? ''}',
        message: '${json['message'] ?? ''}',
        isRead: json['isRead'] == true,
        refId: json['refId'] == null ? null : _int(json['refId']),
      );
}

class MarketplacePost {
  const MarketplacePost({
    required this.id,
    required this.userId,
    required this.products,
    this.createdAt,
    this.content,
    this.reactionCount = 0,
    this.commentCount = 0,
    this.hasReacted = false,
    this.productEngagements = const {},
    this.seller,
  });
  final int id;
  final int userId;
  final List<Product> products;
  final DateTime? createdAt;
  final String? content;
  final int reactionCount;
  final int commentCount;
  final bool hasReacted;
  final Map<int, ProductEngagement> productEngagements;
  final UserProfile? seller;

  ProductEngagement engagementFor(Product product) =>
      productEngagements[product.id] ?? const ProductEngagement();

  MarketplacePost withProducts(List<Product> value) => MarketplacePost(
    id: id,
    userId: userId,
    products: value,
    createdAt: createdAt,
    content: content,
    reactionCount: reactionCount,
    commentCount: commentCount,
    hasReacted: hasReacted,
    productEngagements: productEngagements,
    seller: seller,
  );

  factory MarketplacePost.fromJson(JsonMap json) {
    final post = json['post'] is Map
        ? Map<String, dynamic>.from(json['post'] as Map)
        : json;
    final seller =
        json['seller'] ??
        json['user'] ??
        post['seller'] ??
        post['user'] ??
        post['profile'];
    final rawCreatedAt = json['createdAt'] ?? post['createdAt'];
    return MarketplacePost(
      id: _int(post['id']),
      userId: _int(post['userId']),
      content: post['content'] as String?,
      createdAt: rawCreatedAt == null
          ? null
          : DateTime.tryParse('$rawCreatedAt')?.toLocal(),
      reactionCount: _int(json['reactionCount']),
      commentCount: _int(json['commentCount']),
      hasReacted: json['hasReacted'] == true,
      seller: seller is Map
          ? UserProfile.fromJson(Map<String, dynamic>.from(seller))
          : null,
      productEngagements: {
        for (final item
            in ((json['productEngagements'] as List?) ?? const [])
                .whereType<Map>()
                .map(
                  (item) => ProductEngagement.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                ))
          item.productId: item,
      },
      products: ((json['products'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => Product.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
    );
  }
}

class ProductEngagement {
  const ProductEngagement({
    this.productId = 0,
    this.reactionCount = 0,
    this.commentCount = 0,
    this.hasReacted = false,
  });

  final int productId;
  final int reactionCount;
  final int commentCount;
  final bool hasReacted;

  factory ProductEngagement.fromJson(JsonMap json) => ProductEngagement(
    productId: _int(json['productId']),
    reactionCount: _int(json['reactionCount']),
    commentCount: _int(json['commentCount']),
    hasReacted: json['hasReacted'] == true,
  );
}

class PostComment {
  const PostComment({
    required this.id,
    required this.userId,
    required this.content,
    this.parentId,
    this.username,
    this.fullName,
    this.avatar,
    this.replies = const [],
  });
  final int id;
  final int userId;
  final String content;
  final int? parentId;
  final String? username;
  final String? fullName;
  final MarketplaceImage? avatar;
  final List<PostComment> replies;

  String get displayName => (fullName?.trim().isNotEmpty ?? false)
      ? fullName!.trim()
      : (username?.trim().isNotEmpty ?? false)
      ? username!.trim()
      : 'Member #$userId';

  factory PostComment.fromJson(JsonMap json) {
    final author = asJsonMap(json['author']);
    return PostComment(
      id: _int(json['id']),
      userId: _int(json['userId']),
      content: '${json['content'] ?? ''}',
      parentId: json['parentId'] == null ? null : _int(json['parentId']),
      username: (json['username'] ?? author['username']) as String?,
      fullName: (json['fullName'] ?? author['fullName']) as String?,
      avatar: MarketplaceImage.tryParse(
        json['avatar'] ??
            author['avatar'] ??
            json['avatarUrl'] ??
            author['avatarUrl'],
        type: '${json['avatarType'] ?? author['avatarType'] ?? ''}',
        label: 'avatar',
      ),
      replies: ((json['replies'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => PostComment.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
    );
  }
}

JsonMap asJsonMap(Object? value) =>
    Map<String, dynamic>.from(value as Map? ?? const {});
