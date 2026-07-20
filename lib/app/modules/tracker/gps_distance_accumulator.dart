import 'dart:math' as math;

import '../../data/models/gps_point.dart';
import 'gps_movement_filter.dart';

/// Builds an authoritative run distance from quality-filtered *raw* GPS
/// points.
///
/// This is intentionally independent of Firestore sampling and EMA pace
/// smoothing. Small or uncertain movements are retained in [_pendingPoints]
/// until several directionally-consistent observations make the movement
/// credible. That keeps stationary drift out without throwing away a runner's
/// progress simply because the current accuracy radius is large.
class GpsDistanceAccumulator {
  static const warmUpMaximumAccuracyMetres = 20.0;
  static const maximumSpeedMetresPerSecond = 12.0;
  /// A repeated fix at the same offset from the anchor is not movement. Each
  /// credible confirmation must advance at least this far away from it.
  static const minimumDirectionalProgressMetres = 2.0;
  static const maximumDirectionChangeDegrees = 45.0;

  GpsPoint? _anchor;
  final List<GpsPoint> _pendingPoints = [];
  var _totalDistanceMetres = 0.0;

  bool get hasAnchor => _anchor != null;
  double get totalDistanceMetres => _totalDistanceMetres;

  void reset() {
    _anchor = null;
    _pendingPoints.clear();
    _totalDistanceMetres = 0;
  }

  /// Adds one raw GPS fix and returns an immutable description of what was
  /// accepted. The caller can use [GpsDistanceUpdate.creditedPoints] for its
  /// low-frequency Firestore track while retaining [totalDistanceMetres] as
  /// the canonical distance.
  GpsDistanceUpdate add(GpsPoint point) {
    final anchor = _anchor;
    if (anchor == null) {
      if (!_isWarmUpQuality(point)) {
        return GpsDistanceUpdate.waitingForWarmUp(point);
      }
      _anchor = point;
      return GpsDistanceUpdate.anchorEstablished(point);
    }

    final previous = _pendingPoints.isEmpty ? anchor : _pendingPoints.last;
    final rawSegmentDistance =
        GpsMovementFilter.haversineMetres(previous, point);
    final seconds =
        point.timestamp.difference(previous.timestamp).inMilliseconds /
            Duration.millisecondsPerSecond;
    if (seconds <= 0) {
      return GpsDistanceUpdate.ignored(
        point: point,
        rawSegmentDistanceMetres: rawSegmentDistance,
      );
    }

    final rawSegmentSpeed = rawSegmentDistance / seconds;
    if (rawSegmentSpeed > maximumSpeedMetresPerSecond) {
      // A GPS jump must never become the next reference point. Retaining the
      // accepted anchor lets a later credible point reconnect safely.
      _pendingPoints.clear();
      return GpsDistanceUpdate.rejectedJump(
        point: point,
        rawSegmentDistanceMetres: rawSegmentDistance,
        rawSegmentSpeedMetresPerSecond: rawSegmentSpeed,
      );
    }

    if (!_isDirectionallyConsistent(point)) {
      // Start a fresh candidate path rather than converting a random GPS
      // wander into cumulative distance.
      _pendingPoints
        ..clear()
        ..add(point);
      return _bufferedUpdate(
        point: point,
        rawSegmentDistanceMetres: rawSegmentDistance,
        rawSegmentSpeedMetresPerSecond: rawSegmentSpeed,
      );
    }

    _pendingPoints.add(point);
    final netDisplacement = GpsMovementFilter.haversineMetres(anchor, point);
    final decision = GpsMovementFilter.evaluate(
      rawDistanceMetres: netDisplacement,
      currentAccuracyMetres: _worstPendingAccuracy(),
    );
    final credibleSamples = _crediblePendingSampleCount(anchor);
    if (!decision.countsAsMovement ||
        credibleSamples < decision.confirmationsRequired) {
      return _bufferedUpdate(
        point: point,
        rawSegmentDistanceMetres: rawSegmentDistance,
        rawSegmentSpeedMetresPerSecond: rawSegmentSpeed,
        requiredConfirmations: decision.confirmationsRequired,
      );
    }

    final creditedPoints = List<GpsPoint>.unmodifiable(_pendingPoints);
    // Credit only the stable anchor-to-endpoint displacement. Summing the
    // buffered point-to-point path makes a stationary GPS wander look like
    // distance even when it returns close to where it started.
    final creditedDistance = netDisplacement;
    _totalDistanceMetres += creditedDistance;
    _anchor = point;
    _pendingPoints.clear();
    return GpsDistanceUpdate.accepted(
      point: point,
      rawSegmentDistanceMetres: rawSegmentDistance,
      rawSegmentSpeedMetresPerSecond: rawSegmentSpeed,
      creditedDistanceMetres: creditedDistance,
      creditedPoints: creditedPoints,
      totalDistanceMetres: _totalDistanceMetres,
      requiredConfirmations: decision.confirmationsRequired,
    );
  }

