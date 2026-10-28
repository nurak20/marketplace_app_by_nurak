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
    this.totalLike = 0,
    this.totalComment = 0,
    this.hasLiked = false,
    this.postByUser,
    this.reviews = const [],
    this.comments = const [],
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
  final int totalLike;
  final int totalComment;
  final bool hasLiked;
  final UserProfile? postByUser;
  final List<Review> reviews;
  final List<PostComment> comments;

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

  factory Product.fromJson(JsonMap json) {
    final product = json['product'] is Map
        ? Map<String, dynamic>.from(json['product'] as Map)
        : json;
    final seller = product['seller'] ?? product['user'];
    final postByUser = json['postByUser'] ?? product['postByUser'];
    return Product(
      id: _int(product['id']),
      sellerId: _int(product['sellerId']),
      title: '${product['title'] ?? ''}',
      price: _double(product['price']),
      status: '${product['status'] ?? 'AVAILABLE'}',
      description: product['description'] as String?,
      category: product['category'] as String?,
      condition: '${product['condition'] ?? 'GOOD'}',
      location: product['location'] as String?,
      images: _productImagesFromJson(product),
      seller: seller is Map
          ? UserProfile.fromJson(Map<String, dynamic>.from(seller))
          : null,
      isSaved: product['isSaved'] == true,
      totalLike: _int(json['totalLike'] ?? product['totalLike']),
      totalComment: _int(json['totalComment'] ?? product['totalComment']),
      hasLiked: json['hasLiked'] == true || product['hasLiked'] == true,
      postByUser: postByUser is Map
          ? UserProfile.fromJson(Map<String, dynamic>.from(postByUser))
          : null,
      reviews: ((json['reviews'] ?? product['reviews']) as List? ?? const [])
          .whereType<Map>()
          .map((item) => Review.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      comments: ((json['comments'] ?? product['comments']) as List? ?? const [])
          .whereType<Map>()
          .map((item) => PostComment.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
    );
  }
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
    this.firstName,
    this.lastName,
    this.avatar,
    this.location,
    this.bio,
    this.email,
    this.phone,
  });
  final int id;
  final String username;
  final String? fullName;
  final String? firstName;
  final String? lastName;
  final MarketplaceImage? avatar;
  final String? location;
  final String? bio;
  final String? email;
  final String? phone;

  String get firstNameText {
    final value = firstName?.trim();
    if (value?.isNotEmpty == true) return value!;
    final name = fullName?.trim();
    if (name == null || name.isEmpty) return '';
    return name.split(RegExp(r'\s+')).first;
  }

  String get lastNameText {
    final value = lastName?.trim();
    if (value?.isNotEmpty == true) return value!;
    final name = fullName?.trim();
    if (name == null || name.isEmpty) return '';
    final parts = name.split(RegExp(r'\s+'));
    return parts.length > 1 ? parts.sublist(1).join(' ') : '';
  }

  String get displayName {
    final name = fullName?.trim();
    if (name?.isNotEmpty == true) return name!;
    final joined = [
      firstNameText,
      lastNameText,
    ].where((part) => part.isNotEmpty).join(' ');
    if (joined.isNotEmpty) return joined;
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
      firstName: profile['firstName'] as String?,
      lastName: profile['lastName'] as String?,
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
    this.permissions = const [],
    this.active = true,
    this.canSell = true,
  });
  final UserProfile profile;
  final String? email;
  final String? phone;
  final List<String> roles;
  final List<String> permissions;
  final bool active;
  final bool canSell;

  bool get canAccessManagement => permissions.contains('management:access');
  bool get canManageUsers => permissions.contains('user:manage');
  bool get canManageCategories => permissions.contains('category:manage');
  bool get canManageConditions => permissions.contains('condition:manage');
  bool get canModeratePosts => permissions.contains('post:moderate');
  bool get canManageRoles => permissions.contains('admin:access');
  bool get canAccessPayroll => permissions.contains('payroll:read');
  bool get canManagePayroll => permissions.contains('payroll:manage');
  bool get canApprovePayroll => permissions.contains('payroll:approve');
  bool get canViewReports => permissions.contains('report:read');

  Account copyWith({bool? active, bool? canSell}) => Account(
    profile: profile,
    email: email,
    phone: phone,
    roles: roles,
    permissions: permissions,
    active: active ?? this.active,
    canSell: canSell ?? this.canSell,
  );

  factory Account.fromJson(JsonMap json) => Account(
    profile: UserProfile.fromJson(
      Map<String, dynamic>.from(json['profile'] as Map? ?? const {}),
    ),
    email: json['email'] as String?,
    phone: json['phone'] as String?,
    roles: (json['roles'] as List? ?? const []).map((role) => '$role').toList(),
    permissions: (json['permissions'] as List? ?? const [])
        .map((permission) => '$permission')
        .toList(),
    active: json['active'] != false,
    canSell: json['canSell'] != false,
  );
}

