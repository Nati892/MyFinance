import 'package:household/models/household.dart';

class AppUser {
  final int id;
  final String username;
  final String? displayName;
  final List<Household> households;
  final bool isDeveloper;

  const AppUser({
    required this.id,
    required this.username,
    this.displayName,
    this.households = const [],
    this.isDeveloper = false,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id:          json['id'] as int,
    username:    json['username'] as String,
    displayName: json['displayName'] as String?,
    households:  (json['households'] as List<dynamic>? ?? [])
        .map((h) => Household.fromJson(h as Map<String, dynamic>))
        .toList(),
    // MariaDB TINYINT(1) comes as integer 0/1; handle both int and bool
    isDeveloper: json['isDeveloper'] == true || json['isDeveloper'] == 1,
  );

  String get name => displayName ?? username;
}
