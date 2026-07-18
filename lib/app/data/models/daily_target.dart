class DailyTarget {
  const DailyTarget({
    required this.targetType,
    required this.distanceKm,
    required this.paceGuidance,
    required this.reasoning,
  });
  final String targetType;
  final double? distanceKm;
  final String paceGuidance;
  final String reasoning;

  factory DailyTarget.fromMap(Map<String, dynamic> map) => DailyTarget(
        targetType: map['targetType'] as String,
        distanceKm: (map['distanceKm'] as num?)?.toDouble(),
        paceGuidance: map['paceGuidance'] as String,
        reasoning: map['reasoning'] as String,
      );
}
