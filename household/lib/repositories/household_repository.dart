import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household/core/network/dio_provider.dart';
import 'package:household/models/household.dart';

final householdRepositoryProvider = Provider<HouseholdRepository>(
  (ref) => HouseholdRepository(ref.read(dioProvider)),
);

class HouseholdRepository {
  final Dio _dio;
  HouseholdRepository(this._dio);

  /// PUT /app/households/:id/settings
  /// Updates household-level settings (currently only financialMonthStartDay).
  Future<Household> updateSettings({
    required int householdId,
    int? financialMonthStartDay,
  }) async {
    final body = <String, dynamic>{};
    if (financialMonthStartDay != null) {
      body['financialMonthStartDay'] = financialMonthStartDay;
    }
    final res = await _dio.put('/app/households/$householdId/settings', data: body);
    final data = res.data as Map<String, dynamic>;
    return Household.fromJson(data['household'] as Map<String, dynamic>);
  }
}
