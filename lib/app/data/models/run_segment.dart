import 'package:cloud_firestore/cloud_firestore.dart';

class RunSegment {
  const RunSegment({
    required this.type,
    required this.startTime,
    required this.endTime,
    required this.distanceKm,
    required this.avgPaceSecPerKm,
    this.activeDurationSec,
  });
  final String type;
  final DateTime startTime;
  final DateTime endTime;
  final double distanceKm;
  final double avgPaceSecPerKm;

  /// Active time after subtracting pauses that occurred within this segment.
  /// Older Firestore documents do not have this field and use timestamps.
  final double? activeDurationSec;

  factory RunSegment.fromMap(Map<String, dynamic> map) => RunSegment(
        type: map['type'] as String,
        startTime: (map['startTime'] as Timestamp).toDate(),
        endTime: (map['endTime'] as Timestamp).toDate(),
        distanceKm: (map['distanceKm'] as num).toDouble(),
        avgPaceSecPerKm: (map['avgPaceSecPerKm'] as num).toDouble(),
        activeDurationSec: (map['activeDurationSec'] as num?)?.toDouble(),
      );
  Map<String, dynamic> toMap() => {
        'type': type,
        'startTime': Timestamp.fromDate(startTime),
        'endTime': Timestamp.fromDate(endTime),
        'distanceKm': distanceKm,
        'avgPaceSecPerKm': avgPaceSecPerKm,
        if (activeDurationSec != null) 'activeDurationSec': activeDurationSec,
      };
}
