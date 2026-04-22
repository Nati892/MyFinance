import 'shopping_item.dart';

class ShoppingListItem {
  final int id;
  final int listId;
  final int itemId;
  final ShoppingItem? item;
  final double amount;
  final String unit;
  final String? extraData;
  final int sortOrder;

  ShoppingListItem({
    required this.id,
    required this.listId,
    required this.itemId,
    this.item,
    required this.amount,
    required this.unit,
    this.extraData,
    required this.sortOrder,
  });

  factory ShoppingListItem.fromJson(Map<String, dynamic> json) {
    return ShoppingListItem(
      id: json['id'] as int,
      listId: json['listId'] as int,
      itemId: json['itemId'] as int,
      item: json['item'] != null
          ? ShoppingItem.fromJson(json['item'] as Map<String, dynamic>)
          : null,
      amount: (json['amount'] as num?)?.toDouble() ?? 1.0,
      unit: json['unit'] as String? ?? 'pcs',
      extraData: json['extraData'] as String?,
      sortOrder: json['sortOrder'] as int? ?? 0,
    );
  }
}
