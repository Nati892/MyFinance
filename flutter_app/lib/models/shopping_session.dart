import 'shopping_session_item.dart';

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
  });

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
    );
  }
}
