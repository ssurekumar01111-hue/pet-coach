import 'step_cadence_detector.dart';

/// Fuses cadence and quality-filtered GPS speed into the state shown to the
/// runner and recorded in movement segments.
///
/// Cadence is authoritative only for a confirmed stationary state: GPS drift
/// can never turn zero steps into a run. For walking and running, neither
/// sensor is exclusive. Cadence can promote quickly unless GPS has sustained,
/// good-quality evidence of clearly slow movement, and GPS can promote after
/// sustained running speed if a pedometer under-reports steps.
class MotionFusionDetector {
  MotionFusionDetector({
    this.gpsRunningSpeedMetresPerSecond = 2.2,
    this.gpsClearlySlowSpeedMetresPerSecond = 1.5,
    this.requiredGpsEvidenceSamples = 2,
    this.requiredCadenceLowSamples = 2,
  })  : assert(gpsClearlySlowSpeedMetresPerSecond <
            gpsRunningSpeedMetresPerSecond),
        assert(requiredGpsEvidenceSamples > 0),
        assert(requiredCadenceLowSamples > 0);

  /// Matches the existing deterministic GPS running threshold, but requires
  /// more than one good reading so an isolated noisy point cannot promote.
  final double gpsRunningSpeedMetresPerSecond;

  /// Only this clearly walking-level speed can veto cadence-led running.
  /// Values near a boundary (for example 1.89 vs 1.90 m/s) are deliberately
  /// inconclusive rather than a hard veto.
  final double gpsClearlySlowSpeedMetresPerSecond;
  final int requiredGpsEvidenceSamples;
  final int requiredCadenceLowSamples;

  String _state = 'walking';
  var _cadenceSensorAvailable = false;
  var _cadenceStationary = false;
  var _cadenceLowStreak = 0;
  var _gpsRunningStreak = 0;
  var _gpsSlowStreak = 0;

  String get currentState => _state;
  int get gpsRunningStreak => _gpsRunningStreak;
  int get gpsSlowStreak => _gpsSlowStreak;
  int get cadenceLowStreak => _cadenceLowStreak;

  void reset({String initialState = 'walking'}) {
    _state = initialState;
    _cadenceSensorAvailable = false;
    _cadenceStationary = false;
    _cadenceLowStreak = 0;
    _gpsRunningStreak = 0;
    _gpsSlowStreak = 0;
  }

  MotionFusionDecision setCadenceSensorAvailable(
    bool available,
    DateTime timestamp,
  ) {
    _cadenceSensorAvailable = available;
    _cadenceStationary = false;
    _cadenceLowStreak = 0;
    if (!available && _state == 'stationary') {
      // A dead or revoked pedometer must not leave the UI permanently stuck
      // in stationary. Subsequent GPS samples remain the fallback source.
      return _transitionTo('walking', timestamp, 'gps-fallback');
    }
    return _noChange('sensor-${available ? 'available' : 'unavailable'}');
  }

  MotionFusionDecision addCadenceReading(
    StepCadenceReading reading,
    DateTime timestamp,
  ) {
    _cadenceSensorAvailable = reading.isSensorAvailable;
    if (!reading.isSensorAvailable) {
      _cadenceStationary = false;
      return _evaluateGpsFallback(timestamp);
    }

    _cadenceStationary = reading.classification == 'stationary';
    if (_cadenceStationary) {
      _cadenceLowStreak = 0;
      return _transitionTo('stationary', timestamp, 'cadence-stationary');
    }

    final cadenceClearlyLow = reading.rawClassification == 'walking' &&
        reading.cadenceSpm <=
            StepCadenceDetector.runningCadenceExitThresholdSpm;
    _cadenceLowStreak = cadenceClearlyLow ? _cadenceLowStreak + 1 : 0;

    if (reading.classification == 'running') {
      if (_hasSustainedClearlySlowGps) {
        return _noChange('cadence-running-vetoed-by-slow-gps', vetoed: true);
      }
      return _transitionTo('running', timestamp, 'cadence-running');
    }

    if (_state == 'stationary') {
      return _transitionTo('walking', timestamp, 'cadence-walking');
    }
    if (_state == 'running' &&
        _cadenceLowStreak >= requiredCadenceLowSamples &&
        _hasSustainedClearlySlowGps) {
      return _transitionTo('walking', timestamp, 'fused-running-exit');
    }
    return _noChange('cadence-walking-held');
  }

