import 'dart:async';
import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household/models/board_note.dart';
import 'package:household/models/expense.dart';
import 'package:household/models/shopping_session.dart';
import 'package:household/models/shopping_session_item.dart';
import 'package:household/repositories/board_repository.dart';
import 'package:household/repositories/shopping_repository.dart';
import 'package:household/services/household_service.dart';

final boardViewModelProvider =
    ChangeNotifierProvider.autoDispose<BoardViewModel>((ref) {
  return BoardViewModel(
    ref.read(boardRepositoryProvider),
    ref.read(shoppingRepositoryProvider),
    ref.read(householdServiceProvider),
  );
});

enum BoardLoadState { idle, loading, error }

class BoardViewModel extends ChangeNotifier {
  final BoardRepository _repo;
  final ShoppingRepository _shoppingRepo;
  final HouseholdService _householdService;

  BoardViewModel(this._repo, this._shoppingRepo, this._householdService) {
    load();
  }

  // ── Data ─────────────────────────────────────────────────────────────────

  List<BoardNote> _notes = [];
  List<ShoppingSession> _sessions = [];
  List<BoardNote> _sortedNotes = const [];
  List<ShoppingSession> _sortedSessions = const [];

  List<BoardNote> get notes => _notes;
  List<ShoppingSession> get sessions => _sessions;
  List<BoardNote> get sortedNotes => _sortedNotes;
  List<ShoppingSession> get sortedSessions => _sortedSessions;

  set notes(List<BoardNote> v) {
    _notes = v;
    _sortedNotes = [...v]..sort((a, b) => a.zIndex.compareTo(b.zIndex));
  }

  set sessions(List<ShoppingSession> v) {
    _sessions = v;
    _sortedSessions = [...v]..sort((a, b) => a.zIndex.compareTo(b.zIndex));
  }

  // ── Canvas interaction ────────────────────────────────────────────────────

  int? selectedNoteId;
  int? selectedSessionId;

  // Keep note and session save timers in separate maps — there's no ID collision,
  // and it avoids the old `id + 100000` hack.
  final Map<int, Timer> _noteSaveTimers = {};
  final Map<int, Timer> _sessionSaveTimers = {};

  @override
  void dispose() {
    for (final t in _noteSaveTimers.values) {
      t.cancel();
    }
    for (final t in _sessionSaveTimers.values) {
      t.cancel();
    }
    _noteSaveTimers.clear();
    _sessionSaveTimers.clear();
    super.dispose();
  }

  // ── State ─────────────────────────────────────────────────────────────────

  BoardLoadState state = BoardLoadState.loading;
  String? errorMessage;

  // ── Add-note bottom sheet ─────────────────────────────────────────────────

  bool sheetOpen = false;
  bool sheetSaving = false;
  String? sheetError;

