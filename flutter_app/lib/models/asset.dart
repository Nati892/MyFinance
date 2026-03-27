class Asset {
  final int id;
  final String name;
  final double value;
  final String? description;
  final int sortOrder;
  final int householdId;

  const Asset({
    required this.id,
    required this.name,
    required this.value,
    this.description,
    required this.sortOrder,
    required this.householdId,
  });

  factory Asset.fromJson(Map<String, dynamic> json) => Asset(
    id:          json['id'] as int,
    name:        json['name'] as String,
    value:       (json['value'] as num).toDouble(),
    description: json['description'] as String?,
    sortOrder:   json['sortOrder'] as int? ?? 0,
    householdId: json['householdId'] as int,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'value': value,
    if (description != null) 'description': description,
    'sortOrder': sortOrder,
    'householdId': householdId,
  };
}
