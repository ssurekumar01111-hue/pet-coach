import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:pedometer/pedometer.dart';

/// Primary movement signal backed by the platform step counter.
///
/// A short six-second window makes cadence react quickly. A two-calculation
/// confirmation prevents a transient cadence burst from flipping the visible
/// walk/run state.
class StepCadenceDetector {
  StepCadenceDetector({
    this.window = const Duration(seconds: 6),
    this.transitionConfirmations = 2,
    this.firstReadingTimeout = const Duration(seconds: 12),
    StepCadenceTransitionGuard? transitionGuard,
    bool sensorAvailable = false,
    Stream<StepCount>? stepCountStream,
  })  : assert(transitionConfirmations > 0),
        assert(!firstReadingTimeout.isNegative &&
            firstReadingTimeout != Duration.zero),
        _transitionGuard = transitionGuard,
        _sensorAvailable = sensorAvailable,
        _stepCountStream = stepCountStream ?? Pedometer.stepCountStream,
        _committedClassification =
            sensorAvailable ? 'stationary' : 'unavailable';

  /// A higher cadence is required to enter running than to leave it. This
  /// hysteresis keeps a runner whose device reports 140-160 spm from
  /// repeatedly bouncing between walking and running around one cutoff.
  static const runningCadenceEnterThresholdSpm = 155.0;
  static const runningCadenceExitThresholdSpm = 140.0;

  /// Kept as a compatibility alias for callers/tests that reference the old
  /// single threshold. New classification uses the explicit enter/exit pair.
  static const runningCadenceThresholdSpm = runningCadenceEnterThresholdSpm;

  final Duration window;
  final int transitionConfirmations;
  final Duration firstReadingTimeout;
  final Stream<StepCount> _stepCountStream;
  final List<DateTime> _stepTimes = [];
  StepCadenceTransitionGuard? _transitionGuard;
  bool _sensorAvailable;
  int? _lastSystemStepCount;
  String _committedClassification;
  String? _pendingClassification;
  var _pendingConfirmations = 0;
  StreamSubscription<StepCount>? _subscription;
  Timer? _ticker;
  Timer? _firstReadingTimer;
  var _receivedFirstStepEvent = false;
  void Function(StepCadenceReading reading)? _onReading;
  void Function(Object error)? _onUnavailable;

  bool get isSensorAvailable => _sensorAvailable;

  /// Lets the tracker add an independent signal before committing a cadence
  /// transition. The detector remains deterministic and does not depend on
  /// GPS directly.
  void setTransitionGuard(StepCadenceTransitionGuard? transitionGuard) {
    _transitionGuard = transitionGuard;
  }