class ManagementCategory {
  const ManagementCategory({
    required this.id,
    required this.name,
    required this.active,
  });

  final int id;
  final String name;
  final bool active;

  ManagementCategory copyWith({String? name, bool? active}) =>
      ManagementCategory(
        id: id,
        name: name ?? this.name,
        active: active ?? this.active,
      );

  factory ManagementCategory.fromJson(JsonMap json) => ManagementCategory(
    id: _int(json['id']),
    name: '${json['name'] ?? ''}',
    active: json['active'] != false,
  );
}

class MarketplaceOptions {
  const MarketplaceOptions({
    required this.categories,
    required this.conditions,
  });

  final List<String> categories;
  final List<String> conditions;

  factory MarketplaceOptions.fromJson(JsonMap json) => MarketplaceOptions(
    categories: (json['categories'] as List? ?? const [])
        .map((value) => '$value')
        .toList(),
    conditions: (json['conditions'] as List? ?? const [])
        .map((value) => '$value')
        .toList(),
  );
}

class ManagementCondition {
  const ManagementCondition({required this.code, required this.active});

  final String code;
  final bool active;

  ManagementCondition copyWith({String? code, bool? active}) =>
      ManagementCondition(
        code: code ?? this.code,
        active: active ?? this.active,
      );

  factory ManagementCondition.fromJson(JsonMap json) => ManagementCondition(
    code: '${json['code'] ?? ''}',
    active: json['active'] != false,
  );
}

class ManagementPost {
  const ManagementPost({
    required this.id,
    required this.userId,
    required this.content,
    required this.removed,
    this.createdAt,
  });

  final int id;
  final int userId;
  final String content;
  final bool removed;
  final DateTime? createdAt;

  ManagementPost copyWith({bool? removed}) => ManagementPost(
    id: id,
    userId: userId,
    content: content,
    removed: removed ?? this.removed,
    createdAt: createdAt,
  );