  // Form fields for the add-note sheet
  String formContent = '';
  String formType = 'text'; // 'text' | 'heart' | 'image' | 'shopping'
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
      final results = await Future.wait([
        _repo.getNotes(hid),
        _shoppingRepo.getSessions(hid),
      ]);
      notes = results[0] as List<BoardNote>;
      sessions = results[1] as List<ShoppingSession>;
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
      notes = [created, ..._notes];
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
    _noteSaveTimers.remove(id)?.cancel();
    try {
      await _repo.deleteNote(id);
      notes = _notes.where((n) => n.id != id).toList();
      if (selectedNoteId == id) selectedNoteId = null;
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
      notes = _notes.map((n) => n.id == note.id ? updated : n).toList();
      notifyListeners();
    } catch (_) {}
  }

  // ── Canvas helpers ────────────────────────────────────────────────────────

  int get maxZIndex =>
      _notes.isEmpty ? 1 : _notes.map((n) => n.zIndex).reduce((a, b) => a > b ? a : b);

  void selectNote(int? id) {
    selectedNoteId = id;
    notifyListeners();
  }

  Future<void> bringToFront(int id) async {
    final newZ = maxZIndex + 1;
    notes = _notes.map((n) => n.id == id ? n.copyWith(zIndex: newZ) : n).toList();
    selectedNoteId = id;
    notifyListeners();
    try {
      await _repo.updateNote(id, {'zIndex': newZ});
    } catch (_) {}
  }

  /// Called by the draggable note widget when drag ends. Updates in-memory
  /// position and schedules the API save — the widget itself has already
  /// moved visually via local setState, so we skip notifyListeners.
  void commitNotePosition(int id, double x, double y) {
    notes = _notes.map((n) => n.id == id ? n.copyWith(posX: x, posY: y) : n).toList();
    _noteSaveTimers[id]?.cancel();
    _noteSaveTimers[id] = Timer(const Duration(milliseconds: 200), () {
      _repo.updateNote(id, {'posX': x, 'posY': y});
    });
  }

  Future<void> updateNoteContent(int id, String content) async {
    notes = _notes.map((n) => n.id == id ? n.copyWith(content: content) : n).toList();
    notifyListeners();
    try {
      await _repo.updateNote(id, {'content': content});
    } catch (_) {}
  }

  void resizeNote(int id, double scaleFactor, double baseWidth, double baseHeight) {
    final newW = (baseWidth * scaleFactor).clamp(80.0, 400.0).toInt();
    final newH = (baseHeight * scaleFactor).clamp(80.0, 400.0).toInt();
    notes = _notes.map((n) => n.id == id ? n.copyWith(width: newW, height: newH) : n).toList();
    notifyListeners();

    _noteSaveTimers[id]?.cancel();
    _noteSaveTimers[id] = Timer(const Duration(milliseconds: 500), () {
      _repo.updateNote(id, {'width': newW, 'height': newH});
    });
  }

  void rotateNote(int id, double rotation) {
    notes = _notes.map((n) => n.id == id ? n.copyWith(rotation: rotation) : n).toList();
    notifyListeners();

    _noteSaveTimers[id]?.cancel();
    _noteSaveTimers[id] = Timer(const Duration(milliseconds: 500), () {
      _repo.updateNote(id, {'rotation': rotation});
    });
  }

  Future<void> updateNoteStyle(int id, Map<String, dynamic> props) async {
    notes = _notes.map((n) {
      if (n.id != id) return n;
      return n.copyWith(
        noteColor: props['noteColor'] as String?,
        textColor: props['textColor'] as String?,
        textSize: props['textSize'] as int?,
        isBold: props['isBold'] as bool?,
        isUnderline: props['isUnderline'] as bool?,
        textDirection: props['textDirection'] as String?,
        heartColor: props['heartColor'] as String?,
      );
    }).toList();
    notifyListeners();
    try {
      await _repo.updateNote(id, props);
    } catch (_) {}
  }

  Future<void> updateNoteHeaderText(int id, String? headerText) async {
    notes = _notes.map((n) {
      if (n.id != id) return n;
      return n.copyWith(headerText: headerText);
    }).toList();
    notifyListeners();
    try {
      await _repo.updateNote(id, {'headerText': headerText});
    } catch (_) {}
  }

  Future<void> updateNoteLocked(int id, bool locked) async {
    notes = _notes.map((n) {
      if (n.id != id) return n;
      return n.copyWith(locked: locked);
    }).toList();
    notifyListeners();
    try {
      await _repo.updateNote(id, {'locked': locked});
    } catch (_) {}
  }

  // ── Shopping session canvas helpers ───────────────────────────────────────

  void selectSession(int? id) {
    selectedSessionId = id;
    selectedNoteId = null;
    notifyListeners();
  }

  Future<void> addSession(ShoppingSession session) async {
    sessions = [session, ..._sessions];
    notifyListeners();
  }

  /// Replace a session in-place (e.g. after completion or plan updates).
  void replaceSession(ShoppingSession updated) {
    sessions = _sessions.map((s) => s.id == updated.id ? updated : s).toList();
    notifyListeners();
  }

  Future<void> deleteSession(int id) async {
    _sessionSaveTimers.remove(id)?.cancel();
    try {
      await _shoppingRepo.deleteSession(id);
      sessions = _sessions.where((s) => s.id != id).toList();
      if (selectedSessionId == id) selectedSessionId = null;
      notifyListeners();
    } catch (_) {}
  }

  void commitSessionPosition(int id, double x, double y) {
    sessions = _sessions.map((s) => s.id == id ? s.copyWith(posX: x, posY: y) : s).toList();
    _sessionSaveTimers[id]?.cancel();
    _sessionSaveTimers[id] = Timer(const Duration(milliseconds: 200), () {
      _shoppingRepo.updateSession(id, {'posX': x, 'posY': y});
    });
  }

  void resizeSession(int id, double scaleFactor, double baseWidth, double baseHeight) {
    final newW = (baseWidth * scaleFactor).clamp(150.0, 500.0).toInt();
    final newH = (baseHeight * scaleFactor).clamp(150.0, 600.0).toInt();
    sessions = _sessions.map((s) => s.id == id ? s.copyWith(width: newW, height: newH) : s).toList();
    notifyListeners();
    _sessionSaveTimers[id]?.cancel();
    _sessionSaveTimers[id] = Timer(const Duration(milliseconds: 500), () {
      _shoppingRepo.updateSession(id, {'width': newW, 'height': newH});
    });
  }

  void rotateSession(int id, double rotation) {
    sessions = _sessions.map((s) => s.id == id ? s.copyWith(rotation: rotation) : s).toList();
    notifyListeners();
    _sessionSaveTimers[id]?.cancel();
    _sessionSaveTimers[id] = Timer(const Duration(milliseconds: 500), () {
      _shoppingRepo.updateSession(id, {'rotation': rotation});
    });
  }

  Future<void> bringSessionToFront(int id) async {
    final maxZ = _sessions.isEmpty
        ? 1
        : _sessions.map((s) => s.zIndex).reduce((a, b) => a > b ? a : b);
    final newZ = maxZ + 1;
    sessions = _sessions.map((s) => s.id == id ? s.copyWith(zIndex: newZ) : s).toList();
    selectedSessionId = id;
    notifyListeners();
    try {
      await _shoppingRepo.updateSession(id, {'zIndex': newZ});
    } catch (_) {}
  }

  Future<void> patchSessionItem(
      int sessionId, int sessionItemId, Map<String, dynamic> body) async {
    try {
      final updated = await _shoppingRepo.patchSessionItem(sessionId, sessionItemId, body);
      sessions = _sessions.map((s) {
        if (s.id != sessionId) return s;
        final newItems = s.sessionItems.map((it) => it.id == sessionItemId ? updated : it).toList();
        return s.copyWith(sessionItems: newItems);
      }).toList();
      notifyListeners();
    } catch (_) {}
  }

  /// Complete the session (creates an expense on the server, marks completedAt).
  /// Returns the created Expense on success, or null on failure.
  Future<Expense?> completeSessionAndCreateExpense(
      int sessionId, Map<String, dynamic> body) async {
    try {
      final result = await _shoppingRepo.completeSession(sessionId, body);
      // Server returns the updated session without items — preserve local items.
      final local = _sessions.firstWhere((s) => s.id == sessionId,
          orElse: () => result.session);
      sessions = _sessions
          .map((s) => s.id == sessionId
              ? result.session.copyWith(sessionItems: local.sessionItems)
              : s)
          .toList();
      notifyListeners();
      return result.expense;
    } catch (_) {
      return null;
    }
  }

  /// Flip a planned session to active (without opening the fill screen).
  /// Used when the user taps Play on a planned card.
  Future<void> startPlannedSession(int sessionId) async {
    try {
      await _shoppingRepo.updateSession(sessionId, {'mode': 'active'});
      sessions = _sessions
          .map((s) => s.id == sessionId
              ? s.copyWith(mode: ShoppingSessionMode.active)
              : s)
          .toList();
      notifyListeners();
    } catch (_) {}
  }

  /// Assign a template list to a session: sets listId, switches mode to active,
  /// and adds all template items as session items.
  Future<void> assignListToSession(
      int sessionId, int listId, List<Map<String, dynamic>> itemBodies) async {
    try {
      await _shoppingRepo.updateSession(
          sessionId, {'listId': listId, 'mode': 'active'});
      final added = <ShoppingSessionItem>[];
      for (final body in itemBodies) {
        final item = await _shoppingRepo.addSessionItem(sessionId, body);
        added.add(item);
      }
      sessions = _sessions.map((s) {
        if (s.id != sessionId) return s;
        return s.copyWith(
          mode: ShoppingSessionMode.active,
          sessionItems: [...s.sessionItems, ...added],
        );
      }).toList();
      notifyListeners();
    } catch (_) {}
  }

  /// Update the session-level store ("where did I shop?").
  Future<void> updateSessionStore(int sessionId, int? storeId) async {
    try {
      await _shoppingRepo.updateSession(sessionId, {'storeId': storeId});
      if (storeId != null) {
        sessions = _sessions.map((s) {
          if (s.id != sessionId) return s;
          return s.copyWith(storeId: storeId);
        }).toList();
        notifyListeners();
      }
    } catch (_) {}
  }
}