  /// Adds a GPS speed only after the raw GPS distance pipeline has checked
  /// jump speed and position quality.
  MotionFusionDecision addGpsSpeed({
    required double speedMetresPerSecond,
    required bool isGoodQuality,
    required DateTime timestamp,
  }) {
    if (!isGoodQuality || !speedMetresPerSecond.isFinite) {
      return _noChange('gps-weak-or-invalid');
    }

    if (speedMetresPerSecond >= gpsRunningSpeedMetresPerSecond) {
      _gpsRunningStreak++;
      _gpsSlowStreak = 0;
    } else if (speedMetresPerSecond <= gpsClearlySlowSpeedMetresPerSecond) {
      _gpsSlowStreak++;
      _gpsRunningStreak = 0;
    } else {
      // Near the boundary is deliberately neutral. This removes the old
      // knife-edge 1.89 vs 1.90 m/s veto behaviour.
      _gpsRunningStreak = 0;
      _gpsSlowStreak = 0;
    }

    // Confirmed zero-step stationary remains authoritative even if GPS drifts.
    if (_cadenceSensorAvailable && _cadenceStationary) {
      return _noChange('cadence-stationary-overrides-gps');
    }

    if (_gpsRunningStreak >= requiredGpsEvidenceSamples) {
      return _transitionTo('running', timestamp, 'gps-running');
    }
    if (_state == 'running' &&
        _hasSustainedClearlySlowGps &&
        (!_cadenceSensorAvailable ||
            _cadenceLowStreak >= requiredCadenceLowSamples)) {
      return _transitionTo('walking', timestamp, 'fused-running-exit');
    }
    return _noChange('gps-evidence-pending');
  }

  MotionFusionDecision _evaluateGpsFallback(DateTime timestamp) {
    if (_gpsRunningStreak >= requiredGpsEvidenceSamples) {
      return _transitionTo('running', timestamp, 'gps-fallback-running');
    }
    if (_state == 'running' && _hasSustainedClearlySlowGps) {
      return _transitionTo('walking', timestamp, 'gps-fallback-walking');
    }
    return _noChange('gps-fallback-pending');
  }

  bool get _hasSustainedClearlySlowGps =>
      _gpsSlowStreak >= requiredGpsEvidenceSamples;

  MotionFusionDecision _transitionTo(
    String nextState,
    DateTime timestamp,
    String source,
  ) {
    final previous = _state;
    _state = nextState;
    return MotionFusionDecision(
      previousState: previous,
      state: _state,
      timestamp: timestamp,
      source: source,
      transitioned: previous != _state,
      gpsRunningStreak: _gpsRunningStreak,
      gpsSlowStreak: _gpsSlowStreak,
      cadenceLowStreak: _cadenceLowStreak,
    );
  }

  MotionFusionDecision _noChange(String source, {bool vetoed = false}) =>
      MotionFusionDecision(
        previousState: _state,
        state: _state,
        timestamp: DateTime.now(),
        source: source,
        transitioned: false,
        runningVetoed: vetoed,
        gpsRunningStreak: _gpsRunningStreak,
        gpsSlowStreak: _gpsSlowStreak,
        cadenceLowStreak: _cadenceLowStreak,
      );
}

class MotionFusionDecision {
  const MotionFusionDecision({
    required this.previousState,
    required this.state,
    required this.timestamp,
    required this.source,
    required this.transitioned,
    required this.gpsRunningStreak,
    required this.gpsSlowStreak,
    required this.cadenceLowStreak,
    this.runningVetoed = false,
  });

  final String previousState;
  final String state;
  final DateTime timestamp;
  final String source;
  final bool transitioned;
  final bool runningVetoed;
  final int gpsRunningStreak;
  final int gpsSlowStreak;
  final int cadenceLowStreak;
}
