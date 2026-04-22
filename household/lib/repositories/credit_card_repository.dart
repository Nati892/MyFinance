import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household/core/network/dio_provider.dart';
import 'package:household/models/credit_card.dart';

final creditCardRepositoryProvider = Provider<CreditCardRepository>(
  (ref) => CreditCardRepository(ref.read(dioProvider)),
);

class CreditCardRepository {
  final Dio _dio;
  CreditCardRepository(this._dio);

  Future<List<CreditCard>> getCards(int householdId) async {
    final res = await _dio.get('/app/cards',
        queryParameters: {'householdId': householdId});
    return (res.data['cards'] as List)
        .map((e) => CreditCard.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<CreditCard> createCard(Map<String, dynamic> body) async {
    final res = await _dio.post('/app/cards', data: body);
    return CreditCard.fromJson(res.data['card'] as Map<String, dynamic>);
  }

  Future<CreditCard> updateCard(int id, Map<String, dynamic> body) async {
    final res = await _dio.put('/app/cards/$id', data: body);
    return CreditCard.fromJson(res.data['card'] as Map<String, dynamic>);
  }

  Future<void> deleteCard(int id) => _dio.delete('/app/cards/$id');
}
