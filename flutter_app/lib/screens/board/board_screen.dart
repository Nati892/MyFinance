import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household/l10n/app_localizations.dart';
import 'package:household/screens/board/board_view_model.dart';
import 'package:household/screens/board/canvas_note_widget.dart';
import 'package:household/services/auth_service.dart';
import 'package:image_picker/image_picker.dart';

// ── Color helpers ─────────────────────────────────────────────────────────────

Color _hexColor(String hex, {Color fallback = const Color(0xFFFFF9C4)}) {
  try {
    final h = hex.trim().replaceFirst('#', '');
    if (h.length == 6) return Color(int.parse('FF$h', radix: 16));
    if (h.length == 8) return Color(int.parse(h, radix: 16));
    return fallback;
  } catch (_) {
    return fallback;
  }
}

String _relativeDate(String iso) {
  try {
    final dt = DateTime.parse(iso).toLocal();
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  } catch (_) {
    return '';
  }
}

// ── Note color palette used in the add sheet ─────────────────────────────────

const _kPalette = [
  '#fff9c4',
  '#f8bbd0',
  '#c8e6c9',
  '#b3e5fc',
  '#ffe0b2',
  '#e1bee7',
  '#ffffff',
];

const _kHeartColors = [
  '#e53935', // red
  '#e91e63', // pink
  '#ff7043', // deep orange
  '#8e24aa', // purple
];

// ── Screen ────────────────────────────────────────────────────────────────────

class BoardScreen extends ConsumerStatefulWidget {
  const BoardScreen({super.key});

  @override
  ConsumerState<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends ConsumerState<BoardScreen> {
  final _transformController = TransformationController();

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = ref.watch(boardViewModelProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      body: _buildBody(context, ref, vm),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddSheet(context, ref, vm),
        backgroundColor: const Color(0xFFE53935),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text(AppLocalizations.of(context)!.boardAddNote),
      ),
    );
  }

  // ── Body ──────────────────────────────────────────────────────────────────

  Widget _buildBody(BuildContext context, WidgetRef ref, BoardViewModel vm) {
    if (vm.noHousehold) {
      return Center(
        child: Text(
          AppLocalizations.of(context)!.boardSelectHousehold,
          style: const TextStyle(color: Color(0xFF888888)),
        ),
      );
    }

    switch (vm.state) {
      case BoardLoadState.loading:
        return _buildSkeleton();
      case BoardLoadState.error:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  color: Color(0xFFE53935), size: 40),
              const SizedBox(height: 12),
              Text(vm.errorMessage ?? AppLocalizations.of(context)!.boardLoadFailed,
                  style: const TextStyle(color: Color(0xFF888888))),
              const SizedBox(height: 12),
              TextButton(
                onPressed: vm.load,
                child: Text(AppLocalizations.of(context)!.boardTryAgain),
              ),
            ],
          ),
        );
      case BoardLoadState.idle:
        if (vm.notes.isEmpty) return _buildEmpty();
        return _buildCanvas(context, ref, vm);
    }
  }

  // ── Canvas ────────────────────────────────────────────────────────────────

  Widget _buildCanvas(BuildContext context, WidgetRef ref, BoardViewModel vm) {
    final currentUser = ref.read(authServiceProvider).currentUser;

    // Sort notes by zIndex
    final sortedNotes = [...vm.notes]..sort((a, b) => a.zIndex.compareTo(b.zIndex));

    return GestureDetector(
      onTap: () => vm.selectNote(null),
      child: InteractiveViewer(
        transformationController: _transformController,
        constrained: false,
        boundaryMargin: const EdgeInsets.all(300),
        minScale: 0.25,
        maxScale: 3.0,
        child: Container(
          width: 3000,
          height: 3000,
          color: const Color(0xFFFFF8F0),
          child: Stack(
            children: [
              // Canvas dot-grid background
              Positioned.fill(
                child: CustomPaint(painter: _DotGridPainter()),
              ),
              // Notes
              ...sortedNotes.map((note) {
                final isSelected = vm.selectedNoteId == note.id;
                final isOwner = currentUser?.username == note.authorUsername;
                return Positioned(
                  left: note.posX,
                  top: note.posY,
                  child: CanvasNoteWidget(
                    note: note,
                    isSelected: isSelected,
                    isOwner: isOwner,
                    onTap: () => vm.bringToFront(note.id),
                    onDragUpdate: (delta) => vm.moveNote(note.id, delta),
                    onDragEnd: () => vm.saveNotePosition(note.id),
                    onScaleUpdate: (scale, baseW, baseH) =>
                        vm.resizeNote(note.id, scale, baseW, baseH),
                    onScaleEnd: () {},
                    onRotateUpdate: (rot) => vm.rotateNote(note.id, rot),
                    onRotateEnd: () {},
                    onDelete: () => vm.deleteNote(note.id),
                    onColorChange: (color) =>
                        vm.updateNoteStyle(note.id, {'noteColor': color}),
                    onBoldChange: (bold) =>
                        vm.updateNoteStyle(note.id, {'isBold': bold}),
                    onUnderlineChange: (ul) =>
                        vm.updateNoteStyle(note.id, {'isUnderline': ul}),
                    onTextSizeChange: (size) =>
                        vm.updateNoteStyle(note.id, {'textSize': size}),
                    onDirectionChange: (dir) =>
                        vm.updateNoteStyle(note.id, {'textDirection': dir}),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  // ── Empty state ───────────────────────────────────────────────────────────

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('📌', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!.boardEmpty,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Color(0xFF5D4037),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.boardEmptySubtitle,
            style: const TextStyle(color: Color(0xFF8D6E63), fontSize: 14),
          ),
        ],
      ),
    );
  }

  // ── Skeleton ──────────────────────────────────────────────────────────────

  Widget _buildSkeleton() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: 6,
      itemBuilder: (_, __) => const _SkeletonCard(),
    );
  }

  // ── Add-note bottom sheet ─────────────────────────────────────────────────

  void _openAddSheet(BuildContext context, WidgetRef ref, BoardViewModel vm) {
    vm.openAddSheet();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => UncontrolledProviderScope(
        container: ProviderScope.containerOf(context),
        child: const _AddNoteSheet(),
      ),
    );
  }
}

// ── Dot-grid canvas background ────────────────────────────────────────────────

class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFDDCFBF)
      ..strokeWidth = 1;
    const spacing = 30.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.5, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotGridPainter oldDelegate) => false;
}

