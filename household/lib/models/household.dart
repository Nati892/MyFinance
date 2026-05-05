class Household {
  final int householdId;
  final String name;
  final String role; // 'admin' | 'member'
  final int financialMonthStartDay;

  const Household({
    required this.householdId,
    required this.name,
    required this.role,
    this.financialMonthStartDay = 10,
  });

  factory Household.fromJson(Map<String, dynamic> json) => Household(
    householdId: json['householdId'] as int,
    // signin response uses 'householdName', other endpoints use 'name'
    name:        (json['householdName'] ?? json['name']) as String,
    role:        json['role'] as String? ?? 'member',
    financialMonthStartDay:
        (json['financialMonthStartDay'] as int?) ?? 10,
  );

  Household copyWith({
    int? householdId,
    String? name,
    String? role,
    int? financialMonthStartDay,
  }) =>
      Household(
        householdId: householdId ?? this.householdId,
        name: name ?? this.name,
        role: role ?? this.role,
        financialMonthStartDay:
            financialMonthStartDay ?? this.financialMonthStartDay,
      );
}
