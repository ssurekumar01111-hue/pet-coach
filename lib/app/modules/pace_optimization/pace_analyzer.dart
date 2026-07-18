import 'dart:math' as math;

import '../../data/models/gps_point.dart';
import '../../data/models/run_session.dart';

class PaceSplit {
  const PaceSplit({
    required this.kilometer,
    required this.paceSecPerKm,
    required this.recommendation,
  });
  final int kilometer;
  final double paceSecPerKm;
  final String recommendation;
}

class PaceAnalysis {
  const PaceAnalysis({
    required this.splits,
    required this.targetPaceSecPerKm,
    required this.historicalPaceSecPerKm,
    required this.consistencyNote,
  });
  final List<PaceSplit> splits;
  final double targetPaceSecPerKm;
  final double? historicalPaceSecPerKm;
  final String consistencyNote;
}

/// Deterministic split analysis. It interpolates the timestamp at each 1 km
/// crossing between sampled GPS points; no model or network call is involved.
class PaceAnalyzer {
  static PaceAnalysis analyze({
    required RunSession session,
    required double targetPaceSecPerKm,
    required double? historicalPaceSecPerKm,
  }) {
    final points = session.gpsTrack;
    if (points.length < 2) {
      return PaceAnalysis(
        splits: const [],
        targetPaceSecPerKm: targetPaceSecPerKm,
        historicalPaceSecPerKm: historicalPaceSecPerKm,
        consistencyNote: 'Not enough GPS data to calculate kilometer splits.',
      );
    }
    final splits = <PaceSplit>[];
    var cumulativeMetres = 0.0;
    var nextMarkerMetres = 1000.0;
    var splitStart = points.first.timestamp;
    for (var index = 1; index < points.length; index++) {
      final previous = points[index - 1];
      final current = points[index];
      final legMetres = _haversineMetres(previous, current);
      if (legMetres <= 0) continue;
      final legStartMetres = cumulativeMetres;
      final legEndMetres = cumulativeMetres + legMetres;
      while (legEndMetres >= nextMarkerMetres) {
        final fraction = (nextMarkerMetres - legStartMetres) / legMetres;
        final crossing = previous.timestamp.add(Duration(
          milliseconds: (current.timestamp.difference(previous.timestamp).inMilliseconds * fraction).round(),
        ));
        final pace = crossing.difference(splitStart).inMilliseconds / 1000;
        splits.add(PaceSplit(
          kilometer: splits.length + 1,
          paceSecPerKm: pace,
          recommendation: _recommendation(pace, targetPaceSecPerKm, historicalPaceSecPerKm),
        ));
        splitStart = crossing;
        nextMarkerMetres += 1000;
      }
      cumulativeMetres = legEndMetres;
    }
    return PaceAnalysis(
      splits: splits,
      targetPaceSecPerKm: targetPaceSecPerKm,
      historicalPaceSecPerKm: historicalPaceSecPerKm,
      consistencyNote: _consistencyNote(splits),
    );
  }

  static String _recommendation(double pace, double target, double? historical) {
    final isFasterThanTarget = pace < target * .95;
    final isOnTarget = pace <= target * 1.05;
    final isAtLeastHistorical = historical == null || pace <= historical * 1.05;
    if (isFasterThanTarget && isAtLeastHistorical) return 'faster than needed';
    if (isOnTarget && isAtLeastHistorical) return 'on target';
    return 'needs improvement';
  }

  static String _consistencyNote(List<PaceSplit> splits) {
    if (splits.length < 2) return 'Complete more full kilometers to assess pacing consistency.';
    final midpoint = (splits.length / 2).ceil();
    final first = _average(splits.take(midpoint).map((split) => split.paceSecPerKm))!;
    final second = _average(splits.skip(midpoint).map((split) => split.paceSecPerKm));
    if (second == null) return 'Keep building complete kilometer splits for a consistency check.';
    if (first < second * .92) return 'You started too fast and slowed down. Aim for a steadier opening pace.';
    if (first > second * 1.08) return 'You finished stronger than you started. Try a slightly faster, controlled opening.';
    return 'Your pace stayed consistent across the run. Keep repeating this control.';
  }

  static double? _average(Iterable<double> values) {
    final list = values.toList();
    if (list.isEmpty) return null;
    return list.reduce((a, b) => a + b) / list.length;
  }

  static double _haversineMetres(GpsPoint first, GpsPoint second) {
    const radius = 6371000.0;
    final latDelta = _radians(second.latitude - first.latitude);
    final lonDelta = _radians(second.longitude - first.longitude);
    final a = math.sin(latDelta / 2) * math.sin(latDelta / 2) +
        math.cos(_radians(first.latitude)) * math.cos(_radians(second.latitude)) *
            math.sin(lonDelta / 2) * math.sin(lonDelta / 2);
    return radius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double _radians(double degrees) => degrees * math.pi / 180;
}
