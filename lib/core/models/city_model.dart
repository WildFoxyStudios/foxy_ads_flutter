class City {
  final String id;
  final String countryCode;
  final String name;
  final bool isEnabled;
  final int sortOrder;

  City({
    required this.id,
    required this.countryCode,
    required this.name,
    this.isEnabled = true,
    this.sortOrder = 0,
  });

  factory City.fromJson(Map<String, dynamic> json) {
    return City(
      id: json['id'] as String,
      countryCode: json['country_code'] as String,
      name: json['name'] as String,
      isEnabled: json['is_enabled'] as bool? ?? true,
      sortOrder: json['sort_order'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'country_code': countryCode,
      'name': name,
      'is_enabled': isEnabled,
      'sort_order': sortOrder,
    };
  }

  @override
  String toString() => name;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is City && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
