import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;

import 'ai_summary.dart';
import 'gps_point.dart';
import 'run_segment.dart';
import 'recovery_summary.dart';

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
    this.qualifiedDeterministic,
    this.recoverySummary,
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
  final bool? qualifiedDeterministic;
  final RecoverySummary? recoverySummary;

  /// Sums only accepted (sampled) GPS points. GPS jumps are filtered by tracker.
  double computeTotalDistanceKm() {
    var metres = 0.0;
    for (var index = 1; index < gpsTrack.length; index++) {
      metres += _haversineMetres(gpsTrack[index - 1], gpsTrack[index]);
    }
    return metres / 1000;
  }

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
      qualifiedDeterministic: data['qualifiedDeterministic'] as bool?,
      recoverySummary: data['recoverySummary'] == null
          ? null
          : RecoverySummary.fromMap(
              Map<String, dynamic>.from(data['recoverySummary'] as Map),
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
        // TrackerController maintains this from every accepted raw GPS
        // segment. Recomputing from the intentionally sparse Firestore track
        // would undercount turns and any points omitted for document size.
        'totalDistanceKm': totalDistanceKm,
        // This is the stopwatch-tracked active duration. Deriving it from
        // wall-clock timestamps would incorrectly include paused time.
        'totalTimeSec': totalTimeSec,
        // These fields are Cloud Function-owned and deliberately omitted from
        // every client write. They are read back through [fromFirestore].
      };

  /// Hive-friendly representation for offline storage. Dates are ISO strings
  /// so no Firestore types or generated Hive adapters are needed on device.
  Map<String, dynamic> toLocalMap() => {
        'id': id,
        'uid': uid,
        'examId': examId,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime?.toIso8601String(),
        'gpsTrack': sampledGpsTrackForStorage()
            .map((point) => {
                  'latitude': point.latitude,
                  'longitude': point.longitude,
                  'timestamp': point.timestamp.toIso8601String(),
                  'accuracy': point.accuracy,
                })
            .toList(),
        'segments': segments
            .map((segment) => {
                  'type': segment.type,
                  'startTime': segment.startTime.toIso8601String(),
                  'endTime': segment.endTime.toIso8601String(),
                  'distanceKm': segment.distanceKm,
                  'avgPaceSecPerKm': segment.avgPaceSecPerKm,
                  'activeDurationSec': segment.activeDurationSec,
                })
            .toList(),
        'totalDistanceKm': totalDistanceKm,
        'totalTimeSec': totalTimeSec,
        'qualifiedDeterministic': qualifiedDeterministic,
      };

  factory RunSession.fromLocalMap(Map<String, dynamic> map) => RunSession(
        id: map['id'] as String,
        uid: map['uid'] as String,
        examId: map['examId'] as String,
        startTime: DateTime.parse(map['startTime'] as String),
        endTime: map['endTime'] is String
            ? DateTime.parse(map['endTime'] as String)
            : null,
        gpsTrack:
            ((map['gpsTrack'] as List<dynamic>?) ?? const []).map((value) {
          final point = Map<String, dynamic>.from(value as Map);
          return GpsPoint(
            latitude: (point['latitude'] as num).toDouble(),
            longitude: (point['longitude'] as num).toDouble(),
            timestamp: DateTime.parse(point['timestamp'] as String),
            accuracy: (point['accuracy'] as num?)?.toDouble(),
          );
        }).toList(),
        segments:
            ((map['segments'] as List<dynamic>?) ?? const []).map((value) {
          final segment = Map<String, dynamic>.from(value as Map);
          return RunSegment(
            type: segment['type'] as String,
            startTime: DateTime.parse(segment['startTime'] as String),
            endTime: DateTime.parse(segment['endTime'] as String),
            distanceKm: (segment['distanceKm'] as num).toDouble(),
            avgPaceSecPerKm: (segment['avgPaceSecPerKm'] as num).toDouble(),
            activeDurationSec:
                (segment['activeDurationSec'] as num?)?.toDouble(),
          );
        }).toList(),
        totalDistanceKm: (map['totalDistanceKm'] as num).toDouble(),
        totalTimeSec: (map['totalTimeSec'] as num).toInt(),
        qualifiedDeterministic: map['qualifiedDeterministic'] as bool?,
      );
}
