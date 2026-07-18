class InjuryRiskAssessment {
  const InjuryRiskAssessment({required this.riskLevel, required this.riskFactors, required this.recommendation});
  final String riskLevel;
  final List<String> riskFactors;
  final String recommendation;

  factory InjuryRiskAssessment.fromMap(Map<String, dynamic> map) => InjuryRiskAssessment(
        riskLevel: map['riskLevel'] as String,
        riskFactors: (map['riskFactors'] as List<dynamic>).cast<String>(),
        recommendation: map['recommendation'] as String,
      );
}
