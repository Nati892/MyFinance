import 'shopping_item.dart';
import 'shopping_store.dart';

enum ShoppingItemStatus {
  pending,
  got,
  notGot,
  partial;

  String get wireValue {
    switch (this) {
      case ShoppingItemStatus.pending:
        return 'pending';
      case ShoppingItemStatus.got:
        return 'got';
      case ShoppingItemStatus.notGot:
        return 'not_got';
      case ShoppingItemStatus.partial:
        return 'partial';
    }
  }

  static ShoppingItemStatus fromWire(String? v) {
    switch (v) {
      case 'got':
        return ShoppingItemStatus.got;
      case 'not_got':
        return ShoppingItemStatus.notGot;
      case 'partial':
        return ShoppingItemStatus.partial;
      default:
        return ShoppingItemStatus.pending;
    }
  }
}

class ShoppingSessionItem {
  final int id;
  final int sessionId;
  final int itemId;
  final ShoppingItem? item;
  final double amount;
  final String unit;
  final String? extraData;
  final ShoppingItemStatus status;
  final double? price;
  final int? storeId;
  final ShoppingStore? store;
  final String? note;
  final double? actualAmount;
  final int sortOrder;

  ShoppingSessionItem({
    required this.id,
    required this.sessionId,
    required this.itemId,
    this.item,
    required this.amount,
    required this.unit,
    this.extraData,
    required this.status,
    this.price,
    this.storeId,
    this.store,
    this.note,
    this.actualAmount,
    required this.sortOrder,
  });

  factory ShoppingSessionItem.fromJson(Map<String, dynamic> json) {
    return ShoppingSessionItem(
      id: json['id'] as int,
      sessionId: json['sessionId'] as int,
      itemId: json['itemId'] as int,
      item: json['item'] != null
          ? ShoppingItem.fromJson(json['item'] as Map<String, dynamic>)
          : null,
      amount: (json['amount'] as num?)?.toDouble() ?? 1.0,
      unit: json['unit'] as String? ?? 'pcs',
      extraData: json['extraData'] as String?,
      status: ShoppingItemStatus.fromWire(json['status'] as String?),
      price: (json['price'] as num?)?.toDouble(),
      storeId: json['storeId'] as int?,
      store: json['store'] != null
          ? ShoppingStore.fromJson(json['store'] as Map<String, dynamic>)
          : null,
      note: json['note'] as String?,
      actualAmount: (json['actualAmount'] as num?)?.toDouble(),
      sortOrder: json['sortOrder'] as int? ?? 0,
    );
  }

  ShoppingSessionItem copyWith({
    ShoppingItemStatus? status,
    double? price,
    int? storeId,
    ShoppingStore? store,
    String? note,
    double? amount,
    String? unit,
    double? actualAmount,
  }) {
    return ShoppingSessionItem(
      id: id,
      sessionId: sessionId,
      itemId: itemId,
      item: item,
      amount: amount ?? this.amount,
      unit: unit ?? this.unit,
      extraData: extraData,
      status: status ?? this.status,
      price: price ?? this.price,
      storeId: storeId ?? this.storeId,
      store: store ?? this.store,
      note: note ?? this.note,
      actualAmount: actualAmount ?? this.actualAmount,
      sortOrder: sortOrder,
    );
  }
}
