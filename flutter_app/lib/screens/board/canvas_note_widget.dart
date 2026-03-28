import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:household/models/board_note.dart';

class CanvasNoteWidget extends StatefulWidget {
  final BoardNote note;
  final bool isSelected;
  final bool isOwner;
  final VoidCallback onTap;
  final void Function(Offset delta) onDragUpdate;
  final VoidCallback onDragEnd;
  final void Function(double scaleFactor, double baseW, double baseH) onScaleUpdate;
  final VoidCallback onScaleEnd;
  final void Function(double rotation) onRotateUpdate;
  final VoidCallback onRotateEnd;
  final VoidCallback onDelete;
  final void Function(String color) onColorChange;
  final void Function(bool bold) onBoldChange;
  final void Function(bool underline) onUnderlineChange;
  final void Function(int size) onTextSizeChange;
  final void Function(String dir) onDirectionChange;

  const CanvasNoteWidget({
    super.key,
    required this.note,
    required this.isSelected,
    required this.isOwner,
    required this.onTap,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onScaleUpdate,
    required this.onScaleEnd,
    required this.onRotateUpdate,
    required this.onRotateEnd,
    required this.onDelete,
    required this.onColorChange,
    required this.onBoldChange,
    required this.onUnderlineChange,
    required this.onTextSizeChange,
    required this.onDirectionChange,
  });

  @override
  State<CanvasNoteWidget> createState() => _CanvasNoteWidgetState();
}

class _CanvasNoteWidgetState extends State<CanvasNoteWidget> {
  double _baseWidth = 0;
  double _baseHeight = 0;
  double _startRotation = 0;
  bool _isScaling = false;

  static const _kNoteColors = [
    '#fff9c4', '#f8bbd0', '#c8e6c9', '#b3e5fc',
    '#ffe0b2', '#e1bee7', '#ffffff', '#ffccbc',
  ];

  Color _hexColor(String hex, {Color fallback = const Color(0xFFFFF9C4)}) {
    try {
      final h = hex.trim().replaceFirst('#', '');
      if (h.length == 6) return Color(int.parse('FF$h', radix: 16));
      return fallback;
    } catch (_) {
      return fallback;
    }
  }

