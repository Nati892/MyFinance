import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household/models/board_note.dart';
import 'package:household/repositories/board_repository.dart';

final boardServiceProvider = ChangeNotifierProvider<BoardService>(
  (ref) => BoardService(ref.read(boardRepositoryProvider)),
);

/// Thin service that wraps [BoardRepository] and holds the in-memory note list.
/// Screens that only need simple CRUD can consume this directly.
/// The board screen uses [boardViewModelProvider] for richer UI state.
class BoardService extends ChangeNotifier {
  final BoardRepository _repo;
  BoardService(this._repo);

  List<BoardNote> notes = [];

  Future<void> loadNotes(int householdId) async {
    notes = await _repo.getNotes(householdId);
    notifyListeners();
  }

  Future<BoardNote> createNote(Map<String, dynamic> body) async {
    final note = await _repo.createNote(body);
    notes = [...notes, note];
    notifyListeners();
    return note;
  }

  Future<BoardNote> updateNote(int id, Map<String, dynamic> body) async {
    final updated = await _repo.updateNote(id, body);
    notes = notes.map((n) => n.id == id ? updated : n).toList();
    notifyListeners();
    return updated;
  }

  Future<void> deleteNote(int id) async {
    await _repo.deleteNote(id);
    notes = notes.where((n) => n.id != id).toList();
    notifyListeners();
  }
}
