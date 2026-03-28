class Asset {
  final int id;
  final String name;
  final double value;
  final String? description;
  final String liquidity; // 'high' | 'medium' | 'low'
  final String? date; // YYYY-MM-DD
  final int sortOrder;
  final int householdId;

  // Exit fields
  final String exitType; // 'none' | 'single' | 'series'
  final DateTime? exitDate;
  final DateTime? exitSeriesStart;
  final int? exitSeriesInterval;
  final String? exitSeriesUnit; // 'days'|'weeks'|'months'|'years'

  // Repetitive income fields
  final bool isRepetitive;
  final double? repetitiveAmount;
  final int? repetitiveInterval;
  final String? repetitiveUnit; // 'days'|'weeks'|'months'|'years'

  const Asset({
    required this.id,
    required this.name,
    required this.value,
    this.description,
    required this.liquidity,
    this.date,
    required this.sortOrder,
    required this.householdId,
    this.exitType = 'none',
    this.exitDate,
    this.exitSeriesStart,
    this.exitSeriesInterval,
    this.exitSeriesUnit,
    this.isRepetitive = false,
    this.repetitiveAmount,
    this.repetitiveInterval,
    this.repetitiveUnit,
  });

  factory Asset.fromJson(Map<String, dynamic> json) => Asset(
        id: json['id'] as int,
        name: json['name'] as String,
        value: (json['value'] as num).toDouble(),
        description: json['description'] as String?,
        liquidity: json['liquidity'] as String? ?? 'medium',
        date: json['date'] as String?,
        sortOrder: json['sortOrder'] as int? ?? 0,
        householdId: json['householdId'] as int,
        exitType: json['exit_type'] as String? ?? 'none',
        exitDate: json['exit_date'] != null
            ? DateTime.tryParse(json['exit_date'] as String)
            : null,
        exitSeriesStart: json['exit_series_start'] != null
            ? DateTime.tryParse(json['exit_series_start'] as String)
            : null,
        exitSeriesInterval: json['exit_series_interval'] as int?,
        exitSeriesUnit: json['exit_series_unit'] as String?,
        isRepetitive: json['is_repetitive'] as bool? ?? false,
        repetitiveAmount: json['repetitive_amount'] != null
            ? (json['repetitive_amount'] as num).toDouble()
            : null,
        repetitiveInterval: json['repetitive_interval'] as int?,
        repetitiveUnit: json['repetitive_unit'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'value': value,
        if (description != null) 'description': description,
        'liquidity': liquidity,
        if (date != null) 'date': date,
        'sortOrder': sortOrder,
        'householdId': householdId,
        'exit_type': exitType,
        if (exitDate != null)
          'exit_date':
              '${exitDate!.year}-${exitDate!.month.toString().padLeft(2, '0')}-${exitDate!.day.toString().padLeft(2, '0')}',
        if (exitSeriesStart != null)
          'exit_series_start':
              '${exitSeriesStart!.year}-${exitSeriesStart!.month.toString().padLeft(2, '0')}-${exitSeriesStart!.day.toString().padLeft(2, '0')}',
        if (exitSeriesInterval != null)
          'exit_series_interval': exitSeriesInterval,
        if (exitSeriesUnit != null) 'exit_series_unit': exitSeriesUnit,
        'is_repetitive': isRepetitive,
        if (repetitiveAmount != null) 'repetitive_amount': repetitiveAmount,
        if (repetitiveInterval != null)
          'repetitive_interval': repetitiveInterval,
        if (repetitiveUnit != null) 'repetitive_unit': repetitiveUnit,
      };

  Asset copyWith({
    int? id,
    String? name,
    double? value,
    String? description,
    String? liquidity,
    String? date,
    int? sortOrder,
    int? householdId,
    String? exitType,
    DateTime? exitDate,
    DateTime? exitSeriesStart,
    int? exitSeriesInterval,
    String? exitSeriesUnit,
    bool? isRepetitive,
    double? repetitiveAmount,
    int? repetitiveInterval,
    String? repetitiveUnit,
  }) =>
      Asset(
        id: id ?? this.id,
        name: name ?? this.name,
        value: value ?? this.value,
        description: description ?? this.description,
        liquidity: liquidity ?? this.liquidity,
        date: date ?? this.date,
        sortOrder: sortOrder ?? this.sortOrder,
        householdId: householdId ?? this.householdId,
        exitType: exitType ?? this.exitType,
        exitDate: exitDate ?? this.exitDate,
        exitSeriesStart: exitSeriesStart ?? this.exitSeriesStart,
        exitSeriesInterval: exitSeriesInterval ?? this.exitSeriesInterval,
        exitSeriesUnit: exitSeriesUnit ?? this.exitSeriesUnit,
        isRepetitive: isRepetitive ?? this.isRepetitive,
        repetitiveAmount: repetitiveAmount ?? this.repetitiveAmount,
        repetitiveInterval: repetitiveInterval ?? this.repetitiveInterval,
        repetitiveUnit: repetitiveUnit ?? this.repetitiveUnit,
      );
}
