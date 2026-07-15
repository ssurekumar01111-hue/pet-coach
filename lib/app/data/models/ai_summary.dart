class AiSummary {
  const AiSummary({
    required this.qualifies,
    required this.predictedTime,
    required this.feedback,
    required this.nextTarget,
  });
  final bool qualifies;
  final String predictedTime;
  final String feedback;
  final String nextTarget;

  factory AiSummary.fromMap(Map<String, dynamic> map) => AiSummary(
        qualifies: map['qualifies'] as bool,
        predictedTime: map['predictedTime'] as String,
        feedback: map['feedback'] as String,
        nextTarget: map['nextTarget'] as String,
      );
  Map<String, dynamic> toMap() => {
        'qualifies': qualifies,
        'predictedTime': predictedTime,
        'feedback': feedback,
        'nextTarget': nextTarget,
      };
}
