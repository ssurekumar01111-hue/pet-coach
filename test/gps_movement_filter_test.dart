import 'package:flutter_test/flutter_test.dart';
import 'package:pet_coach_ai/app/data/models/gps_point.dart';
import 'package:pet_coach_ai/app/modules/tracker/gps_distance_accumulator.dart';
import 'package:pet_coach_ai/app/modules/tracker/gps_movement_filter.dart';

void main() {
  test('stationary GPS jitter stays at zero canonical distance', () {
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

    final accumulator = GpsDistanceAccumulator();
    for (final point in points) {
      accumulator.add(point);
    }

    expect(accumulator.totalDistanceMetres, closeTo(0, .001));
  });

  test('uses accuracy as buffered confidence, not a hard displacement gate',
      () {
    expect(
      GpsMovementFilter.evaluate(
        rawDistanceMetres: 4.9,
        currentAccuracyMetres: 5,
      ).countsAsMovement,
      isTrue,
    );
    expect(
      GpsMovementFilter.evaluate(
        rawDistanceMetres: 10,
        currentAccuracyMetres: 25,
      ).confirmationsRequired,
      2,
    );
  });
}
