import 'dart:math' as math;

import '../../data/models/gps_point.dart';

/// Shared geographic helpers and lightweight confidence guidance for GPS
/// movement processing.
///
/// A reported horizontal accuracy is a confidence radius, not a displacement
/// threshold. In particular, a 20 m accuracy reading does not mean that a
/// legitimate 10 m movement should be discarded. The stateful
/// [GpsDistanceAccumulator] turns this guidance into buffered acceptance.
class GpsMovementFilter {
  const GpsMovementFilter._();

  /// Suppresses sub-metre/micro-jitter even when the GPS reports high accuracy.
  static const minimumDisplacementMetres = 3.0;

  static GpsMovementDecision evaluate({
    required double rawDistanceMetres,
    required double? currentAccuracyMetres,
  }) {
    final accuracy = currentAccuracyMetres != null &&
            currentAccuracyMetres.isFinite &&
            currentAccuracyMetres > 0
        ? currentAccuracyMetres
        : 0.0;
    // Keep a fixed micro-jitter floor. Accuracy changes the number of
    // confirmations required by the accumulator; it is deliberately not a
    // hard displacement threshold.
    const requiredDisplacement = minimumDisplacementMetres;
    return GpsMovementDecision(
      rawDistanceMetres: rawDistanceMetres,
      accuracyMetres: accuracy,
      requiredDisplacementMetres: requiredDisplacement,
      countsAsMovement: rawDistanceMetres >= requiredDisplacement,
      confirmationsRequired: _confirmationsForAccuracy(accuracy),
    );
  }

  static int _confirmationsForAccuracy(double accuracy) {
    // Two outward, directionally aligned readings are enough to recover a
    // genuine 10-13m move even when the platform briefly reports 20-35m
    // accuracy. Very weak fixes still need an extra confirmation.
    if (accuracy <= 35) return 2;
    return 3;
  }

  static double haversineMetres(GpsPoint first, GpsPoint second) {
    const earthRadiusMetres = 6371000.0;
    final latitudeDelta = _radians(second.latitude - first.latitude);
    final longitudeDelta = _radians(second.longitude - first.longitude);
    final a = math.sin(latitudeDelta / 2) * math.sin(latitudeDelta / 2) +
        math.cos(_radians(first.latitude)) *
            math.cos(_radians(second.latitude)) *
            math.sin(longitudeDelta / 2) *
            math.sin(longitudeDelta / 2);
    return earthRadiusMetres * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double _radians(double degrees) => degrees * math.pi / 180;
}

class GpsMovementDecision {
  const GpsMovementDecision({
    required this.rawDistanceMetres,
    required this.accuracyMetres,
    required this.requiredDisplacementMetres,
    required this.countsAsMovement,
    required this.confirmationsRequired,
  });

  final double rawDistanceMetres;
  final double accuracyMetres;
  final double requiredDisplacementMetres;
  final bool countsAsMovement;
  final int confirmationsRequired;
}
