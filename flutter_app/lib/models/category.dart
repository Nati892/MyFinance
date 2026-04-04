class Category {
  final int id;
  final String name;
  final String? nameHe;
  final String color;
  final String? icon;
  final int? householdId;
  final int? parentCategoryId;
  final List<Category> subCategories;

  const Category({
    required this.id,
    required this.name,
    this.nameHe,
    required this.color,
    this.icon,
    this.householdId,
    this.parentCategoryId,
    this.subCategories = const [],
  });

  factory Category.fromJson(Map<String, dynamic> json) => Category(
    id:               json['id'] as int,
    name:             json['name'] as String,
    nameHe:           json['nameHe'] as String?,
    color:            json['color'] as String? ?? '#888888',
    icon:             json['icon'] as String?,
    householdId:      json['householdId'] as int?,
    parentCategoryId: json['parentCategoryId'] as int?,
    subCategories:    (json['subCategories'] as List<dynamic>? ?? [])
        .map((e) => Category.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  /// Returns this category plus all its sub-categories as a flat list.
  List<Category> get flatList => [this, ...subCategories];
}