// ── Skeleton card ─────────────────────────────────────────────────────────────

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFEEE8E0),
        borderRadius: BorderRadius.circular(6),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _bar(12, 0.4),
          const SizedBox(height: 8),
          _bar(14, 1.0),
          const SizedBox(height: 6),
          _bar(14, 0.85),
          const SizedBox(height: 6),
          _bar(14, 0.6),
          const Spacer(),
          _bar(10, 0.35),
        ],
      ),
    );
  }

  Widget _bar(double h, double fraction) {
    return FractionallySizedBox(
      widthFactor: fraction,
      child: Container(
        height: h,
        decoration: BoxDecoration(
          color: const Color(0xFFD6CEBC),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}

// ── Add-note bottom sheet ─────────────────────────────────────────────────────

class _AddNoteSheet extends ConsumerStatefulWidget {
  const _AddNoteSheet();

  @override
  ConsumerState<_AddNoteSheet> createState() => _AddNoteSheetState();
}

class _AddNoteSheetState extends ConsumerState<_AddNoteSheet> {
  late final TextEditingController _contentCtrl;
  Uint8List? _pickedImageBytes;

  @override
  void initState() {
    super.initState();
    _contentCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() => _pickedImageBytes = bytes);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = ref.watch(boardViewModelProvider);
    final l10n = AppLocalizations.of(context)!;
    final isHeart = vm.formType == 'heart';
    final isImage = vm.formType == 'image';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Drag handle ────────────────────────────────────────────────
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFDDDDDD),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.boardNewNote,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF5D4037),
            ),
          ),
          const SizedBox(height: 16),

          // ── Type selector ─────────────────────────────────────────────
          Row(
            children: [
              _TypeChip(
                label: l10n.boardTypeText,
                icon: Icons.notes,
                selected: vm.formType == 'text',
                onTap: () => vm.setFormType('text'),
              ),
              const SizedBox(width: 8),
              _TypeChip(
                label: l10n.boardTypeHeart,
                icon: Icons.favorite,
                selected: vm.formType == 'heart',
                onTap: () => vm.setFormType('heart'),
              ),
              const SizedBox(width: 8),
              _TypeChip(
                label: l10n.boardTypeImage,
                icon: Icons.image_outlined,
                selected: vm.formType == 'image',
                onTap: () => vm.setFormType('image'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Content field (hidden for heart; upload for image) ────────
          if (!isHeart && !isImage) ...[
            TextField(
              controller: _contentCtrl,
              onChanged: vm.setFormContent,
              minLines: 3,
              maxLines: 6,
              decoration: InputDecoration(
                hintText: l10n.boardWritePlaceholder,
                hintStyle: const TextStyle(color: Color(0xFFBBBBBB)),
                filled: true,
                fillColor: const Color(0xFFFFF8EE),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (isImage) ...[
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 120,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F0EC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFDDD5CB)),
                ),
                clipBehavior: Clip.hardEdge,
                child: _pickedImageBytes != null
                    ? Image.memory(_pickedImageBytes!, fit: BoxFit.cover,
                        width: double.infinity)
                    : const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add_photo_alternate_outlined,
                                color: Color(0xFFBBBBBB), size: 40),
                            SizedBox(height: 6),
                            Text('Tap to pick an image',
                                style: TextStyle(
                                    color: Color(0xFFBBBBBB), fontSize: 13)),
                          ],
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── Note color palette (not shown for heart) ──────────────────
          if (!isHeart) ...[
            Text(
              l10n.boardNoteColor,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF8D6E63),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _kPalette.map((hex) {
                final selected = vm.formNoteColor == hex;
                return GestureDetector(
                  onTap: () => vm.setFormNoteColor(hex),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: _hexColor(hex),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected
                            ? const Color(0xFFE53935)
                            : Colors.transparent,
                        width: 2.5,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x18000000),
                          blurRadius: 3,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],

          // ── Heart color palette ───────────────────────────────────────
          if (isHeart) ...[
            Text(
              l10n.boardHeartColor,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF8D6E63),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: _kHeartColors.map((hex) {
                final selected = (vm.formHeartColor ?? _kHeartColors[0]) == hex;
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: GestureDetector(
                    onTap: () => vm.setFormHeartColor(hex),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      width: selected ? 36 : 28,
                      height: selected ? 36 : 28,
                      decoration: BoxDecoration(
                        color: _hexColor(hex),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _hexColor(hex).withValues(alpha: 0.4),
                            blurRadius: selected ? 8 : 3,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: selected
                          ? const Icon(Icons.check,
                              color: Colors.white, size: 16)
                          : null,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],

          // ── Error message ─────────────────────────────────────────────
          if (vm.sheetError != null) ...[
            Text(
              vm.sheetError!,
              style: const TextStyle(color: Color(0xFFE53935), fontSize: 13),
            ),
            const SizedBox(height: 8),
          ],

          // ── Save button ───────────────────────────────────────────────
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: vm.sheetSaving
                ? null
                : () async {
                    if (isImage) {
                      if (_pickedImageBytes == null) {
                        // nothing picked yet — bounce
                        return;
                      }
                      final b64 = base64Encode(_pickedImageBytes!);
                      vm.setFormContent('data:image/jpeg;base64,$b64');
                    }
                    final nav = Navigator.of(context);
                    await vm.saveNote();
                    if (!vm.sheetOpen && mounted) {
                      nav.pop();
                    }
                  },
            child: vm.sheetSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : Text(
                    l10n.boardPost,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 16),
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Type chip ─────────────────────────────────────────────────────────────────

class _TypeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _TypeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFE53935)
              : const Color(0xFFF5F0EC),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: selected ? Colors.white : const Color(0xFF8D6E63),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : const Color(0xFF8D6E63),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
