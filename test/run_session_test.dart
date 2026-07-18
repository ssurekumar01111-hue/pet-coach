import 'package:flutter_test/flutter_test.dart';
import 'package:pet_coach_ai/app/data/models/run_session.dart';

void main() {
  test('Firestore serialization keeps stopwatch active time across a pause',
      () {
    // Timeline: run 10 seconds, pause for 5 seconds, then run 10 seconds.
    // Wall-clock timestamps span 25 seconds, but the tracker stopwatch records
    // only the 20 active seconds and that is what must reach Firestore.
    final start = DateTime(2026, 7, 18, 6, 0);
    final session = RunSession(
      id: 'session-1',
      uid: 'user-1',
      examId: 'up_home_guard',
      startTime: start,
      endTime: start.add(const Duration(seconds: 25)),
      gpsTrack: const [],
      segments: const [],
      totalDistanceKm: 0.04,
      totalTimeSec: 20,
    );

    final payload = session.toMap();
    expect(payload['totalTimeSec'], 20);
    expect(payload.containsKey('qualifiedDeterministic'), isFalse);
    expect(payload.containsKey('aiSummary'), isFalse);
    expect(payload.containsKey('recoverySummary'), isFalse);
  });
}