  Future<void> start({
    required void Function(StepCadenceReading reading) onReading,
    required void Function(Object error) onUnavailable,
  }) async {
    await stop();
    _onReading = onReading;
    _onUnavailable = onUnavailable;
    // An EventChannel error or a missing first event switches to GPS fallback.
    _sensorAvailable = true;
    _receivedFirstStepEvent = false;
    _committedClassification = 'stationary';
    _clearPendingTransition();
    _emit(DateTime.now());
    _subscription = _stepCountStream.listen(
      (event) => ingestStepCount(event.steps, event.timeStamp),
      onError: _markUnavailable,
      cancelOnError: false,
    );
    if (_sensorAvailable && !_receivedFirstStepEvent) {
      _firstReadingTimer =
          Timer(firstReadingTimeout, _handleFirstReadingTimeout);
    }
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      _emit(DateTime.now());
    });
  }

  /// Accepts cumulative system step counts. Public to make cadence behavior
  /// deterministic in tests without a platform EventChannel.
  void ingestStepCount(int systemStepCount, DateTime timestamp) {
    _receivedFirstStepEvent = true;
    _firstReadingTimer?.cancel();
    _firstReadingTimer = null;
    final previous = _lastSystemStepCount;
    _lastSystemStepCount = systemStepCount;
    if (previous != null && systemStepCount > previous) {
      final newSteps = (systemStepCount - previous).clamp(0, 30).toInt();
      for (var index = 0; index < newSteps; index++) {
        _stepTimes.add(timestamp);
      }
    } else if (previous != null && systemStepCount < previous) {
      _stepTimes.clear();
    }
  }

  /// Returns the stable state and any currently pending state transition.
  /// This is observational and never advances debounce confirmation.
  StepCadenceReading readingAt(DateTime now) =>
      _buildReading(now, advance: false);

  /// Advances one cadence calculation. Used by the stream/ticker and tests.
  StepCadenceReading refreshAt(DateTime now) =>
      _buildReading(now, advance: true);

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    _ticker?.cancel();
    _ticker = null;
    _firstReadingTimer?.cancel();
    _firstReadingTimer = null;
  }

  void reset() {
    _stepTimes.clear();
    _lastSystemStepCount = null;
    _committedClassification = _sensorAvailable ? 'stationary' : 'unavailable';
    _clearPendingTransition();
  }

  /// Prepares the deterministic detector for debug-only synthetic input.
  /// Production tracking always initializes it through [start].
  void enableSyntheticInput() {
    if (!kDebugMode) return;
    _sensorAvailable = true;
    _receivedFirstStepEvent = true;
    _stepTimes.clear();
    _lastSystemStepCount = null;
    _committedClassification = 'stationary';
    _clearPendingTransition();
    _firstReadingTimer?.cancel();
    _firstReadingTimer = null;
  }

  void _handleFirstReadingTimeout() {
    if (!_sensorAvailable || _receivedFirstStepEvent) return;
    _markUnavailable(
      StepCadenceSensorTimeout(firstReadingTimeout),
    );
  }

  void _markUnavailable(Object error) {
    if (!_sensorAvailable) return;
    _sensorAvailable = false;
    _firstReadingTimer?.cancel();
    _firstReadingTimer = null;
    _stepTimes.clear();
    _committedClassification = 'unavailable';
    _clearPendingTransition();
    _onUnavailable?.call(error);
    _emit(DateTime.now());
  }

  void _emit(DateTime now) {
    final reading = refreshAt(now);
    _onReading?.call(reading);
  }

  StepCadenceReading _buildReading(DateTime now, {required bool advance}) {
    _prune(now);
    final cadence = _stepTimes.length * 60 / window.inSeconds;
    final rawClassification = _rawClassificationFor(cadence);
    var transitioned = false;
    var runningTransitionVetoed = false;
    var confirmationCount = _pendingConfirmations;

    if (advance && _sensorAvailable) {
      if (rawClassification == _committedClassification) {
        _clearPendingTransition();
      } else if (rawClassification == _pendingClassification) {
        // Keep a confirmed-but-vetoed transition at the required count. That
        // allows it to commit later when the secondary signal supports it,
        // without letting the count drift past the debounce threshold.
        if (_pendingConfirmations < transitionConfirmations) {
          _pendingConfirmations++;
        }
      } else {
        _pendingClassification = rawClassification;
        _pendingConfirmations = 1;
      }
      confirmationCount = _pendingConfirmations;

      // An exact threshold makes the debounce contract explicit: the first
      // pending reading is never allowed to commit a transition.
      if (_pendingConfirmations == transitionConfirmations) {
        final transition = StepCadenceTransition(
          from: _committedClassification,
          to: rawClassification,
          cadenceSpm: cadence,
          confirmations: confirmationCount,
          confirmationsRequired: transitionConfirmations,
        );
        final canCommit = _transitionGuard?.call(transition) ?? true;
        if (canCommit) {
          _committedClassification = rawClassification;
          transitioned = true;
          _clearPendingTransition();
        } else if (rawClassification == 'running') {
          runningTransitionVetoed = true;
        }
      }
    }

    return StepCadenceReading(
      cadenceSpm: cadence,
      classification: _committedClassification,
      rawClassification: rawClassification,
      pendingClassification: _pendingClassification,
      pendingConfirmations: _pendingConfirmations,
      confirmationCount: confirmationCount,
      transitionConfirmationsRequired: transitionConfirmations,
      transitioned: transitioned,
      runningTransitionVetoed: runningTransitionVetoed,
      isSensorAvailable: _sensorAvailable,
    );
  }

  void _prune(DateTime now) {
    final cutoff = now.subtract(window);
    _stepTimes.removeWhere((timestamp) => timestamp.isBefore(cutoff));
  }

  void _clearPendingTransition() {
    _pendingClassification = null;
    _pendingConfirmations = 0;
  }

  String _rawClassificationFor(double cadenceSpm) {
    if (!_sensorAvailable) return 'unavailable';
    if (cadenceSpm == 0) return 'stationary';
    if (_committedClassification == 'running' &&
        cadenceSpm >= runningCadenceExitThresholdSpm) {
      return 'running';
    }
    if (cadenceSpm < runningCadenceEnterThresholdSpm) return 'walking';
    return 'running';
  }
}

typedef StepCadenceTransitionGuard = bool Function(
  StepCadenceTransition transition,
);

class StepCadenceTransition {
  const StepCadenceTransition({
    required this.from,
    required this.to,
    required this.cadenceSpm,
    required this.confirmations,
    required this.confirmationsRequired,
  });

  final String from;
  final String to;
  final double cadenceSpm;
  final int confirmations;
  final int confirmationsRequired;
}

class StepCadenceReading {
  const StepCadenceReading({
    required this.cadenceSpm,
    required this.classification,
    required this.rawClassification,
    required this.pendingClassification,
    required this.pendingConfirmations,
    required this.confirmationCount,
    required this.transitionConfirmationsRequired,
    required this.transitioned,
    required this.runningTransitionVetoed,
    required this.isSensorAvailable,
  });

  final double cadenceSpm;
  final String classification;
  final String rawClassification;
  final String? pendingClassification;
  final int pendingConfirmations;

  /// The confirmation count observed for this calculation, including a
  /// transition that was committed and then cleared from pending state.
  final int confirmationCount;
  final int transitionConfirmationsRequired;
  final bool transitioned;
  final bool runningTransitionVetoed;
  final bool isSensorAvailable;

  bool get hasPendingTransition => pendingClassification != null;
}

class StepCadenceSensorTimeout implements Exception {
  const StepCadenceSensorTimeout(this.timeout);

  final Duration timeout;

  @override
  String toString() =>
      'No pedometer step event was received within ${timeout.inSeconds} seconds.';
}
