import 'package:household/models/category.dart';
import 'package:household/models/app_user.dart';

class ExpenseSchedule {
  final int id;
  final int householdId;
  final int expenseCategoryId;
  final Category? category;
  final AppUser? appUser;
  final String description;
  final double? amount;
  final String? paymentMethod;
  /// Weekday numbers: 0=Sun, 1=Mon, 2=Tue, 3=Wed, 4=Thu, 5=Fri, 6=Sat
  final List<int> daysOfWeek;
  final bool isActive;
  final String? note;

  const ExpenseSchedule({
    required this.id,
    required this.householdId,
    required this.expenseCategoryId,
    this.category,
    this.appUser,
    required this.description,
    this.amount,
    this.paymentMethod,
    required this.daysOfWeek,
    required this.isActive,
    this.note,
  });

  factory ExpenseSchedule.fromJson(Map<String, dynamic> json) => ExpenseSchedule(
    id:                json['id'] as int,
    householdId:       json['householdId'] as int,
    expenseCategoryId: json['expenseCategoryId'] as int,
    category: (json['ExpenseCategory'] ?? json['expenseCategory']) != null
        ? Category.fromJson(json['ExpenseCategory'] ?? json['expenseCategory'])
        : null,
    appUser: (json['AppUser'] ?? json['appUser']) != null
        ? AppUser.fromJson(json['AppUser'] ?? json['appUser'])
        : null,
    description: json['description'] as String,
    amount: json['amount'] != null ? (json['amount'] as num).toDouble() : null,
    paymentMethod: json['paymentMethod'] as String?,
    daysOfWeek: (json['daysOfWeek'] as List).map((d) => (d as num).toInt()).toList(),
    isActive: json['isActive'] as bool? ?? true,
    note: json['note'] as String?,
  );

  static const _dayLabels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  String get daysLabel {
    if (daysOfWeek.isEmpty) return '';
    final sorted = [...daysOfWeek]..sort();
    return sorted.map((d) => _dayLabels[d % 7]).join(', ');
  }
}
