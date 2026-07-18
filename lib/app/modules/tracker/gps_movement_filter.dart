import 'dart:math' as math;

import '../../data/models/gps_point.dart';

/// Decides whether a raw GPS displacement is credible enough to represent
/// movement. This deliberately runs before pace, distance, or walk/run logic.
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
    // A point inside its own horizontal accuracy radius is indistinguishable
    // from stationary GPS drift. The 3 m floor catches very small jitter too.
    final requiredDisplacement = math.max(minimumDisplacementMetres, accuracy);
    return GpsMovementDecision(
      rawDistanceMetres: rawDistanceMetres,
      accuracyMetres: accuracy,
      requiredDisplacementMetres: requiredDisplacement,
      countsAsMovement: rawDistanceMetres >= requiredDisplacement,
    );
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
  });

  final double rawDistanceMetres;
  final double accuracyMetres;
  final double requiredDisplacementMetres;
  final bool countsAsMovement;
}
