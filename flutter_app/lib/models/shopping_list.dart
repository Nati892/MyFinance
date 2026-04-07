import 'shopping_list_item.dart';

class ShoppingList {
  final int id;
  final String name;
  final String? nameHe;
  final int householdId;
  final int createdBy;
  final List<ShoppingListItem> listItems;

  ShoppingList({
    required this.id,
    required this.name,
    this.nameHe,
    required this.householdId,
    required this.createdBy,
    this.listItems = const [],
  });

  factory ShoppingList.fromJson(Map<String, dynamic> json) {
    return ShoppingList(
      id: json['id'] as int,
      name: json['name'] as String,
      nameHe: json['nameHe'] as String?,
      householdId: json['householdId'] as int,
      createdBy: json['createdBy'] as int,
      listItems: json['listItems'] != null
          ? (json['listItems'] as List)
              .map((e) => ShoppingListItem.fromJson(e as Map<String, dynamic>))
              .toList()
          : [],
    );
  }
}
