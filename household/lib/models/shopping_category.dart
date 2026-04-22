class ShoppingCategory {
  final int id;
  final String name;
  final String? nameHe;
  final String? icon;
  final int householdId;

  ShoppingCategory({
    required this.id,
    required this.name,
    this.nameHe,
    this.icon,
    required this.householdId,
  });

  factory ShoppingCategory.fromJson(Map<String, dynamic> json) {
    return ShoppingCategory(
      id: json['id'] as int,
      name: json['name'] as String,
      nameHe: json['nameHe'] as String?,
      icon: json['icon'] as String?,
      householdId: json['householdId'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'nameHe': nameHe,
        'icon': icon,
        'householdId': householdId,
      };
}
