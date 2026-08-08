class Listing {
  final String id;
  final String userId;
  final String categoryId;
  final String? subcategoryId;
  final String countryCode;
  final String title;
  final String description;
  final double price;
  final String currency;
  final List<String> images;
  final String? whatsapp;
  final String? phone;
  final String? email;
  final String? location;
  final String? city;
  final bool isNegotiable;
  final bool isFeatured;
  final DateTime? featuredUntil;
  final String status; // active, inactive, sold, deleted
  final int views;
  final DateTime createdAt;
  final DateTime? updatedAt;

  // Related data (from joins)
  final String? userName;
  final String? userAvatar;
  final String? categoryName;
  final String? subcategoryName;

  // Real-estate attributes (JSONB column on the server). Loaded from
  // `attributes` when present; NOT serialized by `toInsertJson`/`toJson`
  // (the create path passes it through `extraFields` instead, the edit
  // path through `updates['attributes']`). Kept here so edit mode can
  // prefill the RE attribute form without a separate round-trip.
  final Map<String, dynamic>? attributes;

  // Foreign key to `developments.id` (obra-nueva). Read by the panel's
  // assign-listings sheet (T10) to pre-check rows already in this
  // development. Nullable: a listing is normally NOT part of a
  // development; the agencies may opt in to bundling their units under
  // a single promotion via `assignListingsToDevelopment`.
  final String? developmentId;

  Listing({
    required this.id,
    required this.userId,
    required this.categoryId,
    this.subcategoryId,
    required this.countryCode,
    required this.title,
    required this.description,
    required this.price,
    this.currency = 'EUR',
    required this.images,
    this.whatsapp,
    this.phone,
    this.email,
    this.location,
    this.city,
    this.isNegotiable = false,
    this.isFeatured = false,
    this.featuredUntil,
    this.status = 'active',
    this.views = 0,
    required this.createdAt,
    this.updatedAt,
    this.userName,
    this.userAvatar,
    this.categoryName,
    this.subcategoryName,
    this.attributes,
    this.developmentId,
  });

  factory Listing.fromJson(Map<String, dynamic> json) {
    return Listing(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      categoryId: json['category_id'] as String? ?? '',
      subcategoryId: json['subcategory_id'] as String?,
      countryCode: json['country_code'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String? ?? 'EUR',
      images: (json['images'] as List<dynamic>?)?.cast<String>() ?? [],
      whatsapp: json['whatsapp'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      location: json['location'] as String?,
      city: json['city'] as String?,
      isNegotiable: json['is_negotiable'] as bool? ?? false,
      isFeatured: json['is_featured'] as bool? ?? false,
      featuredUntil: json['featured_until'] != null
          ? DateTime.tryParse(json['featured_until'] as String? ?? '')
          : null,
      status: json['status'] as String? ?? 'active',
      views: json['views'] as int? ?? 0,
      createdAt: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at'] as String? ?? '') ??
              DateTime.now())
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String? ?? '')
          : null,
      userName: json['user_name'] as String?,
      userAvatar: json['user_avatar'] as String?,
      categoryName: json['category_name'] as String?,
      subcategoryName: json['subcategory_name'] as String?,
      attributes: json['attributes'] is Map
          ? Map<String, dynamic>.from(json['attributes'] as Map)
          : null,
      developmentId: json['development_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'category_id': categoryId,
      'subcategory_id': subcategoryId,
      'country_code': countryCode,
      'title': title,
      'description': description,
      'price': price,
      'currency': currency,
      'images': images,
      'whatsapp': whatsapp,
      'phone': phone,
      'email': email,
      'city': city,
      'is_negotiable': isNegotiable,
      'is_featured': isFeatured,
      'featured_until': featuredUntil?.toIso8601String(),
      'status': status,
      'views': views,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'user_id': userId,
      'category_id': categoryId,
      'subcategory_id': subcategoryId,
      'country_code': countryCode,
      'title': title,
      'description': description,
      'price': price,
      'currency': currency,
      'images': images,
      'whatsapp': whatsapp,
      'phone': phone,
      'email': email,
      'city': city,
      'is_negotiable': isNegotiable,
    };
  }

  Listing copyWith({
    String? id,
    String? userId,
    String? categoryId,
    String? subcategoryId,
    String? countryCode,
    String? title,
    String? description,
    double? price,
    String? currency,
    List<String>? images,
    String? whatsapp,
    String? phone,
    String? email,
    String? location,
    String? city,
    bool? isNegotiable,
    bool? isFeatured,
    DateTime? featuredUntil,
    String? status,
    int? views,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? userName,
    String? userAvatar,
    String? categoryName,
    String? subcategoryName,
    Map<String, dynamic>? attributes,
    String? developmentId,
  }) {
    return Listing(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      categoryId: categoryId ?? this.categoryId,
      subcategoryId: subcategoryId ?? this.subcategoryId,
      countryCode: countryCode ?? this.countryCode,
      title: title ?? this.title,
      description: description ?? this.description,
      price: price ?? this.price,
      currency: currency ?? this.currency,
      images: images ?? this.images,
      whatsapp: whatsapp ?? this.whatsapp,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      location: location ?? this.location,
      city: city ?? this.city,
      isNegotiable: isNegotiable ?? this.isNegotiable,
      isFeatured: isFeatured ?? this.isFeatured,
      featuredUntil: featuredUntil ?? this.featuredUntil,
      status: status ?? this.status,
      views: views ?? this.views,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      userName: userName ?? this.userName,
      userAvatar: userAvatar ?? this.userAvatar,
      categoryName: categoryName ?? this.categoryName,
      subcategoryName: subcategoryName ?? this.subcategoryName,
      attributes: attributes ?? this.attributes,
      developmentId: developmentId ?? this.developmentId,
    );
  }

  bool get isCurrentlyFeatured {
    if (!isFeatured || featuredUntil == null) return false;
    return featuredUntil!.isAfter(DateTime.now());
  }

  @Deprecated('Use formatPrice in core/utils/format_utils.dart for locale-aware rendering.')
  String get formattedPrice {
    return '${price.toStringAsFixed(price.truncateToDouble() == price ? 0 : 2)} $currency';
  }

  String get mainImage => images.isNotEmpty ? images.first : '';
}
