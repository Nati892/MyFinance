import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household/models/credit_card.dart';
import 'package:household/repositories/credit_card_repository.dart';

final creditCardServiceProvider = ChangeNotifierProvider<CreditCardService>(
  (ref) => CreditCardService(ref.read(creditCardRepositoryProvider)),
);

class CreditCardService extends ChangeNotifier {
  final CreditCardRepository _repo;
  CreditCardService(this._repo);

  List<CreditCard> cards = [];

  Future<void> load(int householdId) async {
    cards = await _repo.getCards(householdId);
    notifyListeners();
  }

  Future<CreditCard> create(Map<String, dynamic> body) async {
    final card = await _repo.createCard(body);
    cards = [...cards, card];
    notifyListeners();
    return card;
  }

  Future<CreditCard> update(int id, Map<String, dynamic> body) async {
    final updated = await _repo.updateCard(id, body);
    cards = cards.map((c) => c.id == id ? updated : c).toList();
    notifyListeners();
    return updated;
  }

  Future<void> delete(int id) async {
    await _repo.deleteCard(id);
    cards = cards.where((c) => c.id != id).toList();
    notifyListeners();
  }
}