  bool _isWarmUpQuality(GpsPoint point) {
    final accuracy = point.accuracy;
    return accuracy != null &&
        accuracy.isFinite &&
        accuracy >= 0 &&
        accuracy <= warmUpMaximumAccuracyMetres;
  }

  bool _isDirectionallyConsistent(GpsPoint candidate) {
    final anchor = _anchor!;
    final currentProgress =
        GpsMovementFilter.haversineMetres(anchor, candidate);
    final crediblePoints = _crediblePendingPoints(anchor);
    if (crediblePoints.isEmpty ||
        currentProgress < GpsMovementFilter.minimumDisplacementMetres) {
      // A sub-threshold point is retained as context, but it cannot itself
      // count as one of the outward confirmations.
      return true;
    }

    final previous = crediblePoints.last;
    final previousProgress =
        GpsMovementFilter.haversineMetres(anchor, previous);
    if (currentProgress < previousProgress + minimumDirectionalProgressMetres) {
      return false;
    }

    // Every credible point must trend away from the same stable anchor in a
    // similar direction. Random stationary jitter may create individual 3m+
    // offsets, but it will not produce this outward directional sequence.
    return _bearingDifferenceDegrees(
          _bearingDegrees(anchor, crediblePoints.first),
          _bearingDegrees(anchor, candidate),
        ) <=
        maximumDirectionChangeDegrees;
  }

  int _crediblePendingSampleCount(GpsPoint anchor) =>
      _crediblePendingPoints(anchor).length;

  List<GpsPoint> _crediblePendingPoints(GpsPoint anchor) => _pendingPoints
      .where(
        (point) =>
            GpsMovementFilter.haversineMetres(anchor, point) >=
            GpsMovementFilter.minimumDisplacementMetres,
      )
      .toList(growable: false);

  double _worstPendingAccuracy() {
    var worst = 0.0;
    for (final point in _pendingPoints) {
      final accuracy = point.accuracy;
      if (accuracy != null && accuracy.isFinite && accuracy > worst) {
        worst = accuracy;
      }
    }
    return worst;
  }

  GpsDistanceUpdate _bufferedUpdate({
    required GpsPoint point,
    required double rawSegmentDistanceMetres,
    required double rawSegmentSpeedMetresPerSecond,
    int? requiredConfirmations,
  }) =>
      GpsDistanceUpdate.buffered(
        point: point,
        rawSegmentDistanceMetres: rawSegmentDistanceMetres,
        rawSegmentSpeedMetresPerSecond: rawSegmentSpeedMetresPerSecond,
        pendingCount: _pendingPoints.length,
        requiredConfirmations: requiredConfirmations ??
            GpsMovementFilter.evaluate(
              rawDistanceMetres: 0,
              currentAccuracyMetres: _worstPendingAccuracy(),
            ).confirmationsRequired,
      );

  static double _bearingDegrees(GpsPoint first, GpsPoint second) {
    final longitudeDelta = _radians(second.longitude - first.longitude);
    final latitude1 = _radians(first.latitude);
    final latitude2 = _radians(second.latitude);
    final y = math.sin(longitudeDelta) * math.cos(latitude2);
    final x = math.cos(latitude1) * math.sin(latitude2) -
        math.sin(latitude1) * math.cos(latitude2) * math.cos(longitudeDelta);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  static double _bearingDifferenceDegrees(double first, double second) {
    final difference = (first - second).abs() % 360;
    return difference > 180 ? 360 - difference : difference;
  }

  static double _radians(double degrees) => degrees * math.pi / 180;
}

enum GpsDistanceUpdateKind {
  waitingForWarmUp,
  anchorEstablished,
  buffered,
  accepted,
  rejectedJump,
  ignored,
}

class GpsDistanceUpdate {
  const GpsDistanceUpdate._({
    required this.kind,
    required this.point,
    this.rawSegmentDistanceMetres = 0,
    this.rawSegmentSpeedMetresPerSecond,
    this.creditedDistanceMetres = 0,
    this.creditedPoints = const [],
    this.totalDistanceMetres = 0,
    this.pendingCount = 0,
    this.requiredConfirmations = 0,
  });

