import 'package:flutter_test/flutter_test.dart';
import 'package:pet_coach_ai/app/data/models/gps_point.dart';
import 'package:pet_coach_ai/app/modules/tracker/gps_distance_accumulator.dart';
import 'package:pet_coach_ai/app/modules/tracker/motion_fusion_detector.dart';
import 'package:pet_coach_ai/app/modules/tracker/step_cadence_detector.dart';

void main() {
  final start = DateTime(2026, 7, 20, 6);

  test('1km moving trace with accuracy spikes retains canonical distance', () {
    final accumulator = GpsDistanceAccumulator();

    // A weak initial fix must not become the distance anchor.
    expect(
      accumulator.add(_pointAt(start, metresNorth: 0, accuracy: 51)).kind,
      GpsDistanceUpdateKind.waitingForWarmUp,
    );

    const spikeAccuracies = [4.0, 8.0, 24.0, 12.0, 31.0, 7.0, 18.0];
    for (var index = 0; index <= 200; index++) {
      accumulator.add(
        _pointAt(
          start.add(Duration(seconds: index * 2)),
          metresNorth: index * 5.0,
          accuracy: spikeAccuracies[index % spikeAccuracies.length],
        ),
      );
    }

    // Buffered confidence may leave a short tail at the finish, but it must
    // retain a known 1 km route despite 24-31m accuracy spikes.
    expect(accumulator.totalDistanceMetres, greaterThan(970));
    expect(accumulator.totalDistanceMetres, lessThan(1030));
  });

  test('stationary jitter adds near-zero canonical distance', () {
    final accumulator = GpsDistanceAccumulator();
    const offsets = <(double north, double east)>[
      (0, 0),
      (2, -1),
      (-3, 2),
      (1, 3),
      (-2, -2),
      (3, 1),
      (0, -3),
    ];
    for (final entry in offsets.indexed) {
      accumulator.add(
        _pointAt(
          start.add(Duration(seconds: entry.$1 * 5)),
          metresNorth: entry.$2.$1,
          metresEast: entry.$2.$2,
          accuracy: 10,
        ),
      );
    }

    expect(accumulator.totalDistanceMetres, lessThan(1));
  });

  test('10-13m accuracy-spike moves are buffered then credited', () {
    final accumulator = GpsDistanceAccumulator();
    accumulator.add(_pointAt(start, metresNorth: 0, accuracy: 5));

    final firstMove = accumulator.add(
      _pointAt(
        start.add(const Duration(seconds: 5)),
        metresNorth: 10,
        accuracy: 25,
      ),
    );
    final recoveredMove = accumulator.add(
      _pointAt(
        start.add(const Duration(seconds: 10)),
        metresNorth: 13,
        accuracy: 25,
      ),
    );

    expect(firstMove.isAccepted, isFalse);
    expect(recoveredMove.isAccepted, isTrue);
    expect(accumulator.totalDistanceMetres, closeTo(13, .2));
  });

  test('cadence 200spm with GPS 1.89m/s does not block valid running', () {
    final fusion = MotionFusionDetector();
    fusion.setCadenceSensorAvailable(true, start);
    fusion.addGpsSpeed(
      speedMetresPerSecond: 1.89,
      isGoodQuality: true,
      timestamp: start,
    );

    fusion.addCadenceReading(
      _cadenceReading(
        cadence: 200,
        classification: 'walking',
        rawClassification: 'running',
        pending: 'running',
        confirmations: 1,
      ),
      start.add(const Duration(seconds: 1)),
    );
    final decision = fusion.addCadenceReading(
      _cadenceReading(
        cadence: 200,
        classification: 'running',
        rawClassification: 'running',
        transitioned: true,
        confirmations: 2,
      ),
      start.add(const Duration(seconds: 2)),
    );

    expect(decision.runningVetoed, isFalse);
    expect(fusion.currentState, 'running');
  });

  test('cadence 140-160spm with sustained 3m/s GPS stays running', () {
    final fusion = MotionFusionDetector();
    fusion.setCadenceSensorAvailable(true, start);
    fusion.addCadenceReading(
      _cadenceReading(
        cadence: 160,
        classification: 'running',
        rawClassification: 'running',
        transitioned: true,
        confirmations: 2,
      ),
      start,
    );

    for (final entry in [160.0, 150.0, 140.0, 155.0, 145.0, 150.0].indexed) {
      final timestamp = start.add(Duration(seconds: entry.$1 + 1));
      fusion.addGpsSpeed(
        speedMetresPerSecond: 3.2,
        isGoodQuality: true,
        timestamp: timestamp,
      );
      fusion.addCadenceReading(
        _cadenceReading(
          cadence: entry.$2,
          classification: 'running',
          rawClassification: 'running',
        ),
        timestamp,
      );
    }

    expect(fusion.currentState, 'running');
  });

  test('hand-motion cadence spike plus slow good GPS stays walking', () {
    final fusion = MotionFusionDetector();
    fusion.setCadenceSensorAvailable(true, start);
    fusion.addGpsSpeed(
      speedMetresPerSecond: .8,
      isGoodQuality: true,
      timestamp: start,
    );
    fusion.addGpsSpeed(
      speedMetresPerSecond: .8,
      isGoodQuality: true,
      timestamp: start.add(const Duration(seconds: 2)),
    );

    final decision = fusion.addCadenceReading(
      _cadenceReading(
        cadence: 180,
        classification: 'running',
        rawClassification: 'running',
        transitioned: true,
        confirmations: 2,
      ),
      start.add(const Duration(seconds: 3)),
    );

    expect(decision.runningVetoed, isTrue);
    expect(fusion.currentState, 'walking');
  });

  test('pedometer-unavailable fallback promotes then exits from GPS', () {
    final fusion = MotionFusionDetector();
    fusion.setCadenceSensorAvailable(false, start);
    fusion.addGpsSpeed(
      speedMetresPerSecond: 3,
      isGoodQuality: true,
      timestamp: start,
    );
    fusion.addGpsSpeed(
      speedMetresPerSecond: 3,
      isGoodQuality: true,
      timestamp: start.add(const Duration(seconds: 2)),
    );
    expect(fusion.currentState, 'running');

    fusion.addGpsSpeed(
      speedMetresPerSecond: 1.2,
      isGoodQuality: true,
      timestamp: start.add(const Duration(seconds: 4)),
    );
    fusion.addGpsSpeed(
      speedMetresPerSecond: 1.2,
      isGoodQuality: true,
      timestamp: start.add(const Duration(seconds: 6)),
    );
    expect(fusion.currentState, 'walking');
  });
}

GpsPoint _pointAt(
  DateTime timestamp, {
  required double metresNorth,
  double metresEast = 0,
  required double accuracy,
}) =>
    GpsPoint(
      latitude: 28.6139 + metresNorth / 111111,
      longitude: 77.2090 + metresEast / 97800,
      timestamp: timestamp,
      accuracy: accuracy,
    );

StepCadenceReading _cadenceReading({
  required double cadence,
  required String classification,
  required String rawClassification,
  String? pending,
  int confirmations = 0,
  bool transitioned = false,
}) =>
    StepCadenceReading(
      cadenceSpm: cadence,
      classification: classification,
      rawClassification: rawClassification,
      pendingClassification: pending,
      pendingConfirmations: confirmations,
      confirmationCount: confirmations,
      transitionConfirmationsRequired: 2,
      transitioned: transitioned,
      runningTransitionVetoed: false,
      isSensorAvailable: true,
    );
