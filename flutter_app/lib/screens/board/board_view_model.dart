import 'dart:async';
import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household/models/board_note.dart';
import 'package:household/repositories/board_repository.dart';
import 'package:household/services/household_service.dart';

final boardViewModelProvider =
    ChangeNotifierProvider.autoDispose<BoardViewModel>((ref) {
  return BoardViewModel(
    ref.read(boardRepositoryProvider),
    ref.read(householdServiceProvider),
  );
});

enum BoardLoadState { idle, loading, error }

class BoardViewModel extends ChangeNotifier {
  final BoardRepository _repo;
  final HouseholdService _householdService;

  BoardViewModel(this._repo, this._householdService) {
    load();
  }

  // ── Data ─────────────────────────────────────────────────────────────────

  List<BoardNote> notes = [];

  // ── Canvas interaction ────────────────────────────────────────────────────

  int? selectedNoteId;
  final Map<int, Timer> _saveTimers = {};

  // ── State ─────────────────────────────────────────────────────────────────

  BoardLoadState state = BoardLoadState.loading;
  String? errorMessage;

  // ── Add-note bottom sheet ─────────────────────────────────────────────────

  bool sheetOpen = false;
  bool sheetSaving = false;
  String? sheetError;

  // Form fields for the add-note sheet
  String formContent = '';
  String formType = 'text'; // 'text' | 'heart' | 'image'
  String formNoteColor = '#fff9c4';
  String? formHeartColor;

  bool get noHousehold => _householdService.currentHouseholdId == null;

  // ── Load ──────────────────────────────────────────────────────────────────

  Future<void> load() async {
    final hid = _householdService.currentHouseholdId;
    if (hid == null) {
      state = BoardLoadState.idle;
      notifyListeners();
      return;
    }
    state = BoardLoadState.loading;
    notifyListeners();
    try {
      notes = await _repo.getNotes(hid);
      state = BoardLoadState.idle;
    } catch (e) {
      state = BoardLoadState.error;
      errorMessage = e.toString();
    }
    notifyListeners();
  }

  // ── Bottom sheet ──────────────────────────────────────────────────────────

  void openAddSheet() {
    formContent = '';
    formType = 'text';
    formNoteColor = '#fff9c4';
    formHeartColor = null;
    sheetError = null;
    sheetOpen = true;
    notifyListeners();
  }

  void closeSheet() {
    sheetOpen = false;
    sheetError = null;
    notifyListeners();
  }

  void setFormContent(String v) {
    formContent = v;
    notifyListeners();
  }

  void setFormType(String v) {
    formType = v;
    notifyListeners();
  }

  void setFormNoteColor(String v) {
    formNoteColor = v;
    notifyListeners();
  }

  void setFormHeartColor(String? v) {
    formHeartColor = v;
    notifyListeners();
  }

  Future<void> saveNote() async {
    final hid = _householdService.currentHouseholdId;
    if (hid == null) return;

    if (formContent.trim().isEmpty && formType != 'heart') {
      sheetError = 'Please enter some content.';
      notifyListeners();
      return;
    }

    sheetSaving = true;
    sheetError = null;
    notifyListeners();

    try {
      final body = <String, dynamic>{
        'content': formContent.trim(),
        'type': formType,
        'noteColor': formNoteColor,
        'householdId': hid,
        if (formHeartColor != null) 'heartColor': formHeartColor,
      };

      final created = await _repo.createNote(body);
      notes = [created, ...notes];
      sheetSaving = false;
      sheetOpen = false;
      notifyListeners();
    } catch (e) {
      sheetSaving = false;
      sheetError = 'Failed to save. Please try again.';
      notifyListeners();
    }
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  Future<void> deleteNote(int id) async {
    try {
      await _repo.deleteNote(id);
      notes = notes.where((n) => n.id != id).toList();
      notifyListeners();
    } catch (_) {}
  }

  // ── Note color cycling (quick UI action) ─────────────────────────────────

  static const _noteColors = [
    '#fff9c4', // yellow
    '#f8bbd0', // pink
    '#c8e6c9', // green
    '#b3e5fc', // blue
    '#ffe0b2', // orange
    '#e1bee7', // purple
    '#ffffff', // white
  ];

  Future<void> cycleNoteColor(BoardNote note) async {
    final idx = _noteColors.indexOf(note.noteColor);
    final nextColor = _noteColors[(idx + 1) % _noteColors.length];
    try {
      final updated = await _repo.updateNote(note.id, {'noteColor': nextColor});
      notes = notes.map((n) => n.id == note.id ? updated : n).toList();
      notifyListeners();
    } catch (_) {}
  }

  // ── Canvas helpers ────────────────────────────────────────────────────────

  int get maxZIndex =>
      notes.isEmpty ? 1 : notes.map((n) => n.zIndex).reduce((a, b) => a > b ? a : b);

  void selectNote(int? id) {
    selectedNoteId = id;
    notifyListeners();
  }

  Future<void> bringToFront(int id) async {
    final newZ = maxZIndex + 1;
    notes = notes.map((n) => n.id == id ? n.copyWith(zIndex: newZ) : n).toList();
    selectedNoteId = id;
    notifyListeners();
    try {
      await _repo.updateNote(id, {'zIndex': newZ});
    } catch (_) {}
  }

  /// Called by _DraggableNoteItem when drag ends. Updates in-memory position
  /// and schedules API save — no notifyListeners needed because the widget
  /// already moved visually via local setState.
  void commitNotePosition(int id, double x, double y) {
    notes = notes.map((n) => n.id == id ? n.copyWith(posX: x, posY: y) : n).toList();
    _saveTimers[id]?.cancel();
    _saveTimers[id] = Timer(const Duration(milliseconds: 200), () {
      _repo.updateNote(id, {'posX': x, 'posY': y});
    });
  }

  Future<void> updateNoteContent(int id, String content) async {
    notes = notes.map((n) => n.id == id ? n.copyWith(content: content) : n).toList();
    notifyListeners();
    try {
      await _repo.updateNote(id, {'content': content});
    } catch (_) {}
  }

  void resizeNote(int id, double scaleFactor, double baseWidth, double baseHeight) {
    final newW = (baseWidth * scaleFactor).clamp(80.0, 400.0).toInt();
    final newH = (baseHeight * scaleFactor).clamp(80.0, 400.0).toInt();
    notes = notes.map((n) => n.id == id ? n.copyWith(width: newW, height: newH) : n).toList();
    notifyListeners();

    _saveTimers[id]?.cancel();
    _saveTimers[id] = Timer(const Duration(milliseconds: 500), () {
      _repo.updateNote(id, {'width': newW, 'height': newH});
    });
  }

  void rotateNote(int id, double rotation) {
    notes = notes.map((n) => n.id == id ? n.copyWith(rotation: rotation) : n).toList();
    notifyListeners();

    _saveTimers[id]?.cancel();
    _saveTimers[id] = Timer(const Duration(milliseconds: 500), () {
      _repo.updateNote(id, {'rotation': rotation});
    });
  }

  Future<void> updateNoteStyle(int id, Map<String, dynamic> props) async {
    notes = notes.map((n) {
      if (n.id != id) return n;
      return n.copyWith(
        noteColor: props['noteColor'] as String?,
        textColor: props['textColor'] as String?,
        textSize: props['textSize'] as int?,
        isBold: props['isBold'] as bool?,
        isUnderline: props['isUnderline'] as bool?,
        textDirection: props['textDirection'] as String?,
      );
    }).toList();
    notifyListeners();
    try {
      await _repo.updateNote(id, props);
    } catch (_) {}
  }
}