  Color _darken(Color color, [double amount = 0.15]) {
    final hsl = HSLColor.fromColor(color);
    return hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0)).toColor();
  }

  double _effectiveWidth() => (widget.note.width ?? 170).toDouble();
  double _effectiveHeight() => (widget.note.height ?? 190).toDouble();

  @override
  Widget build(BuildContext context) {
    final w = _effectiveWidth();
    final h = _effectiveHeight();
    final isHeart = widget.note.type == 'heart';

    // When selected, non-heart notes need extra height below for the toolbar.
    final toolbarExtraH = (widget.isSelected && !isHeart) ? 60.0 : 0.0;

    final bgColor = _hexColor(widget.note.noteColor);
    final headerColor = _darken(bgColor, 0.1);
    final textColor = _hexColor(widget.note.textColor, fallback: const Color(0xFF333333));

    return Transform.rotate(
      angle: widget.note.rotation,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onScaleStart: (details) {
          if (details.pointerCount >= 2) {
            _isScaling = true;
            _baseWidth = w;
            _baseHeight = h;
            _startRotation = widget.note.rotation;
          }
        },
        onScaleUpdate: (details) {
          if (_isScaling && details.pointerCount >= 2) {
            widget.onScaleUpdate(details.scale, _baseWidth, _baseHeight);
            widget.onRotateUpdate(_startRotation + details.rotation);
          } else if (!_isScaling) {
            widget.onDragUpdate(details.focalPointDelta);
          }
        },
        onScaleEnd: (details) {
          if (_isScaling) {
            widget.onScaleEnd();
            widget.onRotateEnd();
            _isScaling = false;
          } else {
            widget.onDragEnd();
          }
        },
        child: SizedBox(
          width: w,
          height: h + toolbarExtraH,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Main note content
              SizedBox(
                width: w,
                height: h,
                child: isHeart
                    ? _buildHeartContent(w, h)
                    : _buildNoteCard(w, h, bgColor, headerColor, textColor),
              ),
              // Delete button for heart (overlay top-right corner)
              if (widget.isSelected && widget.isOwner && isHeart)
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: widget.onDelete,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, size: 14, color: Colors.white),
                    ),
                  ),
                ),
              // Toolbar for text/image notes (inside GestureDetector bounds)
              if (widget.isSelected && !isHeart)
                _buildToolbar(w, h),
            ],
          ),
        ),
      ),
    );
  }

  /// Heart notes: just the icon, no card or header.
  Widget _buildHeartContent(double w, double h) {
    final heartColor = _hexColor(widget.note.heartColor ?? '#e53935');
    final size = (w < h ? w : h) * 0.75;
    return Center(
      child: Icon(Icons.favorite, color: heartColor, size: size),
    );
  }

  /// Regular note card with header + content area.
  Widget _buildNoteCard(
    double w,
    double h,
    Color bgColor,
    Color headerColor,
    Color textColor,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: widget.isSelected
                ? const Color(0xFF667EEA).withValues(alpha: 0.4)
                : Colors.black.withValues(alpha: 0.15),
            blurRadius: widget.isSelected ? 12 : 6,
            offset: const Offset(2, 3),
          ),
        ],
        border: widget.isSelected
            ? Border.all(color: const Color(0xFF667EEA), width: 2)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header bar
          Container(
            height: 28,
            decoration: BoxDecoration(
              color: headerColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                Text(
                  widget.note.authorUsername,
                  style: const TextStyle(fontSize: 10, color: Colors.white70),
                ),
                const Spacer(),
                if (widget.isOwner && widget.isSelected)
                  GestureDetector(
                    onTap: widget.onDelete,
                    child: const Icon(Icons.close, size: 14, color: Colors.white70),
                  ),
              ],
            ),
          ),
          // Content area
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: _buildContent(textColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(Color textColor) {
    switch (widget.note.type) {
      case 'image':
        final content = widget.note.content;
        return ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: content.startsWith('data:image')
              ? Image.memory(
                  base64Decode(content.split(',').last),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
                )
              : Image.network(
                  content,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
                ),
        );
      default: // text
        final td = widget.note.textDirection == 'rtl'
            ? TextDirection.rtl
            : TextDirection.ltr;
        return Directionality(
          textDirection: td,
          child: Text(
            widget.note.content,
            style: TextStyle(
              color: textColor,
              fontSize: widget.note.textSize.toDouble(),
              fontWeight: widget.note.isBold ? FontWeight.bold : FontWeight.normal,
              decoration: widget.note.isUnderline ? TextDecoration.underline : null,
            ),
          ),
        );
    }
  }

  /// Toolbar positioned below the note card, within GestureDetector bounds.
  Widget _buildToolbar(double noteWidth, double noteHeight) {
    return Positioned(
      top: noteHeight + 6,
      left: 0,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Color picker
              PopupMenuButton<String>(
                icon: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: _hexColor(widget.note.noteColor),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black26),
                  ),
                ),
                itemBuilder: (_) => _kNoteColors
                    .map((hex) => PopupMenuItem<String>(
                          value: hex,
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: _hexColor(hex),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ))
                    .toList(),
                onSelected: widget.onColorChange,
                tooltip: 'Color',
              ),
              // Bold, underline, text size, direction (text notes only)
              if (widget.note.type == 'text') ...[
                _ToolbarBtn(
                  icon: Icons.format_bold,
                  active: widget.note.isBold,
                  onTap: () => widget.onBoldChange(!widget.note.isBold),
                ),
                _ToolbarBtn(
                  icon: Icons.format_underlined,
                  active: widget.note.isUnderline,
                  onTap: () => widget.onUnderlineChange(!widget.note.isUnderline),
                ),
                _ToolbarBtn(
                  icon: Icons.text_decrease,
                  active: false,
                  onTap: () => widget.onTextSizeChange((widget.note.textSize - 2).clamp(8, 32)),
                ),
                _ToolbarBtn(
                  icon: Icons.text_increase,
                  active: false,
                  onTap: () => widget.onTextSizeChange((widget.note.textSize + 2).clamp(8, 32)),
                ),
                _ToolbarBtn(
                  icon: widget.note.textDirection == 'rtl'
                      ? Icons.format_textdirection_r_to_l
                      : Icons.format_textdirection_l_to_r,
                  active: false,
                  onTap: () => widget.onDirectionChange(
                      widget.note.textDirection == 'rtl' ? 'ltr' : 'rtl'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolbarBtn extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _ToolbarBtn({required this.icon, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF667EEA) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          icon,
          size: 16,
          color: active ? Colors.white : const Color(0xFF555555),
        ),
      ),
    );
  }
}
