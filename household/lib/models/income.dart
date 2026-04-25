import 'package:household/models/category.dart';
import 'package:household/models/app_user.dart';
import 'package:household/models/credit_card.dart';
import 'package:household/models/transaction_attachment.dart';

class Income {
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
  final List<TransactionAttachment> attachments;
  final int attachmentCount;

  const Income({
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
    this.attachments = const [],
    this.attachmentCount = 0,
  });

  factory Income.fromJson(Map<String, dynamic> json) {
    final attachList = json['attachments'] as List? ?? [];
    return Income(
      id:            json['id'] as int,
      amount:        (json['amount'] as num).toDouble(),
      dateTime:      json['dateTime'] as String,
      description:   json['description'] as String?,
      note:          json['note'] as String?,
      paymentMethod: json['paymentMethod'] as String,
      cardId:        json['cardId'] as int?,
      card: json['card'] != null ? CreditCard.fromJson(json['card'] as Map<String, dynamic>) : null,
      householdId:   json['householdId'] as int,
      category: (json['IncomeCategory'] ?? json['incomeCategory']) != null
          ? Category.fromJson(json['IncomeCategory'] ?? json['incomeCategory'])
          : null,
      appUser: (json['AppUser'] ?? json['appUser']) != null
          ? AppUser.fromJson(json['AppUser'] ?? json['appUser'])
          : null,
      attachments: attachList
          .map((a) => TransactionAttachment.fromJson(a as Map<String, dynamic>))
          .toList(),
      attachmentCount: json['attachmentCount'] as int? ?? attachList.length,
    );
  }
}
