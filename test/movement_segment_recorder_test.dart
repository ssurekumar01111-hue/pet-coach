import 'package:flutter_test/flutter_test.dart';
import 'package:pet_coach_ai/app/modules/tracker/movement_segment_recorder.dart';

void main() {
  test('records the live fused movement state and excludes paused time', () {
    final start = DateTime(2026, 7, 18, 6, 0);
    final recorder = MovementSegmentRecorder()
      ..begin(state: 'walking', at: start)
      ..addSpeedSample(1.2)
      // This transition represents the cadence-primary, GPS-vetoed UI state.
      ..transitionTo(
          state: 'running', at: start.add(const Duration(seconds: 10)))
      ..addSpeedSample(2.5)
      // Repeated cadence readings must keep this same running segment open.
      ..transitionTo(
          state: 'running', at: start.add(const Duration(seconds: 15)))
      ..pause(start.add(const Duration(seconds: 20)))
      ..resume(start.add(const Duration(seconds: 25)))
      ..transitionTo(
          state: 'walking', at: start.add(const Duration(seconds: 30)))
      ..addSpeedSample(1.1);

    final segments = recorder.finish(start.add(const Duration(seconds: 40)));

    expect(segments.map((segment) => segment.type), [
      'walking',
      'running',
      'walking',
    ]);
    expect(segments[0].endTime.difference(segments[0].startTime),
        const Duration(seconds: 10));
    expect(segments[1].endTime.difference(segments[1].startTime),
        const Duration(seconds: 20));
    expect(segments[1].activeDurationSec, 15);
    expect(segments[2].endTime.difference(segments[2].startTime),
        const Duration(seconds: 10));
    expect(segments[0].activeDurationSec, 10);
    expect(segments[2].activeDurationSec, 10);
  });
}
