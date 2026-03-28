import 'package:household/models/household.dart';

class AppUser {
  final int id;
  final String username;
  final String? displayName;
  final List<Household> households;

  const AppUser({
    required this.id,
    required this.username,
    this.displayName,
    this.households = const [],
  });

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id:          json['id'] as int,
    username:    json['username'] as String,
    displayName: json['displayName'] as String?,
    households:  (json['households'] as List<dynamic>? ?? [])
        .map((h) => Household.fromJson(h as Map<String, dynamic>))
        .toList(),
  );

  String get name => displayName ?? username;
}
