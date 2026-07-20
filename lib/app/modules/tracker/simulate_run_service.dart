import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/models/gps_point.dart';

/// Debug-only synthetic sensor source for recording demos.
///
/// It deliberately emits into TrackerController's normal GPS and cadence
/// handlers. Only the input source is simulated; filtering, cadence debounce,
/// GPS vetoes, sampled distance, state changes, and voice cues are real.
class SimulateRunService {
  static const _realTick = Duration(seconds: 1);
  static const _simulatedTick = Duration(seconds: 3);

  Future<void> run({
    required void Function(GpsPoint point) onGpsPoint,
    required void Function(int cumulativeSteps, DateTime timestamp) onStepCount,
    required bool Function() isActive,
  }) async {
    if (!kDebugMode) return;

    var timestamp = DateTime.now();
    var latitude = 28.6139;
    const longitude = 77.2090;
    var cumulativeSteps = 1000;
    onStepCount(cumulativeSteps, timestamp); // Establish the system baseline.

    await _emitPhase(
      ticks: 4,
      metresPerTick: 8,
      stepsPerTick: 5,
      onGpsPoint: onGpsPoint,
      onStepCount: onStepCount,
      isActive: isActive,
      timestamp: () => timestamp,
      setTimestamp: (value) => timestamp = value,
      latitude: () => latitude,
      setLatitude: (value) => latitude = value,
      longitude: longitude,
      cumulativeSteps: () => cumulativeSteps,
      setCumulativeSteps: (value) => cumulativeSteps = value,
    );
    // 17 accelerated running samples cover roughly 0.5 km in 25 real seconds
    // across the whole demo while remaining under the GPS jump-speed ceiling.
    await _emitPhase(
      ticks: 17,
      metresPerTick: 32,
      stepsPerTick: 8,
      onGpsPoint: onGpsPoint,
      onStepCount: onStepCount,
      isActive: isActive,
      timestamp: () => timestamp,
      setTimestamp: (value) => timestamp = value,
      latitude: () => latitude,
      setLatitude: (value) => latitude = value,
      longitude: longitude,
      cumulativeSteps: () => cumulativeSteps,
      setCumulativeSteps: (value) => cumulativeSteps = value,
    );
    await _emitPhase(
      ticks: 4,
      metresPerTick: 8,
      stepsPerTick: 5,
      onGpsPoint: onGpsPoint,
      onStepCount: onStepCount,
      isActive: isActive,
      timestamp: () => timestamp,
      setTimestamp: (value) => timestamp = value,
      latitude: () => latitude,
      setLatitude: (value) => latitude = value,
      longitude: longitude,
      cumulativeSteps: () => cumulativeSteps,
      setCumulativeSteps: (value) => cumulativeSteps = value,
    );
  }

  Future<void> _emitPhase({
    required int ticks,
    required double metresPerTick,
    required int stepsPerTick,
    required void Function(GpsPoint point) onGpsPoint,
    required void Function(int cumulativeSteps, DateTime timestamp) onStepCount,
    required bool Function() isActive,
    required DateTime Function() timestamp,
    required void Function(DateTime value) setTimestamp,
    required double Function() latitude,
    required void Function(double value) setLatitude,
    required double longitude,
    required int Function() cumulativeSteps,
    required void Function(int value) setCumulativeSteps,
  }) async {
    for (var tick = 0; tick < ticks; tick++) {
      await Future<void>.delayed(_realTick);
      if (!isActive()) return;

      final nextTimestamp = timestamp().add(_simulatedTick);
      setTimestamp(nextTimestamp);
      final nextLatitude = latitude() + metresPerTick / 111320;
      setLatitude(nextLatitude);
      final nextSteps = cumulativeSteps() + stepsPerTick;
      setCumulativeSteps(nextSteps);

      onGpsPoint(GpsPoint(
        latitude: nextLatitude,
        longitude: longitude,
        timestamp: nextTimestamp,
        accuracy: 3,
      ));
      onStepCount(nextSteps, nextTimestamp);
    }
  }
}