  factory ManagementPost.fromJson(JsonMap json) => ManagementPost(
    id: _int(json['id']),
    userId: _int(json['userId']),
    content: '${json['content'] ?? ''}',
    removed: json['removed'] == true,
    createdAt: json['createdAt'] == null
        ? null
        : DateTime.tryParse('${json['createdAt']}')?.toLocal(),
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

class NotificationActor {
  const NotificationActor({
    required this.id,
    this.username = '',
    this.fullName,
    this.firstName,
    this.lastName,
    this.avatarUrl,
  });
  final int id;
  final String username;
  final String? fullName;
  final String? firstName;
  final String? lastName;
  final String? avatarUrl;

  String get displayName {
    final name = fullName?.trim();
    if (name?.isNotEmpty == true) return name!;
    final joined = [
      firstName,
      lastName,
    ].where((part) => part?.trim().isNotEmpty == true).join(' ');
    if (joined.isNotEmpty) return joined;
    return username.isNotEmpty ? username : 'Member #$id';
  }

  String get initial {
    final name = displayName.trim();
    return name.isEmpty ? '?' : name.substring(0, 1).toUpperCase();
  }

  factory NotificationActor.fromJson(JsonMap json) => NotificationActor(
    id: _int(json['id']),
    username: '${json['username'] ?? ''}',
    fullName: json['fullName'] as String?,
    firstName: json['firstName'] as String?,
    lastName: json['lastName'] as String?,
    avatarUrl: json['avatarUrl'] as String?,
  );
}

class MarketplaceNotification {
  const MarketplaceNotification({
    required this.id,
    required this.type,
    required this.message,
    required this.isRead,
    this.refId,
    this.createdAt,
    this.itemCount = 0,
    this.postId,
    this.productId,
    this.actor,
  });
  final int id;
  final String type;
  final String message;
  final bool isRead;
  final int? refId;
  final DateTime? createdAt;
  final int itemCount;
  final int? postId;
  final int? productId;
  final NotificationActor? actor;

  int? get actorId => actor?.id;

  MarketplaceNotification withRead(bool value) => MarketplaceNotification(
    id: id,
    type: type,
    message: message,
    isRead: value,
    refId: refId,
    createdAt: createdAt,
    itemCount: itemCount,
    postId: postId,
    productId: productId,
    actor: actor,
  );

  factory MarketplaceNotification.fromJson(JsonMap json) {
    final actor = json['actor'];
    return MarketplaceNotification(
      id: _int(json['id']),
      type: '${json['type'] ?? ''}',
      message: '${json['message'] ?? ''}',
      isRead: json['isRead'] == true,
      refId: json['refId'] == null ? null : _int(json['refId']),
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.tryParse('${json['createdAt']}')?.toLocal(),
      itemCount: json['itemCount'] == null ? 0 : _int(json['itemCount']),
      postId: json['postId'] == null ? null : _int(json['postId']),
      productId: json['productId'] == null ? null : _int(json['productId']),
      actor: actor is Map
          ? NotificationActor.fromJson(Map<String, dynamic>.from(actor))
          : null,
    );
  }
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
    this.postByUser,
    this.isRemoved = false,
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
  final UserProfile? postByUser;
  final bool isRemoved;

  UserProfile? get seller => postByUser;

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
    postByUser: postByUser,
    isRemoved: isRemoved,
  );

  factory MarketplacePost.fromJson(JsonMap json) {
    final post = json['post'] is Map
        ? Map<String, dynamic>.from(json['post'] as Map)
        : json;
    final author =
        json['postByUser'] ??
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
      isRemoved: post['removed'] == true,
      createdAt: rawCreatedAt == null
          ? null
          : DateTime.tryParse('$rawCreatedAt')?.toLocal(),
      reactionCount: _int(json['reactionCount']),
      commentCount: _int(json['commentCount']),
      hasReacted: json['hasReacted'] == true,
      postByUser: author is Map
          ? UserProfile.fromJson(Map<String, dynamic>.from(author))
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

const _payrollMonthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

String payrollPeriodLabel(int? year, int? month) {
  if (year == null || month == null || month < 1 || month > 12) return 'Period';
  return '${_payrollMonthNames[month - 1]} $year';
}

DateTime? _payrollDateTime(Object? value) =>
    value == null ? null : DateTime.tryParse('$value')?.toLocal();

class EmployeeProfile {
  const EmployeeProfile({
    required this.id,
    required this.userId,
    required this.baseSalary,
    required this.allowance,
    required this.status,
    this.username,
    this.fullName,
    this.employeeCode,
    this.jobTitle,
    this.department,
    this.currency = 'USD',
    this.hireDate,
    this.bankName,
    this.bankAccount,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final int userId;
  final double baseSalary;
  final double allowance;
  final String status;
  final String? username;
  final String? fullName;
  final String? employeeCode;
  final String? jobTitle;
  final String? department;
  final String currency;
  final DateTime? hireDate;
  final String? bankName;
  final String? bankAccount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get displayName {
    final name = fullName?.trim();
    if (name?.isNotEmpty == true) return name!;
    final handle = username?.trim();
    return handle?.isNotEmpty == true ? handle! : 'User #$userId';
  }

  String get employeeLabel {
    final code = employeeCode?.trim();
    return code?.isNotEmpty == true
        ? code!
        : 'EMP-${userId.toString().padLeft(4, '0')}';
  }

  double get monthlyPackage => baseSalary + allowance;

  factory EmployeeProfile.fromJson(JsonMap json) => EmployeeProfile(
    id: _int(json['id']),
    userId: _int(json['userId']),
    baseSalary: _double(json['baseSalary']),
    allowance: _double(json['allowance']),
    status: '${json['status'] ?? 'ACTIVE'}',
    username: json['username'] as String?,
    fullName: json['fullName'] as String?,
    employeeCode: json['employeeCode'] as String?,
    jobTitle: json['jobTitle'] as String?,
    department: json['department'] as String?,
    currency: '${json['currency'] ?? 'USD'}',
    hireDate: _payrollDateTime(json['hireDate']),
    bankName: json['bankName'] as String?,
    bankAccount: json['bankAccount'] as String?,
    createdAt: _payrollDateTime(json['createdAt']),
    updatedAt: _payrollDateTime(json['updatedAt']),
  );
}

class PayrollRun {
  const PayrollRun({
    required this.id,
    required this.periodYear,
    required this.periodMonth,
    required this.status,
    required this.totalGross,
    required this.totalDeductions,
    required this.totalNet,
    this.currency = 'USD',
    this.notes,
    this.createdBy,
    this.approvedBy,
    this.approvedAt,
    this.paidAt,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final int periodYear;
  final int periodMonth;
  final String status;
  final double totalGross;
  final double totalDeductions;
  final double totalNet;
  final String currency;
  final String? notes;
  final int? createdBy;
  final int? approvedBy;
  final DateTime? approvedAt;
  final DateTime? paidAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get periodLabel => payrollPeriodLabel(periodYear, periodMonth);
  bool get isDraft => status == 'DRAFT';
  bool get isApproved => status == 'APPROVED';
  bool get isPaid => status == 'PAID';
  bool get isCancelled => status == 'CANCELLED';

  factory PayrollRun.fromJson(JsonMap json) => PayrollRun(
    id: _int(json['id']),
    periodYear: _int(json['periodYear']),
    periodMonth: _int(json['periodMonth']),
    status: '${json['status'] ?? 'DRAFT'}',
    totalGross: _double(json['totalGross']),
    totalDeductions: _double(json['totalDeductions']),
    totalNet: _double(json['totalNet']),
    currency: '${json['currency'] ?? 'USD'}',
    notes: json['notes'] as String?,
    createdBy: json['createdBy'] == null ? null : _int(json['createdBy']),
    approvedBy: json['approvedBy'] == null ? null : _int(json['approvedBy']),
    approvedAt: _payrollDateTime(json['approvedAt']),
    paidAt: _payrollDateTime(json['paidAt']),
    createdAt: _payrollDateTime(json['createdAt']),
    updatedAt: _payrollDateTime(json['updatedAt']),
  );
}

class Payslip {
  const Payslip({
    required this.id,
    required this.runId,
    required this.userId,
    required this.baseSalary,
    required this.allowance,
    required this.bonus,
    required this.overtime,
    required this.tax,
    required this.otherDeductions,
    required this.grossPay,
    required this.deductionsTotal,
    required this.netPay,
    this.periodYear,
    this.periodMonth,
    this.runStatus,
    this.employeeCode,
    this.employeeName,
    this.jobTitle,
    this.department,
    this.currency = 'USD',
    this.notes,
    this.paidAt,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final int runId;
  final int userId;
  final int? periodYear;
  final int? periodMonth;
  final String? runStatus;
  final String? employeeCode;
  final String? employeeName;
  final String? jobTitle;
  final String? department;
  final double baseSalary;
  final double allowance;
  final double bonus;
  final double overtime;
  final double tax;
  final double otherDeductions;
  final double grossPay;
  final double deductionsTotal;
  final double netPay;
  final String currency;
  final String? notes;
  final DateTime? paidAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get periodLabel => payrollPeriodLabel(periodYear, periodMonth);

  String get displayName {
    final name = employeeName?.trim();
    if (name?.isNotEmpty == true) return name!;
    final code = employeeCode?.trim();
    return code?.isNotEmpty == true ? code! : 'Employee #$userId';
  }

  factory Payslip.fromJson(JsonMap json) => Payslip(
    id: _int(json['id']),
    runId: _int(json['runId']),
    userId: _int(json['userId']),
    periodYear: json['periodYear'] == null ? null : _int(json['periodYear']),
    periodMonth: json['periodMonth'] == null ? null : _int(json['periodMonth']),
    runStatus: json['runStatus'] as String?,
    employeeCode: json['employeeCode'] as String?,
    employeeName: json['employeeName'] as String?,
    jobTitle: json['jobTitle'] as String?,
    department: json['department'] as String?,
    baseSalary: _double(json['baseSalary']),
    allowance: _double(json['allowance']),
    bonus: _double(json['bonus']),
    overtime: _double(json['overtime']),
    tax: _double(json['tax']),
    otherDeductions: _double(json['otherDeductions']),
    grossPay: _double(json['grossPay']),
    deductionsTotal: _double(json['deductionsTotal']),
    netPay: _double(json['netPay']),
    currency: '${json['currency'] ?? 'USD'}',
    notes: json['notes'] as String?,
    paidAt: _payrollDateTime(json['paidAt']),
    createdAt: _payrollDateTime(json['createdAt']),
    updatedAt: _payrollDateTime(json['updatedAt']),
  );
}

class ReportOverview {
  const ReportOverview({
    required this.totalUsers,
    required this.activeUsers,
    required this.sellers,
    required this.products,
    required this.availableProducts,
    required this.soldProducts,
    required this.posts,
    required this.comments,
    required this.reactions,
    required this.wishlists,
    required this.employees,
    required this.activeEmployees,
    required this.paidGross,
    required this.paidNet,
    required this.availableValue,
  });

  final int totalUsers;
  final int activeUsers;
  final int sellers;
  final int products;
  final int availableProducts;
  final int soldProducts;
  final int posts;
  final int comments;
  final int reactions;
  final int wishlists;
  final int employees;
  final int activeEmployees;
  final double paidGross;
  final double paidNet;
  final double availableValue;

  factory ReportOverview.fromJson(JsonMap json) => ReportOverview(
    totalUsers: _int(json['totalUsers']),
    activeUsers: _int(json['activeUsers']),
    sellers: _int(json['sellers']),
    products: _int(json['products']),
    availableProducts: _int(json['availableProducts']),
    soldProducts: _int(json['soldProducts']),
    posts: _int(json['posts']),
    comments: _int(json['comments']),
    reactions: _int(json['reactions']),
    wishlists: _int(json['wishlists']),
    employees: _int(json['employees']),
    activeEmployees: _int(json['activeEmployees']),
    paidGross: _double(json['paidGross']),
    paidNet: _double(json['paidNet']),
    availableValue: _double(json['availableValue']),
  );
}

class ProductStatusReport {
  const ProductStatusReport({
    required this.status,
    required this.products,
    required this.value,
  });

  final String status;
  final int products;
  final double value;

  factory ProductStatusReport.fromJson(JsonMap json) => ProductStatusReport(
    status: '${json['status'] ?? 'UNKNOWN'}',
    products: _int(json['products']),
    value: _double(json['value']),
  );
}

class CategoryReport {
  const CategoryReport({
    required this.category,
    required this.products,
    required this.available,
    required this.sold,
    required this.reserved,
    required this.value,
  });

  final String category;
  final int products;
  final int available;
  final int sold;
  final int reserved;
  final double value;

  factory CategoryReport.fromJson(JsonMap json) => CategoryReport(
    category: '${json['category'] ?? 'Uncategorized'}',
    products: _int(json['products']),
    available: _int(json['available']),
    sold: _int(json['sold']),
    reserved: _int(json['reserved']),
    value: _double(json['value']),
  );
}

class MonthlyActivityReport {
  const MonthlyActivityReport({
    required this.month,
    required this.users,
    required this.products,
    required this.posts,
    required this.comments,
    required this.reactions,
  });

  final String month;
  final int users;
  final int products;
  final int posts;
  final int comments;
  final int reactions;

  factory MonthlyActivityReport.fromJson(JsonMap json) => MonthlyActivityReport(
    month: '${json['month'] ?? ''}',
    users: _int(json['users']),
    products: _int(json['products']),
    posts: _int(json['posts']),
    comments: _int(json['comments']),
    reactions: _int(json['reactions']),
  );
}

class EngagementReport {
  const EngagementReport({
    required this.month,
    required this.comments,
    required this.reactions,
    required this.wishlists,
    required this.reviews,
    required this.messages,
  });

  final String month;
  final int comments;
  final int reactions;
  final int wishlists;
  final int reviews;
  final int messages;

  factory EngagementReport.fromJson(JsonMap json) => EngagementReport(
    month: '${json['month'] ?? ''}',
    comments: _int(json['comments']),
    reactions: _int(json['reactions']),
    wishlists: _int(json['wishlists']),
    reviews: _int(json['reviews']),
    messages: _int(json['messages']),
  );
}

class TopSellerReport {
  const TopSellerReport({
    required this.userId,
    required this.name,
    required this.listings,
    required this.sold,
    required this.revenue,
    required this.reactions,
    required this.comments,
  });

  final int userId;
  final String name;
  final int listings;
  final int sold;
  final double revenue;
  final int reactions;
  final int comments;

  factory TopSellerReport.fromJson(JsonMap json) => TopSellerReport(
    userId: _int(json['userId']),
    name: '${json['name'] ?? 'Seller #${json['userId'] ?? ''}'}',
    listings: _int(json['listings']),
    sold: _int(json['sold']),
    revenue: _double(json['revenue']),
    reactions: _int(json['reactions']),
    comments: _int(json['comments']),
  );
}

class PayrollDepartmentReport {
  const PayrollDepartmentReport({
    required this.periodYear,
    required this.periodMonth,
    required this.department,
    required this.employees,
    required this.gross,
    required this.deductions,
    required this.net,
  });

  final int periodYear;
  final int periodMonth;
  final String department;
  final int employees;
  final double gross;
  final double deductions;
  final double net;

  String get periodLabel => payrollPeriodLabel(periodYear, periodMonth);

  factory PayrollDepartmentReport.fromJson(JsonMap json) =>
      PayrollDepartmentReport(
        periodYear: _int(json['periodYear']),
        periodMonth: _int(json['periodMonth']),
        department: '${json['department'] ?? 'Unassigned'}',
        employees: _int(json['employees']),
        gross: _double(json['gross']),
        deductions: _double(json['deductions']),
        net: _double(json['net']),
      );
}

class PayrollRunReport {
  const PayrollRunReport({
    required this.periodYear,
    required this.periodMonth,
    required this.status,
    required this.employees,
    required this.gross,
    required this.deductions,
    required this.net,
  });

  final int periodYear;
  final int periodMonth;
  final String status;
  final int employees;
  final double gross;
  final double deductions;
  final double net;

  String get periodLabel => payrollPeriodLabel(periodYear, periodMonth);

  factory PayrollRunReport.fromJson(JsonMap json) => PayrollRunReport(
    periodYear: _int(json['periodYear']),
    periodMonth: _int(json['periodMonth']),
    status: '${json['status'] ?? 'DRAFT'}',
    employees: _int(json['employees']),
    gross: _double(json['gross']),
    deductions: _double(json['deductions']),
    net: _double(json['net']),
  );
}

class HeadcountReport {
  const HeadcountReport({
    required this.department,
    required this.active,
    required this.onLeave,
    required this.terminated,
    required this.total,
  });

  final String department;
  final int active;
  final int onLeave;
  final int terminated;
  final int total;

  factory HeadcountReport.fromJson(JsonMap json) => HeadcountReport(
    department: '${json['department'] ?? 'Unassigned'}',
    active: _int(json['active']),
    onLeave: _int(json['onLeave']),
    terminated: _int(json['terminated']),
    total: _int(json['total']),
  );
}

JsonMap asJsonMap(Object? value) =>
    Map<String, dynamic>.from(value as Map? ?? const {});
