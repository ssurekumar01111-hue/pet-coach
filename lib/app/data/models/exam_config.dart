import 'package:cloud_firestore/cloud_firestore.dart';

class ExamConfig {
  const ExamConfig({
    required this.id,
    required this.distanceKm,
    required this.timeLimitMin,
    required this.name,
    this.approximate = false,
  });
  final String id;
  final double distanceKm;
  final double timeLimitMin;
  final String name;
  final bool approximate;

  factory ExamConfig.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return ExamConfig(
      id: doc.id,
      distanceKm: (data['distanceKm'] as num).toDouble(),
      timeLimitMin: (data['timeLimitMin'] as num).toDouble(),
      name: data['name'] as String,
      approximate: data['approximate'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'distanceKm': distanceKm,
        'timeLimitMin': timeLimitMin,
        'name': name,
        'approximate': approximate,
      };
}
