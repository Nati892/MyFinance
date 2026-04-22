class CreditCard {
  final int id;
  final String lastFourDigits;
  final String? nickname;
  final String? bankName;
  final String? cardType; // 'credit' | 'debit'
  final int? householdId;

  const CreditCard({
    required this.id,
    required this.lastFourDigits,
    this.nickname,
    this.bankName,
    this.cardType,
    this.householdId,
  });

  factory CreditCard.fromJson(Map<String, dynamic> json) => CreditCard(
    id:             json['id'] as int,
    lastFourDigits: json['lastFourDigits'] as String,
    nickname:       json['nickname'] as String?,
    bankName:       json['bankName'] as String?,
    cardType:       json['cardType'] as String?,
    householdId:    json['householdId'] as int?,
  );

  Map<String, dynamic> toCreateJson(int householdId) => {
    'lastFourDigits': lastFourDigits,
    'householdId': householdId,
    if (nickname != null && nickname!.isNotEmpty) 'nickname': nickname,
    if (bankName != null && bankName!.isNotEmpty) 'bankName': bankName,
    if (cardType != null) 'cardType': cardType,
  };

  String get displayLabel => nickname ?? '••••$lastFourDigits';
}
