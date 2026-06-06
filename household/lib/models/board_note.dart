/// Represents a single sticky note on the household board.
///
/// The backend API is at GET/POST/PUT/DELETE /api/app/notes.
/// Notes have a `type` field: 'text', 'heart', or 'image'.
/// The API does NOT have a dedicated heart-toggle endpoint;
/// hearts are stored as note type='heart' entries created/deleted like any note.
const Object _kUnset = Object();

class BoardNote {
  final int id;
  final String content;
  final String type; // 'text' | 'heart' | 'image'
  final String noteColor;
  final String? heartColor;
  final double posX;
  final double posY;
  final int zIndex;
  final double rotation;
  final int? width;
  final int? height;
  final String textColor;
  final int textSize;
  final bool isBold;
  final bool isUnderline;
  final String textDirection; // 'ltr' | 'rtl' | 'auto'
  final String? headerText;
  final bool locked;
  final int householdId;
  final int appUserId;
  final String authorUsername;
  final String createdAt;

  const BoardNote({
    required this.id,
    required this.content,
    required this.type,
    required this.noteColor,
    this.heartColor,
    required this.posX,
    required this.posY,
    required this.zIndex,
    required this.rotation,
    this.width,
    this.height,
    required this.textColor,
    required this.textSize,
    required this.isBold,
    required this.isUnderline,
    required this.textDirection,
    this.headerText,
    this.locked = false,
    required this.householdId,
    required this.appUserId,
    required this.authorUsername,
    required this.createdAt,
  });

  BoardNote copyWith({
    String? content,
    String? type,
    String? noteColor,
    String? heartColor,
    double? posX,
    double? posY,
    int? zIndex,
    double? rotation,
    int? width,
    int? height,
    String? textColor,
    int? textSize,
    bool? isBold,
    bool? isUnderline,
    String? textDirection,
    Object? headerText = _kUnset,
    bool? locked,
  }) {
    return BoardNote(
      id: id,
      content: content ?? this.content,
      type: type ?? this.type,
      noteColor: noteColor ?? this.noteColor,
      heartColor: heartColor ?? this.heartColor,
      posX: posX ?? this.posX,
      posY: posY ?? this.posY,
      zIndex: zIndex ?? this.zIndex,
      rotation: rotation ?? this.rotation,
      width: width ?? this.width,
      height: height ?? this.height,
      textColor: textColor ?? this.textColor,
      textSize: textSize ?? this.textSize,
      isBold: isBold ?? this.isBold,
      isUnderline: isUnderline ?? this.isUnderline,
      textDirection: textDirection ?? this.textDirection,
      headerText: identical(headerText, _kUnset)
          ? this.headerText
          : headerText as String?,
      locked: locked ?? this.locked,
      householdId: householdId,
      appUserId: appUserId,
      authorUsername: authorUsername,
      createdAt: createdAt,
    );
  }

  factory BoardNote.fromJson(Map<String, dynamic> json) {
    final appUser = (json['AppUser'] ?? json['appUser']) as Map<String, dynamic>?;
    return BoardNote(
      id:             json['id'] as int,
      content:        json['content'] as String? ?? '',
      type:           json['type'] as String? ?? 'text',
      noteColor:      json['noteColor'] as String? ?? '#fff9c4',
      heartColor:     json['heartColor'] as String?,
      posX:           (json['posX'] as num?)?.toDouble() ?? 0,
      posY:           (json['posY'] as num?)?.toDouble() ?? 0,
      zIndex:         json['zIndex'] as int? ?? 1,
      rotation:       (json['rotation'] as num?)?.toDouble() ?? 0,
      width:          json['width'] as int?,
      height:         json['height'] as int?,
      textColor:      json['textColor'] as String? ?? '#333333',
      textSize:       json['textSize'] as int? ?? 14,
      isBold:         json['isBold'] as bool? ?? false,
      isUnderline:    json['isUnderline'] as bool? ?? false,
      textDirection:  json['textDirection'] as String? ?? 'auto',
      headerText:     json['headerText'] as String?,
      locked:         json['locked'] as bool? ?? false,
      householdId:    json['householdId'] as int,
      appUserId:      json['appUserId'] as int,
      authorUsername: appUser?['username'] as String? ?? '',
      createdAt:      json['createdAt'] as String? ?? '',
    );
  }
}
