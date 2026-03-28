import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household/core/network/dio_provider.dart';
import 'package:household/models/board_note.dart';

final boardRepositoryProvider = Provider<BoardRepository>(
  (ref) => BoardRepository(ref.read(dioProvider)),
);

class BoardRepository {
  final Dio _dio;
  BoardRepository(this._dio);

  /// GET /api/app/notes?householdId=X
  Future<List<BoardNote>> getNotes(int householdId) async {
    final res = await _dio.get(
      '/app/notes',
      queryParameters: {'householdId': householdId},
    );
    final list = res.data['notes'] as List<dynamic>;
    return list
        .map((e) => BoardNote.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /api/app/notes
  Future<BoardNote> createNote(Map<String, dynamic> body) async {
    final res = await _dio.post('/app/notes', data: body);
    return BoardNote.fromJson(res.data['note'] as Map<String, dynamic>);
  }

  /// PUT /api/app/notes/:id
  Future<BoardNote> updateNote(int id, Map<String, dynamic> body) async {
    final res = await _dio.put('/app/notes/$id', data: body);
    return BoardNote.fromJson(res.data['note'] as Map<String, dynamic>);
  }

  /// DELETE /api/app/notes/:id
  Future<void> deleteNote(int id) => _dio.delete('/app/notes/$id');
}
