class Favorite {
  final String id;
  final String userId;
  final String listingId;
  final DateTime createdAt;

  Favorite({
    required this.id,
    required this.userId,
    required this.listingId,
    required this.createdAt,
  });

  factory Favorite.fromJson(Map<String, dynamic> json) {
    return Favorite(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      listingId: json['listing_id'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at'] as String? ?? '') ??
              DateTime.now())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'listing_id': listingId,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
