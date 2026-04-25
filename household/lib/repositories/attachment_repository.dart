import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household/core/network/dio_provider.dart';
import 'package:household/models/transaction_attachment.dart';

final attachmentRepositoryProvider = Provider<AttachmentRepository>(
  (ref) => AttachmentRepository(ref.read(dioProvider)),
);

class AttachmentRepository {
  final Dio _dio;
  AttachmentRepository(this._dio);

  Future<TransactionAttachment> uploadAttachment({
    required File file,
    int? expenseId,
    int? incomeId,
    required String displayName,
    required int householdId,
  }) async {
    // Keep the original extension in the upload filename so Dio can detect
    // the correct MIME type (displayName has the extension stripped by the UI).
    final pathExt = file.path.contains('.')
        ? '.${file.path.split('.').last.toLowerCase()}'
        : '';
    final uploadFilename = '$displayName$pathExt';
    debugPrint('[AttachmentRepo] uploading file=${file.path}'
        ' filename=$uploadFilename'
        ' expenseId=$expenseId incomeId=$incomeId householdId=$householdId');
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(file.path, filename: uploadFilename),
      'filename': displayName,
      if (expenseId != null) 'expenseId': expenseId,
      if (incomeId != null)  'incomeId': incomeId,
      'householdId': householdId,
    });
    final res = await _dio.post('/app/attachments', data: formData);
    debugPrint('[AttachmentRepo] upload response status=${res.statusCode} data=${res.data}');
    final json = res.data as Map<String, dynamic>;
    final row = (json['attachment'] ?? json) as Map<String, dynamic>;
    return TransactionAttachment.fromJson(row);
  }

  Future<void> renameAttachment(int id, String filename) =>
      _dio.put('/app/attachments/$id', data: {'filename': filename});

  Future<void> deleteAttachment(int id) =>
      _dio.delete('/app/attachments/$id');
}
