import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household/l10n/app_localizations.dart';
import 'package:household/models/board_note.dart';
import 'package:household/screens/board/board_view_model.dart';
import 'package:household/services/auth_service.dart';
import 'package:household/utils/color_utils.dart';

const _kNotePalette = [
  '#fff9c4',
  '#f8bbd0',
  '#c8e6c9',
  '#b3e5fc',
  '#ffe0b2',
  '#e1bee7',
  '#ffffff',
  '#ffccbc',
  '#d7ccc8',
  '#cfd8dc',
  '#ffeb3b',
  '#ff8a65',
  '#ba68c8',
  '#4fc3f7',
  '#81c784',
];

const _kHeartPalette = [
  '#e53935',
  '#e91e63',
  '#ff7043',
  '#8e24aa',
  '#ab47bc',
  '#5e35b1',
  '#3949ab',
  '#1e88e5',
  '#43a047',
  '#fbc02d',
];

class NoteDetailModal extends ConsumerStatefulWidget {
  final int noteId;

  const NoteDetailModal({super.key, required this.noteId});

  static Future<void> show(BuildContext context, int noteId) {
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (_) => NoteDetailModal(noteId: noteId),
    );
  }

  @override
  ConsumerState<NoteDetailModal> createState() => _NoteDetailModalState();
}

class _NoteDetailModalState extends ConsumerState<NoteDetailModal> {
  final TextEditingController _contentCtrl = TextEditingController();
  final TextEditingController _headerCtrl = TextEditingController();
  final FocusNode _bodyFocus = FocusNode();
  final FocusNode _headerFocus = FocusNode();

  bool _editingBody = false;
  bool _editingHeader = false;
  bool _seededControllers = false;
  bool _deleting = false;
  String _lastSyncedContent = '';
  String _lastSyncedHeader = '';

  @override
  void initState() {
    super.initState();
    _contentCtrl.addListener(_onTextChanged);
    _headerCtrl.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _maybeCommitOnClose();
    _contentCtrl.removeListener(_onTextChanged);
    _headerCtrl.removeListener(_onTextChanged);
    _bodyFocus.dispose();
    _headerFocus.dispose();
    _contentCtrl.dispose();
    _headerCtrl.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  void _maybeCommitOnClose() {
    if (_deleting) return;
    if (!_seededControllers) return;
    final vm = ref.read(boardViewModelProvider);
    final note = _findNote(vm);
    if (note == null) return;
    final canEdit = _canEdit(note);
    if (!canEdit) return;

    if (_contentCtrl.text != note.content) {
      vm.updateNoteContent(widget.noteId, _contentCtrl.text);
    }
    final headerText = _headerCtrl.text.trim();
    final stored = note.headerText ?? '';
    if (headerText != stored) {
      vm.updateNoteHeaderText(
        widget.noteId,
        headerText.isEmpty ? null : headerText,
      );
    }
  }

  BoardNote? _findNote(BoardViewModel vm) {
    for (final n in vm.notes) {
      if (n.id == widget.noteId) return n;
    }
    return null;
  }

  bool _canEdit(BoardNote note) {
    final currentUser = ref.read(authServiceProvider).currentUser;
    final isOwner = currentUser?.id == note.appUserId;
    return isOwner || !note.locked;
  }

  void _seedControllers(BoardNote note) {
    if (!_seededControllers) {
      _contentCtrl.text = note.content;
      _headerCtrl.text = note.headerText ?? '';
      _lastSyncedContent = note.content;
      _lastSyncedHeader = note.headerText ?? '';
      _seededControllers = true;
      return;
    }
    if (!_editingBody && note.content != _lastSyncedContent) {
      _contentCtrl.text = note.content;
      _lastSyncedContent = note.content;
    }
    final remoteHeader = note.headerText ?? '';
    if (!_editingHeader && remoteHeader != _lastSyncedHeader) {
      _headerCtrl.text = remoteHeader;
      _lastSyncedHeader = remoteHeader;
    }
  }

  void _enterBodyEdit() {
    if (_editingBody) return;
    setState(() => _editingBody = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bodyFocus.requestFocus();
    });
  }

