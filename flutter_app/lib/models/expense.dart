import 'package:household/models/category.dart';
import 'package:household/models/app_user.dart';
import 'package:household/models/credit_card.dart';

class Expense {
  final int id;
  final double amount;
  final String dateTime;
  final String? description;
  final String? note;
  final String paymentMethod;
  final int? cardId;
  final CreditCard? card;
  final int householdId;
  final Category? category;
  final AppUser? appUser;
  final int? installmentCurrent;
  final int? installmentTotal;

  const Expense({
    required this.id,
    required this.amount,
    required this.dateTime,
    this.description,
    this.note,
    required this.paymentMethod,
    this.cardId,
    this.card,
    required this.householdId,
    this.category,
    this.appUser,
    this.installmentCurrent,
    this.installmentTotal,
  });

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
    id:            json['id'] as int,
    amount:        (json['amount'] as num).toDouble(),
    dateTime:      json['dateTime'] as String,
    description:   json['description'] as String?,
    note:          json['note'] as String?,
    paymentMethod: json['paymentMethod'] as String,
    cardId:        json['cardId'] as int?,
    card: (json['card']) != null
        ? CreditCard.fromJson(json['card'] as Map<String, dynamic>)
        : null,
    householdId:   json['householdId'] as int,
    category: (json['ExpenseCategory'] ?? json['expenseCategory']) != null
        ? Category.fromJson(json['ExpenseCategory'] ?? json['expenseCategory'])
        : null,
    appUser: (json['AppUser'] ?? json['appUser']) != null
        ? AppUser.fromJson(json['AppUser'] ?? json['appUser'])
        : null,
    installmentCurrent: json['installmentCurrent'] as int?,
    installmentTotal:   json['installmentTotal'] as int?,
  );

  Map<String, dynamic> toCreateJson({
    required int expenseCategoryId,
    required int householdId,
  }) => {
    'amount': amount,
    'dateTime': dateTime,
    if (description != null && description!.isNotEmpty) 'description': description,
    if (note != null && note!.isNotEmpty) 'note': note,
    'paymentMethod': paymentMethod,
    'cardId': cardId,
    'expenseCategoryId': expenseCategoryId,
    'householdId': householdId,
    if (installmentTotal != null && installmentTotal! > 1) 'installmentTotal': installmentTotal,
    if (installmentCurrent != null) 'installmentCurrent': installmentCurrent,
  };
}
