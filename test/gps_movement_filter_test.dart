import 'package:flutter_test/flutter_test.dart';
import 'package:pet_coach_ai/app/data/models/gps_point.dart';
import 'package:pet_coach_ai/app/modules/tracker/gps_movement_filter.dart';
import 'package:pet_coach_ai/app/modules/tracker/walk_run_detector.dart';

void main() {
  test('stationary GPS jitter stays at zero distance and walking state', () {
    final start = DateTime(2026, 7, 18, 6, 30);
    // Positions remain inside a typical 10 m accuracy radius around one chair.
    final offsetsMetres = <(double north, double east)>[
      (0, 0),
      (2, -1),
      (-3, 2),
      (1, 3),
      (-2, -2),
      (3, 1),
      (0, -3),
    ];
    final points = offsetsMetres.indexed.map((entry) {
      final index = entry.$1;
      final offset = entry.$2;
      // Approximate local metre-to-degree conversion, sufficient for this test.
      return GpsPoint(
        latitude: 28.6139 + offset.$1 / 111111,
        longitude: 77.2090 + offset.$2 / 97800,
        timestamp: start.add(Duration(seconds: index * 5)),
        accuracy: 10,
      );
    }).toList();

    final detector = WalkRunDetector();
    var acceptedDistanceMetres = 0.0;
    var acceptedSamples = 0;
    for (var index = 1; index < points.length; index++) {
      final rawDistance =
          GpsMovementFilter.haversineMetres(points[index - 1], points[index]);
      final decision = GpsMovementFilter.evaluate(
        rawDistanceMetres: rawDistance,
        currentAccuracyMetres: points[index].accuracy,
      );
      if (!decision.countsAsMovement) continue;

      acceptedDistanceMetres += rawDistance;
      acceptedSamples++;
      detector.addSpeedSample(rawDistance / 5, points[index].timestamp);
    }

    expect(acceptedSamples, 0);
    expect(acceptedDistanceMetres, closeTo(0, .001));
    expect(detector.currentState, 'walking');
  });

  test('requires at least the accuracy radius and 3 metre floor', () {
    expect(
      GpsMovementFilter.evaluate(
        rawDistanceMetres: 4.9,
        currentAccuracyMetres: 5,
      ).countsAsMovement,
      isFalse,
    );
    expect(
      GpsMovementFilter.evaluate(
        rawDistanceMetres: 3.0,
        currentAccuracyMetres: 1,
      ).countsAsMovement,
      isTrue,
    );
  });
}
