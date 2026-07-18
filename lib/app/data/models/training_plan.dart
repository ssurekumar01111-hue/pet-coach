class TrainingPlanDay {
  const TrainingPlanDay({
    required this.day,
    required this.focus,
    required this.target,
    required this.notes,
  });
  final int day;
  final String focus;
  final String target;
  final String notes;

  factory TrainingPlanDay.fromMap(Map<String, dynamic> map) => TrainingPlanDay(
        day: map['day'] as int,
        focus: map['focus'] as String,
        target: map['target'] as String,
        notes: map['notes'] as String,
      );
}

class TrainingPlan {
  const TrainingPlan({required this.days});
  final List<TrainingPlanDay> days;

  factory TrainingPlan.fromMap(Map<String, dynamic> map) => TrainingPlan(
        days: (map['days'] as List<dynamic>)
            .map((day) => TrainingPlanDay.fromMap(Map<String, dynamic>.from(day as Map)))
            .toList(),
      );
}
