import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household/l10n/app_localizations.dart';
import 'package:household/models/board_note.dart';
import 'package:household/models/shopping_session.dart';
import 'package:household/models/shopping_store.dart';
import 'package:household/screens/board/board_view_model.dart';
import 'package:household/screens/board/canvas_note_widget.dart';
import 'package:household/screens/board/canvas_shopping_session_widget.dart';
import 'package:household/screens/board/note_detail_modal.dart';
import 'package:household/screens/board/shopping_view_model.dart';
import 'package:household/screens/shopping/shopping_management_screen.dart';
import 'package:household/screens/shopping/shopping_session_panel.dart';
import 'package:household/services/auth_service.dart';
import 'package:household/utils/color_utils.dart';
import 'package:image_picker/image_picker.dart';

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
        if (vm.notes.isEmpty && vm.sessions.isEmpty) return _buildEmpty();
        return _buildCanvas(context, ref, vm);
    }
  }

  // ── Canvas ────────────────────────────────────────────────────────────────

  Widget _buildCanvas(BuildContext context, WidgetRef ref, BoardViewModel vm) {
    final currentUser = ref.read(authServiceProvider).currentUser;
    final shoppingVm = ref.watch(shoppingViewModelProvider);

    // Sorted lists are maintained on the view model.
    final sortedNotes = vm.sortedNotes;
    final sortedSessions = vm.sortedSessions;

    return GestureDetector(
      onTap: () {
        vm.selectNote(null);
        vm.selectSession(null);
      },
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
              // Notes — each wrapped in _DraggableNoteItem which owns its own
              // position state to avoid rebuilding the whole canvas on every frame.
              ...sortedNotes.map((note) {
                final isSelected = vm.selectedNoteId == note.id;
                final isOwner = currentUser?.id == note.appUserId;
                return _DraggableNoteItem(
                  key: ValueKey(note.id),
                  note: note,
                  isSelected: isSelected,
                  isOwner: isOwner,
                  onPositionCommit: (x, y) => vm.commitNotePosition(note.id, x, y),
                  onTap: () {
                    vm.bringToFront(note.id);
                    NoteDetailModal.show(context, note.id);
                  },
                  onScaleUpdate: (scale, baseW, baseH) =>
                      vm.resizeNote(note.id, scale, baseW, baseH),
                  onScaleEnd: () {},
                  onRotateUpdate: (rot) => vm.rotateNote(note.id, rot),
                  onRotateEnd: () {},
                );
              }),
              // Shopping sessions
              ...sortedSessions.map((session) {
                return _DraggableSessionItem(
                  key: ValueKey('session_${session.id}'),
                  session: session,
                  isSelected: vm.selectedSessionId == session.id,
                  stores: shoppingVm.stores,
                  onPositionCommit: (x, y) =>
                      vm.commitSessionPosition(session.id, x, y),
                  onTap: () => _openSessionPanel(context, session),
                  onScaleUpdate: (scale, baseW, baseH) =>
                      vm.resizeSession(session.id, scale, baseW, baseH),
                  onScaleEnd: () {},
                  onRotateUpdate: (rot) => vm.rotateSession(session.id, rot),
                  onRotateEnd: () {},
                  onDelete: () => vm.deleteSession(session.id),
                  onPlay: () => _openSessionPanel(context, session),
                  onPatchItem: (itemId, patch) =>
                      vm.patchSessionItem(session.id, itemId, patch),
                  onCreateStore: shoppingVm.createStore,
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

  // ── Open 90% session panel ────────────────────────────────────────────────

  void _openSessionPanel(BuildContext context, ShoppingSession session) {
    final container = ProviderScope.containerOf(context);
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => UncontrolledProviderScope(
        container: container,
        child: ShoppingSessionPanel(
          sessionId: session.id,
          onManage: ({initialTab = 0}) =>
              _openManagementScreen(context, container, initialTab: initialTab),
        ),
      ),
    );
  }

  void _openManagementScreen(
    BuildContext context,
    ProviderContainer container, {
    int initialTab = 0,
  }) {
    Navigator.of(context, rootNavigator: true).push(MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => UncontrolledProviderScope(
        container: container,
        child: ShoppingManagementScreen(initialTab: initialTab),
      ),
    ));
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
  // Shopping sub-tab step: 0 = template pick, 1 = item selection
  int _shoppingStep = 0;

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
    final svm = ref.watch(shoppingViewModelProvider);
    final l10n = AppLocalizations.of(context)!;
    final isShopping = vm.formType == 'shopping';
    final isHeart = vm.formType == 'heart';
    final isImage = vm.formType == 'image';
    final selectedColor = vm.formNoteColor;

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
          Wrap(
            spacing: 8,
            children: [
              _TypeChip(
                label: l10n.boardTypeText,
                icon: Icons.notes,
                selected: vm.formType == 'text',
                onTap: () { vm.setFormType('text'); setState(() => _shoppingStep = 0); },
              ),
              _TypeChip(
                label: l10n.boardTypeHeart,
                icon: Icons.favorite,
                selected: vm.formType == 'heart',
                onTap: () { vm.setFormType('heart'); setState(() => _shoppingStep = 0); },
              ),
              _TypeChip(
                label: l10n.boardTypeImage,
                icon: Icons.image_outlined,
                selected: vm.formType == 'image',
                onTap: () { vm.setFormType('image'); setState(() => _shoppingStep = 0); },
              ),
              _TypeChip(
                label: l10n.shoppingTab,
                icon: Icons.shopping_cart_outlined,
                selected: vm.formType == 'shopping',
                onTap: () {
                  vm.setFormType('shopping');
                  setState(() => _shoppingStep = 0);
                  svm.resetForm();
                  svm.loadAll();
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Shopping tab ──────────────────────────────────────────────
          if (isShopping) ...[
            _ShoppingFormContent(
              svm: svm,
              boardVm: vm,
              step: _shoppingStep,
              onStepChange: (s) => setState(() => _shoppingStep = s),
              onDone: () => Navigator.of(context).pop(),
            ),
          ],

          // ── Content field (hidden for heart/image/shopping) ───────────
          if (!isHeart && !isImage && !isShopping) ...[
            TextField(
              controller: _contentCtrl,
              onChanged: vm.setFormContent,
              minLines: 3,
              maxLines: 6,
              decoration: InputDecoration(
                hintText: l10n.boardWritePlaceholder,
                hintStyle: const TextStyle(color: Color(0xFFBBBBBB)),
                filled: true,
                fillColor: Color(int.parse(selectedColor.replaceFirst('#', 'FF'), radix: 16)),
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

          // ── Note color palette (not shown for heart or shopping) ──────
          if (!isHeart && !isShopping) ...[
            Text(
              l10n.boardNoteColor,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF8D6E63),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            _ColorPalette(
              palette: _kPalette,
              selected: vm.formNoteColor,
              onSelect: vm.setFormNoteColor,
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
                        color: hexColor(hex),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: hexColor(hex).withValues(alpha: 0.4),
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

          // ── Save button (only for non-shopping tabs) ──────────────────
          if (!isShopping)
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
                        if (_pickedImageBytes == null) return;
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

// ── Draggable shopping session item ──────────────────────────────────────────

class _DraggableSessionItem extends StatefulWidget {
  final ShoppingSession session;
  final bool isSelected;
  final List<ShoppingStore> stores;
  final void Function(double x, double y) onPositionCommit;
  final VoidCallback onTap;
  final void Function(double scale, double baseW, double baseH) onScaleUpdate;
  final VoidCallback onScaleEnd;
  final void Function(double rotation) onRotateUpdate;
  final VoidCallback onRotateEnd;
  final VoidCallback onDelete;
  final VoidCallback onPlay;
  final void Function(int itemId, Map<String, dynamic> patch) onPatchItem;
  final Future<ShoppingStore?> Function(String name) onCreateStore;

  const _DraggableSessionItem({
    required super.key,
    required this.session,
    required this.isSelected,
    required this.stores,
    required this.onPositionCommit,
    required this.onTap,
    required this.onScaleUpdate,
    required this.onScaleEnd,
    required this.onRotateUpdate,
    required this.onRotateEnd,
    required this.onDelete,
    required this.onPlay,
    required this.onPatchItem,
    required this.onCreateStore,
  });

  @override
  State<_DraggableSessionItem> createState() => _DraggableSessionItemState();
}

class _DraggableSessionItemState extends State<_DraggableSessionItem> {
  late double _x, _y;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _x = widget.session.posX;
    _y = widget.session.posY;
  }

  @override
  void didUpdateWidget(_DraggableSessionItem old) {
    super.didUpdateWidget(old);
    if (!_isDragging &&
        (old.session.posX != widget.session.posX ||
            old.session.posY != widget.session.posY)) {
      _x = widget.session.posX;
      _y = widget.session.posY;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _x,
      top: _y,
      child: RepaintBoundary(
        child: CanvasShoppingSessionWidget(
          key: ValueKey('inner_${widget.session.id}'),
          session: widget.session,
          isSelected: widget.isSelected,
          stores: widget.stores,
          onTap: widget.onTap,
          onDragUpdate: (delta) {
            setState(() {
              _isDragging = true;
              _x += delta.dx;
              _y += delta.dy;
            });
          },
          onDragEnd: () {
            _isDragging = false;
            widget.onPositionCommit(_x, _y);
          },
          onScaleUpdate: widget.onScaleUpdate,
          onScaleEnd: widget.onScaleEnd,
          onRotateUpdate: widget.onRotateUpdate,
          onRotateEnd: widget.onRotateEnd,
          onDelete: widget.onDelete,
          onPlay: widget.onPlay,
          onPatchItem: widget.onPatchItem,
          onCreateStore: widget.onCreateStore,
        ),
      ),
    );
  }
}

// ── Color palette with rainbow swatch ────────────────────────────────────────

class _ColorPalette extends StatelessWidget {
  final List<String> palette;
  final String selected;
  final void Function(String hex) onSelect;

  const _ColorPalette({
    required this.palette,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ...palette.map((hex) {
          final isSelected = selected == hex;
          return GestureDetector(
            onTap: () => onSelect(hex),
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: hexColor(hex),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
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
        }),
        // Rainbow swatch — opens full color picker
        GestureDetector(
          onTap: () => _openColorPicker(context),
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const SweepGradient(
                colors: [
                  Color(0xFFFF0000),
                  Color(0xFFFFFF00),
                  Color(0xFF00FF00),
                  Color(0xFF00FFFF),
                  Color(0xFF0000FF),
                  Color(0xFFFF00FF),
                  Color(0xFFFF0000),
                ],
              ),
              border: Border.all(
                color: Colors.transparent,
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
        ),
      ],
    );
  }

  void _openColorPicker(BuildContext context) {
    Color current = hexColor(selected);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        contentPadding: const EdgeInsets.all(16),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: current,
            onColorChanged: (c) => current = c,
            enableAlpha: false,
            labelTypes: const [],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final hex = '#${current.toARGB32().toRadixString(16).substring(2)}';
              onSelect(hex);
              Navigator.of(ctx).pop();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

// ── Shopping form content (inside bottom sheet) ───────────────────────────────

class _ShoppingFormContent extends StatefulWidget {
  final ShoppingViewModel svm;
  final BoardViewModel boardVm;
  final int step;
  final void Function(int step) onStepChange;
  final VoidCallback onDone;

  const _ShoppingFormContent({
    required this.svm,
    required this.boardVm,
    required this.step,
    required this.onStepChange,
    required this.onDone,
  });

  @override
  State<_ShoppingFormContent> createState() => _ShoppingFormContentState();
}

class _ShoppingFormContentState extends State<_ShoppingFormContent> {
  final _listNameCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  // For new item sub-form
  final _newItemNameCtrl = TextEditingController();
  final _newItemNameHeCtrl = TextEditingController();

  @override
  void dispose() {
    _listNameCtrl.dispose();
    _searchCtrl.dispose();
    _newItemNameCtrl.dispose();
    _newItemNameHeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final svm = widget.svm;
    if (svm.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Step 0: name + template pick + color ──────────────────────
        if (widget.step == 0) ...[
          // Session name field
          TextField(
            controller: _listNameCtrl,
            onChanged: svm.setFormSessionName,
            textDirection: TextDirection.rtl,
            decoration: InputDecoration(
              hintText: AppLocalizations.of(context)!.shoppingListName,
              hintStyle: const TextStyle(color: Color(0xFFBBBBBB)),
              filled: true,
              fillColor: const Color(0xFFF5F0EC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 12),
          // Template picker
          if (svm.lists.isNotEmpty) ...[
            Text(
              AppLocalizations.of(context)!.shoppingPickTemplate,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF8D6E63),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<int?>(
              initialValue: svm.formSourceListId,
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFFF5F0EC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: [
                DropdownMenuItem<int?>(
                  value: null,
                  child: Text(AppLocalizations.of(context)!.shoppingNewList),
                ),
                ...svm.lists.map((l) => DropdownMenuItem<int?>(
                      value: l.id,
                      child: Text(l.name),
                    )),
              ],
              onChanged: svm.setSourceList,
            ),
            const SizedBox(height: 12),
          ],
          // Color picker
          Text(
            AppLocalizations.of(context)!.boardNoteColor,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF8D6E63),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          _ColorPalette(
            palette: _kPalette,
            selected: svm.formSessionColor,
            onSelect: svm.setFormSessionColor,
          ),
          const SizedBox(height: 12),
          // Plan block
          _PlanBlock(svm: svm),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: svm.formSessionName.trim().isEmpty
                ? null
                : () => widget.onStepChange(1),
            child: Text(AppLocalizations.of(context)!.shoppingSelectItems),
          ),
        ],

        // ── Step 1: item selection ─────────────────────────────────────
        if (widget.step == 1) ...[
          // New item sub-form
          if (svm.showNewItemForm) ...[
            _NewItemForm(
              svm: svm,
              nameCtrl: _newItemNameCtrl,
              nameHeCtrl: _newItemNameHeCtrl,
            ),
          ] else ...[
            // Search
            TextField(
              controller: _searchCtrl,
              onChanged: svm.setSearchQuery,
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context)!.shoppingSearchItems,
                hintStyle: const TextStyle(color: Color(0xFFBBBBBB)),
                prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF8D6E63)),
                filled: true,
                fillColor: const Color(0xFFF5F0EC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              ),
            ),
            const SizedBox(height: 8),
            // Item list (constrained height, scrollable)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: svm.filteredItems.isEmpty
                  ? Center(
                      child: Text(
                        AppLocalizations.of(context)!.shoppingNoItems,
                        style: const TextStyle(color: Color(0xFF8D6E63), fontSize: 13),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: svm.filteredItems.length,
                      itemBuilder: (ctx, i) {
                        final item = svm.filteredItems[i];
                        final selected = svm.isSelected(item.id);
                        return ListTile(
                          dense: true,
                          leading: item.icon != null
                              ? Text(item.icon!, style: const TextStyle(fontSize: 20))
                              : const Icon(Icons.shopping_basket_outlined,
                                  size: 20, color: Color(0xFF8D6E63)),
                          title: Text(
                            item.nameHe ?? item.name,
                            style: const TextStyle(fontSize: 13),
                            textDirection: TextDirection.rtl,
                          ),
                          subtitle: item.category != null
                              ? Text(
                                  item.category!.nameHe ?? item.category!.name,
                                  style: const TextStyle(fontSize: 11),
                                )
                              : null,
                          trailing: selected
                              ? const Icon(Icons.check_circle,
                                  color: Color(0xFFE53935))
                              : const Icon(Icons.radio_button_unchecked,
                                  color: Color(0xFFCCCCCC)),
                          onTap: () => svm.toggleItem(item),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 8),
            // Add new item button
            OutlinedButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: Text(AppLocalizations.of(context)!.shoppingAddItem),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF5D4037),
                side: const BorderSide(color: Color(0xFF5D4037)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: svm.openNewItemForm,
            ),
            const SizedBox(height: 8),
            // Selected items summary
            if (svm.selectedItems.isNotEmpty) ...[
              Text(
                '${svm.selectedItems.length} item(s) selected',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF8D6E63),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
            ],
            // Error
            if (svm.saveError != null) ...[
              Text(
                svm.saveError!,
                style: const TextStyle(color: Color(0xFFE53935), fontSize: 13),
              ),
              const SizedBox(height: 8),
            ],
            // Save session button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE53935),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: svm.saving
                  ? null
                  : () async {
                      final session = await svm.saveSession();
                      if (session != null) {
                        await widget.boardVm.addSession(session);
                        widget.onDone();
                      }
                    },
              child: svm.saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(AppLocalizations.of(context)!.shoppingSave),
            ),
          ],
        ],
      ],
    );
  }
}

// ── New item sub-form ─────────────────────────────────────────────────────────

class _NewItemForm extends StatelessWidget {
  final ShoppingViewModel svm;
  final TextEditingController nameCtrl;
  final TextEditingController nameHeCtrl;

  const _NewItemForm({
    required this.svm,
    required this.nameCtrl,
    required this.nameHeCtrl,
  });

  static const _units = ['pcs', 'kg', 'g', 'L', 'ml', 'lbs'];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.shoppingNewItemTitle,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF5D4037),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: nameCtrl,
          onChanged: svm.setNewItemName,
          decoration: InputDecoration(
            hintText: l10n.shoppingItemName,
            hintStyle: const TextStyle(color: Color(0xFFBBBBBB)),
            filled: true,
            fillColor: const Color(0xFFF5F0EC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.all(10),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: nameHeCtrl,
          onChanged: svm.setNewItemNameHe,
          textDirection: TextDirection.rtl,
          decoration: InputDecoration(
            hintText: l10n.shoppingItemNameHe,
            hintStyle: const TextStyle(color: Color(0xFFBBBBBB)),
            filled: true,
            fillColor: const Color(0xFFF5F0EC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.all(10),
          ),
        ),
        const SizedBox(height: 6),
        // Unit + category row
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: svm.newItemUnit,
                decoration: InputDecoration(
                  labelText: l10n.shoppingUnit,
                  labelStyle: const TextStyle(fontSize: 12),
                  filled: true,
                  fillColor: const Color(0xFFF5F0EC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                items: _units
                    .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                    .toList(),
                onChanged: (v) { if (v != null) svm.setNewItemUnit(v); },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<int?>(
                initialValue: svm.newItemCategoryId,
                decoration: InputDecoration(
                  labelText: l10n.shoppingCategory,
                  labelStyle: const TextStyle(fontSize: 12),
                  filled: true,
                  fillColor: const Color(0xFFF5F0EC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('None')),
                  ...svm.categories.map((c) => DropdownMenuItem<int?>(
                        value: c.id,
                        child: Text(c.nameHe ?? c.name, overflow: TextOverflow.ellipsis),
                      )),
                ],
                onChanged: svm.setNewItemCategory,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: svm.closeNewItemForm,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF8D6E63),
                  side: const BorderSide(color: Color(0xFF8D6E63)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE53935),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () async {
                  await svm.saveNewItem();
                },
                child: Text(l10n.shoppingAddItem),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ── Plan block (reveals when user ticks "Plan this for later") ────────────────

class _PlanBlock extends StatefulWidget {
  final ShoppingViewModel svm;

  const _PlanBlock({required this.svm});

  @override
  State<_PlanBlock> createState() => _PlanBlockState();
}

class _PlanBlockState extends State<_PlanBlock> {
  final _minCtrl = TextEditingController();
  final _maxCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _minCtrl.text = widget.svm.formPlanMinPrice?.toStringAsFixed(0) ?? '';
    _maxCtrl.text = widget.svm.formPlanMaxPrice?.toStringAsFixed(0) ?? '';
  }

  @override
  void dispose() {
    _minCtrl.dispose();
    _maxCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final svm = widget.svm;
    final l10n = AppLocalizations.of(context)!;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7EF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFEEE4D8)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(
              l10n.shoppingPlanForLater,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF5D4037)),
            ),
            value: svm.formPlanEnabled,
            activeThumbColor: const Color(0xFFE53935),
            onChanged: svm.setPlanEnabled,
          ),
          if (svm.formPlanEnabled) ...[
            const SizedBox(height: 4),
            // Category picker
            DropdownButtonFormField<int?>(
              initialValue: svm.formExpenseCategoryId,
              decoration: InputDecoration(
                labelText: l10n.shoppingPlanCategory,
                labelStyle: const TextStyle(fontSize: 12),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
              items: svm.expenseCategories
                  .map((c) => DropdownMenuItem<int?>(
                        value: c.id,
                        child: Text(c.nameHe ?? c.name, overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: svm.setExpenseCategoryId,
            ),
            const SizedBox(height: 8),
            // Min / max price
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _minCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      labelText: l10n.shoppingPlanMinPrice,
                      labelStyle: const TextStyle(fontSize: 12),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    onChanged: (v) => svm.setPlanMinPrice(double.tryParse(v)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _maxCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      labelText: l10n.shoppingPlanMaxPrice,
                      labelStyle: const TextStyle(fontSize: 12),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    onChanged: (v) => svm.setPlanMaxPrice(double.tryParse(v)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Month picker
            OutlinedButton.icon(
              icon: const Icon(Icons.calendar_month, size: 16),
              label: Text(_monthLabel(svm.formPlanYear, svm.formPlanMonth, l10n)),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF5D4037),
                side: const BorderSide(color: Color(0xFFDDD5CB)),
                alignment: Alignment.centerLeft,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                minimumSize: const Size.fromHeight(40),
              ),
              onPressed: () => _pickMonth(context, svm),
            ),
            const SizedBox(height: 8),
            // Week-of-month chips
            Text(
              l10n.shoppingPlanWeek,
              style: const TextStyle(fontSize: 12, color: Color(0xFF8D6E63), fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _WeekChip(
                  label: l10n.shoppingPlanWholeMonth,
                  selected: svm.formPlanWeekOfMonth == null,
                  onTap: () => svm.setPlanWeekOfMonth(null),
                ),
                for (var w = 1; w <= 5; w++)
                  _WeekChip(
                    label: 'W$w',
                    selected: svm.formPlanWeekOfMonth == w,
                    onTap: () => svm.setPlanWeekOfMonth(w),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(
                l10n.shoppingPlanAddToBudget,
                style: const TextStyle(fontSize: 13, color: Color(0xFF5D4037)),
              ),
              value: svm.formAddToBudgetPlan,
              activeColor: const Color(0xFFE53935),
              onChanged: (v) => svm.setAddToBudgetPlan(v ?? false),
            ),
          ],
        ],
      ),
    );
  }

  String _monthLabel(int? year, int? month, AppLocalizations l10n) {
    if (year == null || month == null) return l10n.shoppingPlanMonth;
    const names = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${names[month - 1]} $year';
  }

  Future<void> _pickMonth(BuildContext context, ShoppingViewModel svm) async {
    final now = DateTime.now();
    final initial = DateTime(
      svm.formPlanYear ?? now.year,
      svm.formPlanMonth ?? now.month,
    );
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      initialDatePickerMode: DatePickerMode.year,
      helpText: AppLocalizations.of(context)!.shoppingPlanPickMonth,
    );
    if (picked != null) {
      svm.setPlanYear(picked.year);
      svm.setPlanMonth(picked.month);
    }
  }
}

class _WeekChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _WeekChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE53935) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? const Color(0xFFE53935) : const Color(0xFFDDD5CB),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : const Color(0xFF5D4037),
          ),
        ),
      ),
    );
  }
}

// ── Draggable note item — owns position state to avoid full-canvas rebuilds ───

class _DraggableNoteItem extends StatefulWidget {
  final BoardNote note;
  final bool isSelected;
  final bool isOwner;
  final void Function(double x, double y) onPositionCommit;
  final VoidCallback onTap;
  final void Function(double scale, double baseW, double baseH) onScaleUpdate;
  final VoidCallback onScaleEnd;
  final void Function(double rotation) onRotateUpdate;
  final VoidCallback onRotateEnd;

  const _DraggableNoteItem({
    required super.key,
    required this.note,
    required this.isSelected,
    required this.isOwner,
    required this.onPositionCommit,
    required this.onTap,
    required this.onScaleUpdate,
    required this.onScaleEnd,
    required this.onRotateUpdate,
    required this.onRotateEnd,
  });

  @override
  State<_DraggableNoteItem> createState() => _DraggableNoteItemState();
}

class _DraggableNoteItemState extends State<_DraggableNoteItem> {
  late double _x, _y;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _x = widget.note.posX;
    _y = widget.note.posY;
  }

  @override
  void didUpdateWidget(_DraggableNoteItem old) {
    super.didUpdateWidget(old);
    // Accept external position changes (e.g. socket updates) only when not dragging.
    if (!_isDragging &&
        (old.note.posX != widget.note.posX || old.note.posY != widget.note.posY)) {
      _x = widget.note.posX;
      _y = widget.note.posY;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _x,
      top: _y,
      child: RepaintBoundary(
        child: CanvasNoteWidget(
          note: widget.note,
          isSelected: widget.isSelected,
          isOwner: widget.isOwner,
          onTap: widget.onTap,
          onDragUpdate: (delta) {
            setState(() {
              _isDragging = true;
              _x += delta.dx;
              _y += delta.dy;
            });
          },
          onDragEnd: () {
            _isDragging = false;
            widget.onPositionCommit(_x, _y);
          },
          onScaleUpdate: widget.onScaleUpdate,
          onScaleEnd: widget.onScaleEnd,
          onRotateUpdate: widget.onRotateUpdate,
          onRotateEnd: widget.onRotateEnd,
        ),
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
