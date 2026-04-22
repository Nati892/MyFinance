import 'package:household/models/category.dart';
import 'package:household/models/app_user.dart';

class RecurringExpense {
  final int id;
  final double amount;
  final String? description;
  final String? note;
  final String paymentMethod;
  final int householdId;
  final int expenseCategoryId;
  final Category? category;
  final AppUser? appUser;
  final int dayOfMonth;
  final int startYear;
  final int startMonth;
  final bool isActive;

  const RecurringExpense({
    required this.id,
    required this.amount,
    this.description,
    this.note,
    required this.paymentMethod,
    required this.householdId,
    required this.expenseCategoryId,
    this.category,
    this.appUser,
    required this.dayOfMonth,
    required this.startYear,
    required this.startMonth,
    required this.isActive,
  });

  factory RecurringExpense.fromJson(Map<String, dynamic> json) => RecurringExpense(
    id:                 json['id'] as int,
    amount:             (json['amount'] as num).toDouble(),
    description:        json['description'] as String?,
    note:               json['note'] as String?,
    paymentMethod:      json['paymentMethod'] as String,
    householdId:        json['householdId'] as int,
    expenseCategoryId:  json['expenseCategoryId'] as int,
    category: (json['ExpenseCategory'] ?? json['expenseCategory']) != null
        ? Category.fromJson(json['ExpenseCategory'] ?? json['expenseCategory'])
        : null,
    appUser: (json['AppUser'] ?? json['appUser']) != null
        ? AppUser.fromJson(json['AppUser'] ?? json['appUser'])
        : null,
    dayOfMonth:  json['dayOfMonth'] as int,
    startYear:   json['startYear'] as int,
    startMonth:  json['startMonth'] as int,
    isActive:    json['isActive'] as bool? ?? true,
  );
}
