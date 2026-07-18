class QualificationReadiness {
  const QualificationReadiness({
    required this.readinessPercent,
    required this.trend,
    required this.predictedQualificationDate,
    required this.summary,
  });

  final int readinessPercent;
  final String trend;
  final String predictedQualificationDate;
  final String summary;

  factory QualificationReadiness.fromMap(Map<String, dynamic> map) =>
      QualificationReadiness(
        readinessPercent: (map['readinessPercent'] as num).round().clamp(0, 100).toInt(),
        trend: map['trend'] as String,
        predictedQualificationDate: map['predictedQualificationDate'] as String,
        summary: map['summary'] as String,
      );
}
