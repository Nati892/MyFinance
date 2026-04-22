class Household {
  final int householdId;
  final String name;
  final String role; // 'admin' | 'member'

  const Household({
    required this.householdId,
    required this.name,
    required this.role,
  });

  factory Household.fromJson(Map<String, dynamic> json) => Household(
    householdId: json['householdId'] as int,
    // signin response uses 'householdName', other endpoints use 'name'
    name:        (json['householdName'] ?? json['name']) as String,
    role:        json['role'] as String? ?? 'member',
  );
}
