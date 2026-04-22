import 'shopping_category.dart';

class ShoppingItem {
  final int id;
  final String name;
  final String? nameHe;
  final String? icon;
  final String defaultUnit;
  final int? categoryId;
  final ShoppingCategory? category;
  final int householdId;
  final int createdBy;

  ShoppingItem({
    required this.id,
    required this.name,
    this.nameHe,
    this.icon,
    required this.defaultUnit,
    this.categoryId,
    this.category,
    required this.householdId,
    required this.createdBy,
  });

  factory ShoppingItem.fromJson(Map<String, dynamic> json) {
    return ShoppingItem(
      id: json['id'] as int,
      name: json['name'] as String,
      nameHe: json['nameHe'] as String?,
      icon: json['icon'] as String?,
      defaultUnit: json['defaultUnit'] as String? ?? 'pcs',
      categoryId: json['categoryId'] as int?,
      category: json['category'] != null
          ? ShoppingCategory.fromJson(json['category'] as Map<String, dynamic>)
          : null,
      householdId: json['householdId'] as int,
      createdBy: json['createdBy'] as int,
    );
  }
}
