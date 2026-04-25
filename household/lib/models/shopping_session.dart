import 'shopping_session_item.dart';
import 'shopping_store.dart';

enum ShoppingSessionMode {
  active,
  planned;

  String get wireValue => this == ShoppingSessionMode.planned ? 'planned' : 'active';

  static ShoppingSessionMode fromWire(String? v) =>
      v == 'planned' ? ShoppingSessionMode.planned : ShoppingSessionMode.active;
}

class ShoppingSession {
  final int id;
  final String name;
  final int? listId;
  final double posX;
  final double posY;
  final int zIndex;
  final double rotation;
  final int width;
  final int height;
  final String noteColor;
  final int householdId;
  final int createdBy;
  final List<ShoppingSessionItem> sessionItems;

  // Plan + lifecycle
  final ShoppingSessionMode mode;
  final double? plannedMinPrice;
  final double? plannedMaxPrice;
  final int? plannedYear;
  final int? plannedMonth;
  final int? plannedWeekOfMonth;
  final int? expenseCategoryId;
  final String? completedAt;
  final int? linkedExpenseId;
  final int? linkedBudgetPlanItemId;
  final int? storeId;
  final ShoppingStore? store;

  ShoppingSession({
    required this.id,
    required this.name,
    this.listId,
    required this.posX,
    required this.posY,
    required this.zIndex,
    required this.rotation,
    required this.width,
    required this.height,
    required this.noteColor,
    required this.householdId,
    required this.createdBy,
    this.sessionItems = const [],
    this.mode = ShoppingSessionMode.active,
    this.plannedMinPrice,
    this.plannedMaxPrice,
    this.plannedYear,
    this.plannedMonth,
    this.plannedWeekOfMonth,
    this.expenseCategoryId,
    this.completedAt,
    this.linkedExpenseId,
    this.linkedBudgetPlanItemId,
    this.storeId,
    this.store,
  });

  bool get isPlanned => mode == ShoppingSessionMode.planned;
  bool get isCompleted => completedAt != null;

  /// Running total of prices for items marked got/partial.
  double get actualTotal {
    double sum = 0;
    for (final it in sessionItems) {
      if (it.status == ShoppingItemStatus.got || it.status == ShoppingItemStatus.partial) {
        sum += it.price ?? 0;
      }
    }
    return sum;
  }

  int get completedItemCount =>
      sessionItems.where((it) => it.status != ShoppingItemStatus.pending).length;

  factory ShoppingSession.fromJson(Map<String, dynamic> json) {
    return ShoppingSession(
      id: json['id'] as int,
      name: json['name'] as String,
      listId: json['listId'] as int?,
      posX: (json['posX'] as num?)?.toDouble() ?? 50.0,
      posY: (json['posY'] as num?)?.toDouble() ?? 50.0,
      zIndex: json['zIndex'] as int? ?? 1,
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
      width: json['width'] as int? ?? 220,
      height: json['height'] as int? ?? 300,
      noteColor: json['noteColor'] as String? ?? '#fff9c4',
      householdId: json['householdId'] as int,
      createdBy: json['createdBy'] as int,
      sessionItems: json['sessionItems'] != null
          ? (json['sessionItems'] as List)
              .map((e) => ShoppingSessionItem.fromJson(e as Map<String, dynamic>))
              .toList()
          : [],
      mode: ShoppingSessionMode.fromWire(json['mode'] as String?),
      plannedMinPrice: (json['plannedMinPrice'] as num?)?.toDouble(),
      plannedMaxPrice: (json['plannedMaxPrice'] as num?)?.toDouble(),
      plannedYear: json['plannedYear'] as int?,
      plannedMonth: json['plannedMonth'] as int?,
      plannedWeekOfMonth: json['plannedWeekOfMonth'] as int?,
      expenseCategoryId: json['expenseCategoryId'] as int?,
      completedAt: json['completedAt'] as String?,
      linkedExpenseId: json['linkedExpenseId'] as int?,
      linkedBudgetPlanItemId: json['linkedBudgetPlanItemId'] as int?,
      storeId: json['storeId'] as int?,
      store: json['store'] != null
          ? ShoppingStore.fromJson(json['store'] as Map<String, dynamic>)
          : null,
    );
  }

  ShoppingSession copyWith({
    double? posX,
    double? posY,
    int? zIndex,
    double? rotation,
    int? width,
    int? height,
    String? noteColor,
    String? name,
    List<ShoppingSessionItem>? sessionItems,
    ShoppingSessionMode? mode,
    double? plannedMinPrice,
    double? plannedMaxPrice,
    int? plannedYear,
    int? plannedMonth,
    int? plannedWeekOfMonth,
    int? expenseCategoryId,
    String? completedAt,
    int? linkedExpenseId,
    int? linkedBudgetPlanItemId,
    int? storeId,
    ShoppingStore? store,
  }) {
    return ShoppingSession(
      id: id,
      name: name ?? this.name,
      listId: listId,
      posX: posX ?? this.posX,
      posY: posY ?? this.posY,
      zIndex: zIndex ?? this.zIndex,
      rotation: rotation ?? this.rotation,
      width: width ?? this.width,
      height: height ?? this.height,
      noteColor: noteColor ?? this.noteColor,
      householdId: householdId,
      createdBy: createdBy,
      sessionItems: sessionItems ?? this.sessionItems,
      mode: mode ?? this.mode,
      plannedMinPrice: plannedMinPrice ?? this.plannedMinPrice,
      plannedMaxPrice: plannedMaxPrice ?? this.plannedMaxPrice,
      plannedYear: plannedYear ?? this.plannedYear,
      plannedMonth: plannedMonth ?? this.plannedMonth,
      plannedWeekOfMonth: plannedWeekOfMonth ?? this.plannedWeekOfMonth,
      expenseCategoryId: expenseCategoryId ?? this.expenseCategoryId,
      completedAt: completedAt ?? this.completedAt,
      linkedExpenseId: linkedExpenseId ?? this.linkedExpenseId,
      linkedBudgetPlanItemId: linkedBudgetPlanItemId ?? this.linkedBudgetPlanItemId,
      storeId: storeId ?? this.storeId,
      store: store ?? this.store,
    );
  }
}
