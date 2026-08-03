class Category {
  final String id;
  final String name;
  final String nameEs;
  final String icon;
  final String color;
  final int sortOrder;
  final bool isAdult;
  final String? parentId;
  final String? description;
  final List<Category>? subcategories;

  Category({
    required this.id,
    required this.name,
    this.nameEs = '',
    required this.icon,
    required this.color,
    required this.sortOrder,
    this.isAdult = false,
    this.parentId,
    this.description,
    this.subcategories,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    final name = json['name'] as String? ?? '';
    return Category(
      id: json['id'] as String? ?? '',
      name: name,
      nameEs: json['name_es'] as String? ?? name,
      icon: json['icon'] as String? ?? '',
      color: json['color'] as String? ?? '',
      sortOrder: json['sort_order'] as int? ?? 0,
      isAdult: json['is_adult'] as bool? ?? false,
      parentId: json['parent_id'] as String?,
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'name_es': nameEs,
      'icon': icon,
      'color': color,
      'sort_order': sortOrder,
      'is_adult': isAdult,
      'parent_id': parentId,
      'description': description,
    };
  }

  // Check if this is a main category (no parent)
  bool get isMainCategory => parentId == null;

  // Check if this is a subcategory (has parent)
  bool get isSubcategory => parentId != null;

  // Create a copy with subcategories
  Category copyWithSubcategories(List<Category> subs) {
    return Category(
      id: id,
      name: name,
      nameEs: nameEs,
      icon: icon,
      color: color,
      sortOrder: sortOrder,
      isAdult: isAdult,
      parentId: parentId,
      description: description,
      subcategories: subs,
    );
  }

  // Default categories (matching Supabase)
  static List<Category> defaultCategories = [
    Category(
      id: 'real_estate',
      name: 'Real Estate',
      nameEs: 'Inmuebles',
      icon: '🏠',
      color: '#2D3047',
      sortOrder: 1,
    ),
    Category(
      id: 'vehicles',
      name: 'Vehicles',
      nameEs: 'Vehículos',
      icon: '🚗',
      color: '#FF6B35',
      sortOrder: 2,
    ),
    Category(
      id: 'electronics',
      name: 'Electronics',
      nameEs: 'Electrónica',
      icon: '📱',
      color: '#4ECDC4',
      sortOrder: 3,
    ),
    Category(
      id: 'fashion',
      name: 'Fashion',
      nameEs: 'Moda',
      icon: '👗',
      color: '#FF6B6B',
      sortOrder: 4,
    ),
    Category(
      id: 'home_garden',
      name: 'Home & Garden',
      nameEs: 'Hogar y Jardín',
      icon: '🏡',
      color: '#95E1D3',
      sortOrder: 5,
    ),
    Category(
      id: 'services',
      name: 'Services',
      nameEs: 'Servicios',
      icon: '🔧',
      color: '#AA96DA',
      sortOrder: 6,
    ),
    Category(
      id: 'jobs',
      name: 'Jobs',
      nameEs: 'Empleo',
      icon: '💼',
      color: '#FCBAD3',
      sortOrder: 7,
    ),
    Category(
      id: 'classes',
      name: 'Classes',
      nameEs: 'Clases y Talleres',
      icon: '📖',
      color: '#FFD93D',
      sortOrder: 8,
    ),
    Category(
      id: 'community',
      name: 'Community',
      nameEs: 'Comunidad',
      icon: '🤝',
      color: '#6BCB77',
      sortOrder: 9,
    ),
    Category(
      id: 'sports',
      name: 'Sports',
      nameEs: 'Deportes',
      icon: '⚽',
      color: '#F38181',
      sortOrder: 10,
    ),
    Category(
      id: 'kids',
      name: 'Kids & Baby',
      nameEs: 'Niños y Bebé',
      icon: '👶',
      color: '#FCE38A',
      sortOrder: 11,
    ),
    Category(
      id: 'pets',
      name: 'Pets',
      nameEs: 'Mascotas',
      icon: '🐕',
      color: '#A8D8EA',
      sortOrder: 12,
    ),
    Category(
      id: 'music_art',
      name: 'Music & Art',
      nameEs: 'Música y Arte',
      icon: '🎸',
      color: '#9B5DE5',
      sortOrder: 13,
    ),
    Category(
      id: 'books',
      name: 'Books',
      nameEs: 'Libros',
      icon: '📚',
      color: '#F15BB5',
      sortOrder: 14,
    ),
    Category(
      id: 'collectibles',
      name: 'Collectibles',
      nameEs: 'Coleccionables',
      icon: '🏺',
      color: '#00BBF9',
      sortOrder: 15,
    ),
    Category(
      id: 'food',
      name: 'Food & Drinks',
      nameEs: 'Comida y Bebidas',
      icon: '🍕',
      color: '#00F5D4',
      sortOrder: 16,
    ),
    Category(
      id: 'others',
      name: 'Others',
      nameEs: 'Otros',
      icon: '📦',
      color: '#9B9B9B',
      sortOrder: 17,
    ),
    Category(
      id: 'contacts',
      name: 'Contacts',
      nameEs: 'Contactos',
      icon: '💋',
      color: '#E91E63',
      sortOrder: 18,
      isAdult: true,
    ),
  ];
}
