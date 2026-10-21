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

  factory ApiPage.fromJson(JsonMap json, T Function(JsonMap) parse) => ApiPage(
    items: ((json['items'] as List?) ?? const [])
        .whereType<Map>()
        .map((item) => parse(Map<String, dynamic>.from(item)))
        .toList(),
    page: _int(json['page']),
    totalPages: _int(json['totalPages']),
  );
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
  );
}

class ProductImage {
  const ProductImage(this.url, {this.primary = false});
  final String url;
  final bool primary;

  factory ProductImage.fromJson(JsonMap json) => ProductImage(
    '${json['imageUrl'] ?? ''}',
    primary: json['isPrimary'] == true,
  );
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
    this.avatarUrl,
    this.location,
    this.bio,
    this.email,
    this.phone,
  });
  final int id;
  final String username;
  final String? fullName;
  final String? avatarUrl;
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
      avatarUrl: profile['avatarUrl'] as String?,
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
  });
  final int id;
  final int senderId;
  final int receiverId;
  final int? productId;
  final String content;
  final bool isRead;

  factory MarketplaceMessage.fromJson(JsonMap json) => MarketplaceMessage(
    id: _int(json['id']),
    senderId: _int(json['senderId']),
    receiverId: _int(json['receiverId']),
    productId: json['productId'] == null ? null : _int(json['productId']),
    content: '${json['content'] ?? ''}',
    isRead: json['isRead'] == true,
  );
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
  );

  factory MarketplacePost.fromJson(JsonMap json) {
    final post = asJsonMap(json['post']);
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
    this.avatarUrl,
    this.replies = const [],
  });
  final int id;
  final int userId;
  final String content;
  final int? parentId;
  final String? username;
  final String? fullName;
  final String? avatarUrl;
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
      avatarUrl: (json['avatarUrl'] ?? author['avatarUrl']) as String?,
      replies: ((json['replies'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => PostComment.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
    );
  }
}

JsonMap asJsonMap(Object? value) =>
    Map<String, dynamic>.from(value as Map? ?? const {});
