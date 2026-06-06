import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:household/models/board_note.dart';
import 'package:household/utils/color_utils.dart';

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
  });

  @override
  State<CanvasNoteWidget> createState() => _CanvasNoteWidgetState();
}

class _CanvasNoteWidgetState extends State<CanvasNoteWidget> {
  double _baseWidth = 0;
  double _baseHeight = 0;
  double _startRotation = 0;
  bool _isScaling = false;

  double _effectiveWidth() => (widget.note.width ?? 170).toDouble();
  double _effectiveHeight() => (widget.note.height ?? 190).toDouble();

  @override
  Widget build(BuildContext context) {
    final w = _effectiveWidth();
    final h = _effectiveHeight();
    final isHeart = widget.note.type == 'heart';

    final bgColor = hexColor(widget.note.noteColor);
    final headerColor = darken(bgColor, 0.15);
    final textColor = hexColor(widget.note.textColor, fallback: const Color(0xFF333333));

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
          height: h,
          child: isHeart
              ? _buildHeartContent(w, h)
              : _buildNoteCard(w, h, bgColor, headerColor, textColor),
        ),
      ),
    );
  }

  Widget _buildHeartContent(double w, double h) {
    final heartColor = hexColor(widget.note.heartColor ?? '#e53935');
    final size = (w < h ? w : h) * 0.75;
    return Center(
      child: Icon(Icons.favorite, color: heartColor, size: size),
    );
  }

  Widget _buildNoteCard(
    double w,
    double h,
    Color bgColor,
    Color headerColor,
    Color textColor,
  ) {
    final headerLuminance = headerColor.computeLuminance();
    final iconColor = headerLuminance > 0.35 ? const Color(0xFF3E2723) : Colors.white;

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
                  style: TextStyle(fontSize: 10, color: iconColor.withValues(alpha: 0.75)),
                ),
                const Spacer(),
              ],
            ),
          ),
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
      default:
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
              decoration:
                  widget.note.isUnderline ? TextDecoration.underline : null,
            ),
          ),
        );
    }
  }
}
