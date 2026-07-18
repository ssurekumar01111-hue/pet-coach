import 'package:flutter_test/flutter_test.dart';
import 'package:pedometer/pedometer.dart';
import 'package:pet_coach_ai/app/modules/tracker/step_cadence_detector.dart';
import 'package:pet_coach_ai/app/modules/tracker/walk_run_detector.dart';

void main() {
  final start = DateTime(2026, 7, 18, 6, 30);

  test('zero steps stay stationary despite unrelated GPS noise', () {
    final detector = StepCadenceDetector(sensorAvailable: true);
    final noisyGps = WalkRunDetector();
    for (var index = 0; index < 5; index++) {
      noisyGps.addSpeedSample(3.0, start.add(Duration(seconds: index + 1)));
    }

    final reading = detector.readingAt(start.add(const Duration(seconds: 6)));

    expect(reading.cadenceSpm, 0);
    expect(reading.classification, 'stationary');
    // The GPS-only signal could say running, but it must not override zero steps.
    expect(noisyGps.currentState, 'running');
  });

  test('walking cadence commits after two consecutive calculations', () {
    final detector = StepCadenceDetector(sensorAvailable: true);
    _recordSteps(detector, count: 12, start: start); // 120 spm over 6 seconds.

    final first = detector.refreshAt(start.add(const Duration(seconds: 6)));
    final second = detector.refreshAt(start.add(const Duration(seconds: 7)));

    expect(first.rawClassification, 'walking');
    expect(first.classification, 'stationary');
    expect(first.pendingClassification, 'walking');
    expect(first.pendingConfirmations, 1);
    expect(second.classification, 'walking');
    expect(second.transitioned, isTrue);
  });

  test('brief running-level cadence spike does not commit to running', () {
    final detector = StepCadenceDetector(sensorAvailable: true);
    _recordSteps(detector, count: 12, start: start);
    detector.refreshAt(start.add(const Duration(seconds: 6)));
    expect(
        detector
            .refreshAt(start.add(const Duration(seconds: 7)))
            .classification,
        'walking');

    // Three seconds of fast steps temporarily lifts the six-second rolling
    // cadence above 155 spm, but it receives only one confirmation.
    _recordSteps(
      detector,
      count: 11,
      start: start.add(const Duration(seconds: 7)),
      initialSystemCount: 112,
      duration: const Duration(seconds: 3),
    );
    final spike = detector.refreshAt(start.add(const Duration(seconds: 10)));
    final recovered =
        detector.refreshAt(start.add(const Duration(seconds: 11)));

    expect(spike.rawClassification, 'running');
    expect(spike.classification, 'walking');
    expect(spike.pendingClassification, 'running');
    expect(spike.pendingConfirmations, 1);
    expect(recovered.rawClassification, 'walking');
    expect(recovered.classification, 'walking');
    expect(recovered.hasPendingTransition, isFalse);
  });

  test('sustained running cadence commits only on the second confirmation', () {
    var guardCalls = 0;
    final detector = StepCadenceDetector(sensorAvailable: true);
    detector.setTransitionGuard((_) {
      guardCalls++;
      return true;
    });
    _recordSteps(detector, count: 18, start: start); // 180 spm over 6 seconds.

    final first = detector.refreshAt(start.add(const Duration(seconds: 6)));
    expect(first.rawClassification, 'running');
    expect(first.classification, 'stationary');
    expect(first.pendingConfirmations, 1);
    expect(first.confirmationCount, 1);
    expect(first.transitioned, isFalse);
    expect(guardCalls, 0);

    final second = detector.refreshAt(start.add(const Duration(seconds: 7)));
    expect(second.rawClassification, 'running');
    expect(second.classification, 'running');
    expect(second.confirmationCount, 2);
    expect(second.transitioned, isTrue);
    expect(guardCalls, 1);
  });

  test('cadence running is vetoed when GPS remains at walking speed', () {
    const gpsWalkingSpeed = .8;
    final detector = StepCadenceDetector(
      sensorAvailable: true,
      transitionGuard: (transition) =>
          transition.to != 'running' || gpsWalkingSpeed >= 1.9,
    );

    _recordSteps(detector, count: 12, start: start); // Establish walking.
    detector.refreshAt(start.add(const Duration(seconds: 6)));
    expect(
      detector.refreshAt(start.add(const Duration(seconds: 7))).classification,
      'walking',
    );

    _recordSteps(
      detector,
      count: 18,
      start: start.add(const Duration(seconds: 7)),
      initialSystemCount: 112,
      duration: const Duration(seconds: 4),
    );
    final firstRunningConfirmation =
        detector.refreshAt(start.add(const Duration(seconds: 11)));
    final vetoed = detector.refreshAt(start.add(const Duration(seconds: 12)));

    expect(firstRunningConfirmation.rawClassification, 'running');
    expect(firstRunningConfirmation.classification, 'walking');
    expect(firstRunningConfirmation.confirmationCount, 1);
    expect(vetoed.rawClassification, 'running');
    expect(vetoed.classification, 'walking');
    expect(vetoed.confirmationCount, 2);
    expect(vetoed.runningTransitionVetoed, isTrue);
    expect(vetoed.pendingClassification, 'running');
  });

  test('sensor-unavailable mode falls back to GPS speed classification', () {
    final cadence = StepCadenceDetector();
    final gps = WalkRunDetector();
    for (var index = 0; index < 5; index++) {
      gps.addSpeedSample(3.0, start.add(Duration(seconds: index + 1)));
    }

    expect(cadence.readingAt(start).isSensorAvailable, isFalse);
    expect(cadence.readingAt(start).classification, 'unavailable');
    expect(gps.currentState, 'running');
  });

  test('no first pedometer event activates the GPS fallback path', () async {
    Object? unavailableReason;
    final detector = StepCadenceDetector(
      firstReadingTimeout: const Duration(milliseconds: 10),
      stepCountStream: Stream<StepCount>.empty(),
    );

    await detector.start(
      onReading: (_) {},
      onUnavailable: (error) => unavailableReason = error,
    );
    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(detector.isSensorAvailable, isFalse);
    expect(unavailableReason, isA<StepCadenceSensorTimeout>());
    await detector.stop();
  });
}

void _recordSteps(
  StepCadenceDetector detector, {
  required int count,
  required DateTime start,
  int initialSystemCount = 100,
  Duration duration = const Duration(seconds: 6),
}) {
  detector.ingestStepCount(initialSystemCount, start);
  for (var index = 1; index <= count; index++) {
    detector.ingestStepCount(
      initialSystemCount + index,
      start.add(Duration(
        milliseconds: (duration.inMilliseconds * index / count).round(),
      )),
    );
  }
}
