import 'package:flutter_test/flutter_test.dart';
import 'package:pet_coach_ai/app/modules/tracker/walk_run_detector.dart';

void main() {
  DateTime time = DateTime(2026);
  void add(WalkRunDetector detector, double speed) {
    time = time.add(const Duration(seconds: 1));
    detector.addSpeedSample(speed, time);
  }

  test('classifies steady running', () {
    final detector = WalkRunDetector();
    for (var index = 0; index < 8; index++) {
      add(detector, 3.0);
    }
    expect(detector.currentState, 'running');
    expect(detector.segments, isEmpty);
  });

  test('classifies steady walking', () {
    final detector = WalkRunDetector();
    for (var index = 0; index < 8; index++) {
      add(detector, 1.5);
    }
    expect(detector.currentState, 'walking');
    expect(detector.segments, isEmpty);
  });

  test('emits a running segment after a debounced run-to-walk transition', () {
    final detector = WalkRunDetector();
    for (var index = 0; index < 5; index++) {
      add(detector, 3.0);
    }
    for (var index = 0; index < 8; index++) {
      add(detector, 1.5);
    }
    expect(detector.currentState, 'walking');
    expect(detector.segments, hasLength(1));
    expect(detector.segments.single.type, 'running');
  });

  test('does not transition for short noisy data around the threshold', () {
    final detector = WalkRunDetector();
    for (var index = 0; index < 5; index++) {
      add(detector, 3.0);
    }
    for (final speed in [1.5, 1.5, 3.0, 3.0, 1.5, 1.5, 3.0, 3.0]) {
      add(detector, speed);
    }
    expect(detector.currentState, 'running');
    expect(detector.segments, isEmpty);
  });
}