  factory GpsDistanceUpdate.waitingForWarmUp(GpsPoint point) =>
      GpsDistanceUpdate._(
        kind: GpsDistanceUpdateKind.waitingForWarmUp,
        point: point,
      );

  factory GpsDistanceUpdate.anchorEstablished(GpsPoint point) =>
      GpsDistanceUpdate._(
        kind: GpsDistanceUpdateKind.anchorEstablished,
        point: point,
      );

  factory GpsDistanceUpdate.buffered({
    required GpsPoint point,
    required double rawSegmentDistanceMetres,
    required double rawSegmentSpeedMetresPerSecond,
    required int pendingCount,
    required int requiredConfirmations,
  }) =>
      GpsDistanceUpdate._(
        kind: GpsDistanceUpdateKind.buffered,
        point: point,
        rawSegmentDistanceMetres: rawSegmentDistanceMetres,
        rawSegmentSpeedMetresPerSecond: rawSegmentSpeedMetresPerSecond,
        pendingCount: pendingCount,
        requiredConfirmations: requiredConfirmations,
      );

  factory GpsDistanceUpdate.accepted({
    required GpsPoint point,
    required double rawSegmentDistanceMetres,
    required double rawSegmentSpeedMetresPerSecond,
    required double creditedDistanceMetres,
    required List<GpsPoint> creditedPoints,
    required double totalDistanceMetres,
    required int requiredConfirmations,
  }) =>
      GpsDistanceUpdate._(
        kind: GpsDistanceUpdateKind.accepted,
        point: point,
        rawSegmentDistanceMetres: rawSegmentDistanceMetres,
        rawSegmentSpeedMetresPerSecond: rawSegmentSpeedMetresPerSecond,
        creditedDistanceMetres: creditedDistanceMetres,
        creditedPoints: creditedPoints,
        totalDistanceMetres: totalDistanceMetres,
        requiredConfirmations: requiredConfirmations,
      );

  factory GpsDistanceUpdate.rejectedJump({
    required GpsPoint point,
    required double rawSegmentDistanceMetres,
    required double rawSegmentSpeedMetresPerSecond,
  }) =>
      GpsDistanceUpdate._(
        kind: GpsDistanceUpdateKind.rejectedJump,
        point: point,
        rawSegmentDistanceMetres: rawSegmentDistanceMetres,
        rawSegmentSpeedMetresPerSecond: rawSegmentSpeedMetresPerSecond,
      );

  factory GpsDistanceUpdate.ignored({
    required GpsPoint point,
    required double rawSegmentDistanceMetres,
  }) =>
      GpsDistanceUpdate._(
        kind: GpsDistanceUpdateKind.ignored,
        point: point,
        rawSegmentDistanceMetres: rawSegmentDistanceMetres,
      );

  final GpsDistanceUpdateKind kind;
  final GpsPoint point;
  final double rawSegmentDistanceMetres;
  final double? rawSegmentSpeedMetresPerSecond;
  final double creditedDistanceMetres;
  final List<GpsPoint> creditedPoints;
  final double totalDistanceMetres;
  final int pendingCount;
  final int requiredConfirmations;

  bool get isAnchorEstablished =>
      kind == GpsDistanceUpdateKind.anchorEstablished;
  bool get isAccepted => kind == GpsDistanceUpdateKind.accepted;
  bool get isRejectedJump => kind == GpsDistanceUpdateKind.rejectedJump;

  /// Suitable for movement fusion only when both the segment and the current
  /// fix are good enough to make a speed estimate meaningful.
  bool get hasGoodQualityMotionEvidence {
    final accuracy = point.accuracy;
    final speed = rawSegmentSpeedMetresPerSecond;
    return speed != null &&
        accuracy != null &&
        accuracy.isFinite &&
        accuracy <= GpsDistanceAccumulator.warmUpMaximumAccuracyMetres &&
        rawSegmentDistanceMetres >=
            GpsMovementFilter.minimumDisplacementMetres &&
        !isRejectedJump;
  }
}