  void _enterHeaderEdit() {
    if (_editingHeader) return;
    setState(() => _editingHeader = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _headerFocus.requestFocus();
    });
  }

  bool _isDirtyForNote(BoardNote note) {
    if (!_seededControllers) return false;
    if (_contentCtrl.text != note.content) return true;
    final headerText = _headerCtrl.text.trim();
    final stored = note.headerText ?? '';
    if (headerText != stored) return true;
    return false;
  }

  void _saveAll(BoardViewModel vm, BoardNote note) {
    if (_contentCtrl.text != note.content) {
      vm.updateNoteContent(widget.noteId, _contentCtrl.text);
      _lastSyncedContent = _contentCtrl.text;
    }
    final headerText = _headerCtrl.text.trim();
    final stored = note.headerText ?? '';
    if (headerText != stored) {
      vm.updateNoteHeaderText(
        widget.noteId,
        headerText.isEmpty ? null : headerText,
      );
      _lastSyncedHeader = headerText;
    }
    _bodyFocus.unfocus();
    _headerFocus.unfocus();
    setState(() {
      _editingBody = false;
      _editingHeader = false;
    });
  }

  Future<void> _confirmDelete(BoardViewModel vm) async {
    final l = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: Text(l.boardDeleteConfirm),
        content: Text(l.boardDeleteMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dctx).pop(false),
            child: Text(l.boardCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dctx).pop(true),
            child: Text(
              l.boardDelete,
              style: const TextStyle(color: Color(0xFFE53935)),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    _deleting = true;
    Navigator.of(context).pop();
    // Fire and forget — VM removes the note from state and updates the canvas.
    // Awaiting here would let notifyListeners rebuild this modal after pop with
    // a null lookup, briefly showing an empty barrier.
    unawaited(vm.deleteNote(widget.noteId));
  }

  @override
  Widget build(BuildContext context) {
    final vm = ref.watch(boardViewModelProvider);
    final note = _findNote(vm);

    if (note == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
      return const SizedBox.shrink();
    }

    _seedControllers(note);

    final currentUser = ref.read(authServiceProvider).currentUser;
    final isOwner = currentUser?.id == note.appUserId;
    final canEdit = isOwner || !note.locked;
    final lockedForViewer = note.locked && !isOwner;

    final bgColor = hexColor(note.noteColor);
    final headerColor = darken(bgColor, 0.15);
    final headerLuminance = headerColor.computeLuminance();
    final headerFg =
        headerLuminance > 0.35 ? const Color(0xFF3E2723) : Colors.white;
    final bodyTextColor =
        hexColor(note.textColor, fallback: const Color(0xFF333333));
    final showSettingsBar = !lockedForViewer;
    final isDirty = canEdit && _isDirtyForNote(note);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (sheetCtx, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 16,
                offset: Offset(0, -2),
              ),
            ],
          ),
          child: Stack(
            children: [
              Column(
                children: [
                  _buildHandle(headerFg),
                  _buildHeader(note, headerColor, headerFg, canEdit, vm),
                  if (lockedForViewer)
                    _buildLockedBanner(note, bodyTextColor),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: EdgeInsets.fromLTRB(
                        20,
                        16,
                        20,
                        showSettingsBar ? 96 : 36,
                      ),
                      child: _buildBody(note, canEdit),
                    ),
                  ),
                ],
              ),
              Positioned(
                right: 14,
                bottom:
                    (showSettingsBar ? 76 : 12) +
                    MediaQuery.of(sheetCtx).padding.bottom,
                child: _buildWatermark(note, bodyTextColor),
              ),
              if (showSettingsBar)
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12 + MediaQuery.of(sheetCtx).padding.bottom,
                  child: _buildSettingsBar(note, vm, isOwner),
                ),
              if (isDirty)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: (showSettingsBar ? 80 : 24) +
                      MediaQuery.of(sheetCtx).padding.bottom,
                  child: Center(child: _buildSavePill(vm, note)),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSavePill(BoardViewModel vm, BoardNote note) {
    final l = AppLocalizations.of(context)!;
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(28),
      color: const Color(0xFF43A047),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: () => _saveAll(vm, note),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.save, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                l.boardSave,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHandle(Color fg) {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      height: 4,
      width: 40,
      decoration: BoxDecoration(
        color: fg.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildHeader(
    BoardNote note,
    Color headerColor,
    Color headerFg,
    bool canEdit,
    BoardViewModel vm,
  ) {
    final l = AppLocalizations.of(context)!;
    final hasHeaderText = (note.headerText ?? '').isNotEmpty;
    final placeholderText = note.authorUsername.isNotEmpty
        ? note.authorUsername
        : l.boardNoteHeaderPlaceholder;
    final headerStyle = TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: hasHeaderText
          ? headerFg
          : headerFg.withValues(alpha: 0.55),
      fontStyle: hasHeaderText ? FontStyle.normal : FontStyle.italic,
    );

    final Widget headerContent;
    if (_editingHeader) {
      headerContent = TextField(
        controller: _headerCtrl,
        focusNode: _headerFocus,
        maxLength: 120,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _saveAll(vm, note),
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: headerFg,
        ),
        cursorColor: headerFg,
        decoration: InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.zero,
          border: InputBorder.none,
          counterText: '',
          hintText: l.boardNoteHeaderPlaceholder,
          hintStyle: headerStyle.copyWith(
            color: headerFg.withValues(alpha: 0.45),
          ),
        ),
      );
    } else {
      headerContent = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: canEdit ? _enterHeaderEdit : null,
        child: Text(
          hasHeaderText ? note.headerText! : placeholderText,
          overflow: TextOverflow.ellipsis,
          style: headerStyle,
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      decoration: BoxDecoration(color: headerColor),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          if (note.locked)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(Icons.lock, size: 16, color: headerFg),
            ),
          Expanded(child: headerContent),
          IconButton(
            tooltip: 'Close',
            icon: Icon(Icons.close, color: headerFg),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildLockedBanner(BoardNote note, Color textColor) {
    final l = AppLocalizations.of(context)!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.black.withValues(alpha: 0.06),
      child: Row(
        children: [
          Icon(Icons.lock, size: 14, color: textColor.withValues(alpha: 0.7)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              l.boardLockedByOwner(note.authorUsername),
              style: TextStyle(
                fontSize: 12,
                color: textColor.withValues(alpha: 0.7),
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWatermark(BoardNote note, Color textColor) {
    final l = AppLocalizations.of(context)!;
    return IgnorePointer(
      child: Text(
        l.boardWatermarkBy(note.authorUsername),
        style: TextStyle(
          fontSize: 11,
          fontStyle: FontStyle.italic,
          color: textColor.withValues(alpha: 0.45),
        ),
      ),
    );
  }

  Widget _buildBody(BoardNote note, bool canEdit) {
    switch (note.type) {
      case 'image':
        return _buildImageBody(note);
      case 'heart':
        return _buildHeartBody(note);
      default:
        return _buildTextBody(note, canEdit);
    }
  }

  Widget _buildImageBody(BoardNote note) {
    final content = note.content;
    final image = content.startsWith('data:image')
        ? Image.memory(
            base64Decode(content.split(',').last),
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) =>
                const Icon(Icons.broken_image, size: 64, color: Colors.grey),
          )
        : Image.network(
            content,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) =>
                const Icon(Icons.broken_image, size: 64, color: Colors.grey),
          );
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 200),
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4,
          child: image,
        ),
      ),
    );
  }

  Widget _buildHeartBody(BoardNote note) {
    final heartColor = hexColor(note.heartColor ?? '#e53935');
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Icon(Icons.favorite, color: heartColor, size: 220),
      ),
    );
  }

  Widget _buildTextBody(BoardNote note, bool canEdit) {
    final l = AppLocalizations.of(context)!;
    final textColor = hexColor(note.textColor, fallback: const Color(0xFF333333));
    final td = note.textDirection == 'rtl'
        ? TextDirection.rtl
        : TextDirection.ltr;
    final style = TextStyle(
      color: textColor,
      fontSize: note.textSize.toDouble(),
      fontWeight: note.isBold ? FontWeight.bold : FontWeight.normal,
      decoration: note.isUnderline ? TextDecoration.underline : null,
      height: 1.4,
    );

    if (_editingBody) {
      return Directionality(
        textDirection: td,
        child: TextField(
          controller: _contentCtrl,
          focusNode: _bodyFocus,
          style: style,
          maxLines: null,
          minLines: 6,
          decoration: const InputDecoration(
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
            isDense: true,
          ),
        ),
      );
    }

    final placeholderStyle = style.copyWith(
      color: style.color?.withValues(alpha: 0.5),
      fontStyle: FontStyle.italic,
    );
    final display = note.content.isEmpty
        ? Text(
            canEdit ? l.boardWritePlaceholder : '',
            style: placeholderStyle,
          )
        : Text(note.content, style: style);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: canEdit ? _enterBodyEdit : null,
      child: Directionality(
        textDirection: td,
        child: SizedBox(
          width: double.infinity,
          child: display,
        ),
      ),
    );
  }

  Widget _buildSettingsBar(BoardNote note, BoardViewModel vm, bool isOwner) {
    final l = AppLocalizations.of(context)!;
    final isText = note.type == 'text';
    final isHeart = note.type == 'heart';

    final children = <Widget>[
      _swatchButton(note, vm, isHeart: isHeart),
      if (isText) ...[
        _toolBtn(
          icon: Icons.format_bold,
          active: note.isBold,
          onTap: () => vm.updateNoteStyle(
            widget.noteId,
            {'isBold': !note.isBold},
          ),
        ),
        _toolBtn(
          icon: Icons.format_underlined,
          active: note.isUnderline,
          onTap: () => vm.updateNoteStyle(
            widget.noteId,
            {'isUnderline': !note.isUnderline},
          ),
        ),
        _toolBtn(
          icon: Icons.text_decrease,
          active: false,
          onTap: () => vm.updateNoteStyle(
            widget.noteId,
            {'textSize': (note.textSize - 2).clamp(8, 48)},
          ),
        ),
        _toolBtn(
          icon: Icons.text_increase,
          active: false,
          onTap: () => vm.updateNoteStyle(
            widget.noteId,
            {'textSize': (note.textSize + 2).clamp(8, 48)},
          ),
        ),
        _toolBtn(
          icon: note.textDirection == 'rtl'
              ? Icons.format_textdirection_r_to_l
              : Icons.format_textdirection_l_to_r,
          active: false,
          onTap: () => vm.updateNoteStyle(
            widget.noteId,
            {
              'textDirection': note.textDirection == 'rtl' ? 'ltr' : 'rtl',
            },
          ),
        ),
      ],
      const Spacer(),
      if (isOwner)
        _toolBtn(
          icon: note.locked ? Icons.lock : Icons.lock_open,
          active: note.locked,
          tooltip: note.locked ? l.boardUnlockNote : l.boardLockNote,
          onTap: () => vm.updateNoteLocked(widget.noteId, !note.locked),
        ),
      if (isOwner)
        _toolBtn(
          icon: Icons.delete_outline,
          active: false,
          color: const Color(0xFFE53935),
          onTap: () => _confirmDelete(vm),
        ),
    ];

    return Material(
      elevation: 10,
      borderRadius: BorderRadius.circular(28),
      color: Colors.white,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(children: children),
      ),
    );
  }

  Widget _swatchButton(
    BoardNote note,
    BoardViewModel vm, {
    required bool isHeart,
  }) {
    final currentHex = isHeart ? (note.heartColor ?? '#e53935') : note.noteColor;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: GestureDetector(
        onTap: () => _showColorGrid(note, vm, isHeart: isHeart),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: hexColor(currentHex),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.black26, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _toolBtn({
    required IconData icon,
    required bool active,
    required VoidCallback onTap,
    Color? color,
    String? tooltip,
  }) {
    final btn = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkResponse(
        onTap: onTap,
        radius: 22,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: active ? const Color(0xFF667EEA) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 20,
            color: active
                ? Colors.white
                : (color ?? const Color(0xFF555555)),
          ),
        ),
      ),
    );
    if (tooltip != null) return Tooltip(message: tooltip, child: btn);
    return btn;
  }

  void _showColorGrid(
    BoardNote note,
    BoardViewModel vm, {
    required bool isHeart,
  }) {
    final palette = isHeart ? _kHeartPalette : _kNotePalette;
    final currentHex = isHeart ? (note.heartColor ?? '#e53935') : note.noteColor;
    final l = AppLocalizations.of(context)!;

    showDialog<void>(
      context: context,
      barrierColor: Colors.black45,
      builder: (dctx) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420, maxHeight: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 12, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          l.boardNoteColor,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(dctx).pop(),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Wrap(
                      spacing: 14,
                      runSpacing: 14,
                      children: [
                        ...palette.map((hex) {
                          final isCurrent =
                              hex.toLowerCase() == currentHex.toLowerCase();
                          return _SwatchTile(
                            color: hexColor(hex),
                            isCurrent: isCurrent,
                            onTap: () {
                              vm.updateNoteStyle(
                                widget.noteId,
                                isHeart
                                    ? {'heartColor': hex}
                                    : {'noteColor': hex},
                              );
                              Navigator.of(dctx).pop();
                            },
                          );
                        }),
                        _RainbowSwatchTile(
                          onTap: () {
                            Navigator.of(dctx).pop();
                            _openCustomColorPicker(note, vm, isHeart: isHeart);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openCustomColorPicker(
    BoardNote note,
    BoardViewModel vm, {
    required bool isHeart,
  }) {
    final startHex = isHeart ? (note.heartColor ?? '#e53935') : note.noteColor;
    Color picked = hexColor(startHex);
    final l = AppLocalizations.of(context)!;

    showDialog<void>(
      context: context,
      builder: (dctx) {
        return AlertDialog(
          title: Text(l.boardNoteColor),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: picked,
              onColorChanged: (c) => picked = c,
              enableAlpha: false,
              labelTypes: const [],
              pickerAreaHeightPercent: 0.6,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dctx).pop(),
              child: Text(l.boardCancel),
            ),
            TextButton(
              onPressed: () {
                final hex = '#${picked.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
                vm.updateNoteStyle(
                  widget.noteId,
                  isHeart ? {'heartColor': hex} : {'noteColor': hex},
                );
                Navigator.of(dctx).pop();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }
}

class _SwatchTile extends StatelessWidget {
  final Color color;
  final bool isCurrent;
  final VoidCallback onTap;

  const _SwatchTile({
    required this.color,
    required this.isCurrent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isCurrent ? const Color(0xFF667EEA) : Colors.black26,
            width: isCurrent ? 3 : 1.5,
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: isCurrent
            ? Icon(
                Icons.check,
                size: 22,
                color: color.computeLuminance() > 0.45
                    ? const Color(0xFF3E2723)
                    : Colors.white,
              )
            : null,
      ),
    );
  }
}

class _RainbowSwatchTile extends StatelessWidget {
  final VoidCallback onTap;
  const _RainbowSwatchTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: SweepGradient(
            colors: [
              Color(0xFFE53935),
              Color(0xFFFB8C00),
              Color(0xFFFDD835),
              Color(0xFF43A047),
              Color(0xFF1E88E5),
              Color(0xFF8E24AA),
              Color(0xFFE53935),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(Icons.colorize, color: Colors.white),
      ),
    );
  }
}
