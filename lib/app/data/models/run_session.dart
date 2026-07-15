import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;

import 'ai_summary.dart';
import 'gps_point.dart';
import 'run_segment.dart';

class RunSession {
  const RunSession({
    required this.id,
    required this.uid,
    required this.examId,
    required this.startTime,
    this.endTime,
    required this.gpsTrack,
    required this.segments,
    required this.totalDistanceKm,
    required this.totalTimeSec,
    this.aiSummary,
  });
  final String id;
  final String uid;
  final String examId;
  final DateTime startTime;
  final DateTime? endTime;
  final List<GpsPoint> gpsTrack;
  final List<RunSegment> segments;
  final double totalDistanceKm;
  final int totalTimeSec;
  final AiSummary? aiSummary;

  /// Sums only accepted (sampled) GPS points. GPS jumps are filtered by tracker.
  double computeTotalDistanceKm() {
    var metres = 0.0;
    for (var index = 1; index < gpsTrack.length; index++) {
      metres += _haversineMetres(gpsTrack[index - 1], gpsTrack[index]);
    }
    return metres / 1000;
  }

  int computeTotalTimeSec({DateTime? now}) =>
      (endTime ?? now ?? DateTime.now()).difference(startTime).inSeconds;

  /// Keeps the complete run distributed across its duration if it is very long.
  List<GpsPoint> sampledGpsTrackForStorage({int maxPoints = 500}) {
    if (gpsTrack.length <= maxPoints) return gpsTrack;
    final step = (gpsTrack.length / maxPoints).ceil();
    final sampled = <GpsPoint>[];
    for (var index = 0; index < gpsTrack.length; index += step) {
      sampled.add(gpsTrack[index]);
    }
    if (sampled.last != gpsTrack.last) sampled.add(gpsTrack.last);
    return sampled;
  }

  static double _haversineMetres(GpsPoint first, GpsPoint second) {
    const earthRadiusMetres = 6371000.0;
    final latDelta = _toRadians(second.latitude - first.latitude);
    final lonDelta = _toRadians(second.longitude - first.longitude);
    final a = math.sin(latDelta / 2) * math.sin(latDelta / 2) +
        math.cos(_toRadians(first.latitude)) *
            math.cos(_toRadians(second.latitude)) *
            math.sin(lonDelta / 2) *
            math.sin(lonDelta / 2);
    return earthRadiusMetres * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double _toRadians(double degrees) => degrees * math.pi / 180;

  factory RunSession.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return RunSession(
      id: doc.id,
      uid: data['uid'] as String,
      examId: data['examId'] as String,
      startTime: (data['startTime'] as Timestamp).toDate(),
      endTime: (data['endTime'] as Timestamp?)?.toDate(),
      gpsTrack: ((data['gpsTrack'] as List<dynamic>?) ?? [])
          .map((e) => GpsPoint.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      segments: ((data['segments'] as List<dynamic>?) ?? [])
          .map((e) => RunSegment.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      totalDistanceKm: (data['totalDistanceKm'] as num).toDouble(),
      totalTimeSec: data['totalTimeSec'] as int,
      aiSummary: data['aiSummary'] == null
          ? null
          : AiSummary.fromMap(
              Map<String, dynamic>.from(data['aiSummary'] as Map),
            ),
    );
  }

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'examId': examId,
        'startTime': Timestamp.fromDate(startTime),
        'endTime': endTime == null ? null : Timestamp.fromDate(endTime!),
        'gpsTrack':
            sampledGpsTrackForStorage().map((point) => point.toMap()).toList(),
        'segments': segments.map((segment) => segment.toMap()).toList(),
        'totalDistanceKm': computeTotalDistanceKm(),
        'totalTimeSec': computeTotalTimeSec(),
        'aiSummary': aiSummary?.toMap(),
      };
}
