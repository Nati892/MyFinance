class Category {
  final int id;
  final String name;
  final String? nameHe;
  final String color;
  final String? icon;
  final int? householdId;

  const Category({
    required this.id,
    required this.name,
    this.nameHe,
    required this.color,
    this.icon,
    this.householdId,
  });

  factory Category.fromJson(Map<String, dynamic> json) => Category(
    id:          json['id'] as int,
    name:        json['name'] as String,
    nameHe:      json['nameHe'] as String?,
    color:       json['color'] as String? ?? '#888888',
    icon:        json['icon'] as String?,
    householdId: json['householdId'] as int?,
  );
}
