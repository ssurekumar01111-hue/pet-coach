class RecoverySummary {
  const RecoverySummary({required this.score, required this.recommendation});

  final int score;
  final String recommendation;

  factory RecoverySummary.fromMap(Map<String, dynamic> map) => RecoverySummary(
        score: (map['score'] as num).round().clamp(0, 100).toInt(),
        recommendation: map['recommendation'] as String,
      );

  Map<String, dynamic> toMap() => {
        'score': score,
        'recommendation': recommendation,
      };
}
