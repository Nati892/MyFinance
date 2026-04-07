class ShoppingStore {
  final int id;
  final String name;
  final int householdId;

  ShoppingStore({
    required this.id,
    required this.name,
    required this.householdId,
  });

  factory ShoppingStore.fromJson(Map<String, dynamic> json) {
    return ShoppingStore(
      id: json['id'] as int,
      name: json['name'] as String,
      householdId: json['householdId'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'householdId': householdId,
      };
}
