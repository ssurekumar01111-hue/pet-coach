import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:battery_plus/battery_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../data/models/exam_config.dart';
import '../../data/models/gps_point.dart';
import '../../data/models/run_session.dart';
import '../../services/hydration_service.dart';
import '../../services/field_test_log_service.dart';
import '../../services/offline_session_sync_service.dart';
import 'gps_distance_accumulator.dart';
import 'movement_segment_recorder.dart';
import 'motion_fusion_detector.dart';
import 'simulate_run_service.dart';
import 'step_cadence_detector.dart';
import 'walk_run_detector.dart';

class TrackerController extends GetxController {
  TrackerController({
    FirebaseAuth? auth,
    FlutterTts? tts,
    HydrationService? hydration,
    OfflineSessionSyncService? offlineSync,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _tts = tts ?? FlutterTts(),
        _hydration = hydration ??
            (Get.isRegistered<HydrationService>()
                ? Get.find<HydrationService>()
                : null),
        _offlineSync = offlineSync ??
            (Get.isRegistered<OfflineSessionSyncService>()
                ? Get.find<OfflineSessionSyncService>()
                : null);

  static const _sampleInterval = Duration(seconds: 3);
  static const _maxValidSpeedMetresPerSecond = 12.0;
  static const _voiceCueIntervalKm = .5;
  static const _batterySampleInterval = Duration(minutes: 5);
  static const _emaAlpha = .35;

  final FirebaseAuth _auth;
  final FlutterTts _tts;
  final HydrationService? _hydration;
  final OfflineSessionSyncService? _offlineSync;
  final FieldTestLogService _fieldTestLog = FieldTestLogService();
  final isTracking = false.obs;
  final isPaused = false.obs;
  final elapsed = Duration.zero.obs;
  final distanceKm = 0.0.obs;
  final currentPaceSecPerKm = 0.0.obs;
  final movementState = 'walking'.obs;
  final gpsJumpCount = 0.obs;
  final errorMessage = RxnString();
  final isVoiceEnabled = true.obs;
  final completedSession = Rxn<RunSession>();
  final debugBatteryPercent = RxnInt();
  final stepCadenceSpm = 0.0.obs;
  final isStepSensorAvailable = false.obs;
  final isDemoSimulationRunning = false.obs;

  final List<GpsPoint> _sampledPoints = [];
  final WalkRunDetector _detector = WalkRunDetector();
  final GpsDistanceAccumulator _distanceAccumulator = GpsDistanceAccumulator();
  final MotionFusionDetector _motionFusion = MotionFusionDetector();
  final MovementSegmentRecorder _movementSegmentRecorder =
      MovementSegmentRecorder();
  final StepCadenceDetector _stepCadenceDetector = StepCadenceDetector();
  final SimulateRunService _simulateRunService = SimulateRunService();
  final Stopwatch _stopwatch = Stopwatch();
  StreamSubscription<Position>? _positionSubscription;
  Timer? _elapsedTimer;
  Timer? _batteryTimer;
  GpsPoint? _lastSmoothedPoint;
  GpsPoint? _lastAcceptedRawPoint;
  GpsPoint? _lastPersistedPoint;
  DateTime? _sessionStart;
  String? _sessionId;
  double _nextVoiceCueAtKm = _voiceCueIntervalKm;
  bool _isSpeaking = false;
  var _isDemoSession = false;
  StepCadenceReading? _lastCadenceReading;

  @override
  void onInit() {
    super.onInit();
    _configureTts();
  }

  Future<void> start() async {
    if (isTracking.value && !isPaused.value) return;
    errorMessage.value = null;
    if (!await _ensureLocationPermission()) return;

    if (isPaused.value) {
      _resumeTrackingSession();
    } else {
      await _beginNewTrackingSession();
    }
    _startElapsedTimer();
    _startDebugBatterySampling();
    await _startStepCadenceDetection();
    _positionSubscription ??= Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen(_onPosition, onError: (Object error) {
      errorMessage.value = 'Unable to receive location updates: $error';
    });
  }

  /// Starts a synthetic debug session without requesting device sensor input.
  /// The simulator feeds the normal GPS/cadence processing pipeline below.
  Future<void> startDemoSimulation() async {
    if (!kDebugMode || isTracking.value || isDemoSimulationRunning.value) {
      return;
    }
    errorMessage.value = null;
    await _beginNewTrackingSession(isDemo: true);
    _startElapsedTimer();
    _startDebugBatterySampling();
    _stepCadenceDetector.enableSyntheticInput();
    isStepSensorAvailable.value = true;
    _motionFusion.setCadenceSensorAvailable(true, DateTime.now());
    isDemoSimulationRunning.value = true;
    try {
      await _simulateRunService.run(
        onGpsPoint: _processGpsPoint,
        onStepCount: _injectSyntheticStepCount,
        isActive: () =>
            isTracking.value &&
            !isPaused.value &&
            isDemoSimulationRunning.value,
      );
    } finally {
      isDemoSimulationRunning.value = false;
    }
  }

  Future<void> _beginNewTrackingSession({bool isDemo = false}) async {
    _isDemoSession = isDemo;
    _detector.reset();
    _distanceAccumulator.reset();
    _motionFusion.reset();
    _sampledPoints.clear();
    _lastSmoothedPoint = null;
    _lastAcceptedRawPoint = null;
    _stepCadenceDetector.reset();
    _lastCadenceReading = null;
    _lastPersistedPoint = null;
    _sessionStart = DateTime.now();
    movementState.value = 'walking';
    _movementSegmentRecorder.begin(
      state: movementState.value,
      at: _sessionStart!,
    );
    if (kDebugMode) {
      try {
        await _fieldTestLog.startSession(_sessionStart!);
      } catch (_) {
        debugPrint('[FieldTestLog] unable to create session log');
      }
    }
    _sessionId = FirebaseFirestore.instance.collection('sessions').doc().id;
    distanceKm.value = 0;
    currentPaceSecPerKm.value = 0;
    gpsJumpCount.value = 0;
    _nextVoiceCueAtKm = _voiceCueIntervalKm;
    _stopwatch
      ..reset()
      ..start();
    isTracking.value = true;
  }

  void _resumeTrackingSession() {
    isPaused.value = false;
    _stopwatch.start();
    _movementSegmentRecorder.resume(DateTime.now());
  }

  Future<void> pause() async {
    if (!isTracking.value || isPaused.value) return;
    isDemoSimulationRunning.value = false;
    isPaused.value = true;
    _stopwatch.stop();
    _movementSegmentRecorder.pause(DateTime.now());
    _elapsedTimer?.cancel();
    _batteryTimer?.cancel();
    await _stepCadenceDetector.stop();
    await _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  Future<void> stop() async {
    if (!isTracking.value) return;
    isDemoSimulationRunning.value = false;
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    _elapsedTimer?.cancel();
    _batteryTimer?.cancel();
    await _stepCadenceDetector.stop();
    _stopwatch.stop();
    await _stopSpeaking();
    final wallClockEndTime = DateTime.now();
    final syntheticEndTime =
        _isDemoSession ? _lastAcceptedRawPoint?.timestamp : null;
    final endTime =
        syntheticEndTime != null && syntheticEndTime.isAfter(wallClockEndTime)
            ? syntheticEndTime
            : wallClockEndTime;
    final segments = _movementSegmentRecorder.finish(endTime);
    final uid = _auth.currentUser?.uid;
    if (uid != null && _sessionStart != null && _sessionId != null) {
      final exam = Get.arguments as ExamConfig?;
      final session = RunSession(
        id: _sessionId!,
        uid: uid,
        examId: exam?.id ?? '',
        startTime: _sessionStart!,
        endTime: endTime,
        gpsTrack: List.unmodifiable(_sampledPoints),
        segments: segments,
        totalDistanceKm: distanceKm.value,
        totalTimeSec: _stopwatch.elapsed.inSeconds,
      );
      completedSession.value = session;
      await _offlineSync?.enqueue(session);
      unawaited(_hydration?.notifyRunCompleted() ?? Future<void>.value());
    }
    isTracking.value = false;
    isPaused.value = false;
    _isDemoSession = false;
  }

  Future<bool> _ensureLocationPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      errorMessage.value = 'Please enable location services to track your run.';
      return false;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      errorMessage.value = 'Location permission is required to track your run.';
      return false;
    }
    // Android may offer this separately; decline does not block foreground runs.
    await Permission.locationAlways.request();
    return true;
  }

  void _onPosition(Position position) {
    final point = GpsPoint(
      latitude: position.latitude,
      longitude: position.longitude,
      timestamp: position.timestamp,
      accuracy: position.accuracy,
    );
    _processGpsPoint(point);
  }

  /// Shared by real [Position] updates and the debug simulator. Keeping the
  /// filtering/persistence path here prevents demo-only shortcuts.
  void _processGpsPoint(GpsPoint point) {
    final update = _distanceAccumulator.add(point);
    _debugGpsDistanceUpdate(update);

    if (update.isRejectedJump) {
      _debugGps(
        point,
        speed: update.rawSegmentSpeedMetresPerSecond,
        passed: false,
      );
      gpsJumpCount.value++;
      return;
    }

    // GPS movement evidence is intentionally independent of the canonical
    // distance acceptance buffer. This lets two good, sustained running-speed
    // samples promote a run promptly while still keeping distance drift out.
    if (update.hasGoodQualityMotionEvidence) {
      _consumeGpsMotionEvidence(update);
    }

    if (update.isAnchorEstablished) {
      _lastAcceptedRawPoint = point;
      _persistRawPoints([point]);
      return;
    }
    if (!update.isAccepted) return;

    _lastAcceptedRawPoint = update.point;
    distanceKm.value = _distanceAccumulator.totalDistanceMetres / 1000;
    _updateDisplayedPace(update.point);
    _persistRawPoints(update.creditedPoints);
    _maybeSpeakProgressCue();
  }

  void _consumeGpsMotionEvidence(GpsDistanceUpdate update) {
    final point = update.point;
    final speed = update.rawSegmentSpeedMetresPerSecond!;
    _debugGps(point, speed: speed, passed: true);
    final oldGpsState = _detector.currentState;
    _detector.addSpeedSample(speed, point.timestamp);
    _movementSegmentRecorder.addSpeedSample(speed);
    _applyFusionDecision(
      _motionFusion.addGpsSpeed(
        speedMetresPerSecond: speed,
        isGoodQuality: true,
        timestamp: point.timestamp,
      ),
      point.timestamp,
    );
    if (kDebugMode && oldGpsState != _detector.currentState) {
      _debugLog(
        '[WalkRun] gps-observed $oldGpsState->${_detector.currentState} '
        'speed=${speed.toStringAsFixed(2)}m/s '
        '${_fusionDebugSummary()}',
      );
    }
  }

  /// EMA deliberately affects only the pace shown live. Canonical distance is
  /// accumulated above from raw, quality-filtered GPS segments.
  void _updateDisplayedPace(GpsPoint rawPoint) {
    final point = _emaSmoothedPoint(rawPoint);
    final previous = _lastSmoothedPoint;
    if (previous != null) {
      final seconds =
          point.timestamp.difference(previous.timestamp).inMilliseconds /
              Duration.millisecondsPerSecond;
      if (seconds > 0) {
        final speed = _haversineMetres(previous, point) / seconds;
        if (speed <= _maxValidSpeedMetresPerSecond) {
          currentPaceSecPerKm.value = speed <= 0 ? 0 : 1000 / speed;
        }
      }
    }
    _lastSmoothedPoint = point;
  }

  void _persistRawPoints(List<GpsPoint> points) {
    for (final point in points) {
      if (_lastPersistedPoint == null ||
          point.timestamp.difference(_lastPersistedPoint!.timestamp) >=
              _sampleInterval) {
        _sampledPoints.add(point);
        _lastPersistedPoint = point;
      }
    }
  }

  GpsPoint _emaSmoothedPoint(GpsPoint rawPoint) {
    final previous = _lastSmoothedPoint;
    if (previous == null) return rawPoint;
    return GpsPoint(
      latitude:
          _emaAlpha * rawPoint.latitude + (1 - _emaAlpha) * previous.latitude,
      longitude:
          _emaAlpha * rawPoint.longitude + (1 - _emaAlpha) * previous.longitude,
      timestamp: rawPoint.timestamp,
      accuracy: rawPoint.accuracy,
    );
  }

  Future<void> _startStepCadenceDetection() async {
    if (Platform.isAndroid) {
      var permission = await Permission.activityRecognition.status;
      if (!permission.isGranted) {
        Get.snackbar(
          'Step detection',
          'Allow Physical activity so PET Coach can distinguish steps from GPS drift.',
        );
        permission = await Permission.activityRecognition.request();
      }
      if (!permission.isGranted) {
        _activateGpsFallback(
            'Activity recognition permission was not granted.');
        return;
      }
    }

    isStepSensorAvailable.value = true;
    _motionFusion.setCadenceSensorAvailable(true, DateTime.now());
    await _stepCadenceDetector.start(
      onReading: _onStepCadenceReading,
      onUnavailable: _activateGpsFallback,
    );
  }

  void _injectSyntheticStepCount(int cumulativeSteps, DateTime timestamp) {
    if (!kDebugMode) return;
    _stepCadenceDetector.ingestStepCount(cumulativeSteps, timestamp);
    _onStepCadenceReading(_stepCadenceDetector.refreshAt(timestamp), timestamp);
  }

  void _onStepCadenceReading(
    StepCadenceReading reading, [
    DateTime? readingTimestamp,
  ]) {
    _lastCadenceReading = reading;
    stepCadenceSpm.value = reading.cadenceSpm;
    isStepSensorAvailable.value = reading.isSensorAvailable;
    final timestamp = readingTimestamp ?? DateTime.now();
    final fusionDecision = _motionFusion.addCadenceReading(reading, timestamp);
    if (kDebugMode) {
      if (fusionDecision.runningVetoed || reading.runningTransitionVetoed) {
        _debugLog('[WalkRun] cadence-running VETOED '
            'cadence=${reading.cadenceSpm.toStringAsFixed(1)}spm '
            'confirmed=${reading.confirmationCount}/${reading.transitionConfirmationsRequired} '
            'gpsSlowStreak=${fusionDecision.gpsSlowStreak}/${_motionFusion.requiredGpsEvidenceSamples} '
            'reason=${fusionDecision.source}');
      } else if (reading.transitioned) {
        _debugLog('[WalkRun] cadence confirmed ${reading.confirmationCount}/'
            '${reading.transitionConfirmationsRequired} '
            '${reading.classification} cadence=${reading.cadenceSpm.toStringAsFixed(1)}spm '
            '${_fusionDebugSummary()}');
      } else if (reading.hasPendingTransition) {
        _debugLog(
            '[WalkRun] pending ${reading.pendingClassification}, confirmed '
            '${reading.pendingConfirmations}/${reading.transitionConfirmationsRequired} '
            'cadence=${reading.cadenceSpm.toStringAsFixed(1)}spm '
            'gpsState=${_detector.currentState} ${_fusionDebugSummary()}');
      }
    }
    _applyFusionDecision(fusionDecision, timestamp);
  }

  void _activateGpsFallback(Object reason) {
    isStepSensorAvailable.value = false;
    stepCadenceSpm.value = 0;
    _applyFusionDecision(
      _motionFusion.setCadenceSensorAvailable(false, DateTime.now()),
      DateTime.now(),
    );
    if (kDebugMode) {
      _debugLog('[StepCadence] unavailable; GPS fallback enabled: $reason');
    }
  }

  void _applyFusionDecision(
    MotionFusionDecision decision,
    DateTime timestamp,
  ) {
    if (!decision.transitioned) return;
    _setMovementState(
      decision.state,
      timestamp,
      trigger: decision.source,
    );
  }

  void _setMovementState(
    String state,
    DateTime timestamp, {
    required String trigger,
  }) {
    final oldState = movementState.value;
    if (oldState == state) return;
    _movementSegmentRecorder.transitionTo(state: state, at: timestamp);
    movementState.value = state;
    if (kDebugMode && oldState != state) {
      _debugLog('[WalkRun] transition at ${timestamp.toIso8601String()} '
          'trigger=$trigger ${_cadenceDebugSummary(timestamp)} '
          'gpsAvg=${_detector.rollingAverageSpeed?.toStringAsFixed(2) ?? 'n/a'}m/s '
          'gpsState=${_detector.currentState} $oldState->$state');
    }
  }

  String _cadenceDebugSummary(DateTime timestamp) {
    final reading =
        _lastCadenceReading ?? _stepCadenceDetector.readingAt(timestamp);
    final pending = reading.pendingClassification ?? 'none';
    return 'cadence=${stepCadenceSpm.value.toStringAsFixed(1)}spm '
        'cadenceState=${reading.classification} rawCadenceState=${reading.rawClassification} '
        'pending=$pending confirmed=${reading.confirmationCount}/${reading.transitionConfirmationsRequired} '
        'vetoed=${reading.runningTransitionVetoed}';
  }

  String _fusionDebugSummary() => 'fusion=${_motionFusion.currentState} '
      'gpsRun=${_motionFusion.gpsRunningStreak}/${_motionFusion.requiredGpsEvidenceSamples} '
      'gpsSlow=${_motionFusion.gpsSlowStreak}/${_motionFusion.requiredGpsEvidenceSamples} '
      'cadenceLow=${_motionFusion.cadenceLowStreak}/${_motionFusion.requiredCadenceLowSamples}';

  void toggleVoice() {
    isVoiceEnabled.value = !isVoiceEnabled.value;
    if (!isVoiceEnabled.value) unawaited(_stopSpeaking());
  }

  void _maybeSpeakProgressCue() {
    if (!isVoiceEnabled.value ||
        isPaused.value ||
        distanceKm.value < _nextVoiceCueAtKm) {
      return;
    }
    _nextVoiceCueAtKm += _voiceCueIntervalKm;
    if (kDebugMode) {
      _debugLog('[VoiceCue] triggered=${DateTime.now().toIso8601String()} '
          'distance=${distanceKm.value.toStringAsFixed(3)}km '
          'pace=${currentPaceSecPerKm.value.toStringAsFixed(1)}s/km');
    }
    unawaited(_speakProgressCue());
  }

  Future<void> _configureTts() async {
    try {
      await _tts.setLanguage('en-IN');
      await _tts.setSpeechRate(.48);
      await _tts.awaitSpeakCompletion(true);
    } catch (_) {
      // Voice coaching is optional; tracking remains available without TTS.
    }
  }

  Future<void> _speakProgressCue() async {
    if (!isVoiceEnabled.value || _isSpeaking || !isTracking.value) return;
    _isSpeaking = true;
    try {
      final distance = distanceKm.value;
      final distanceText = distance < 1
          ? '${(distance * 1000).round()} meters'
          : '${distance.toStringAsFixed(1)} kilometers';
      final pace = currentPaceSecPerKm.value;
      final paceText = pace <= 0
          ? 'pace not available yet'
          : '${pace ~/ 60} minutes ${(pace % 60).round()} seconds';
      final state = movementState.value;
      final encouragement =
          state == 'running' ? 'Keep running.' : 'Ease into a run when ready.';
      await _tts.speak(
        '$distanceText in. $paceText per kilometer. You are $state. $encouragement',
      );
    } catch (_) {
      // An unavailable voice engine must never interrupt location tracking.
    } finally {
      _isSpeaking = false;
    }
  }

  Future<void> _stopSpeaking() async {
    _isSpeaking = false;
    try {
      await _tts.stop();
    } catch (_) {
      // TTS may not be available on a particular device.
    }
  }

  static double _haversineMetres(GpsPoint first, GpsPoint second) {
    const radius = 6371000.0;
    final latDelta = _radians(second.latitude - first.latitude);
    final lonDelta = _radians(second.longitude - first.longitude);
    final a = math.sin(latDelta / 2) * math.sin(latDelta / 2) +
        math.cos(_radians(first.latitude)) *
            math.cos(_radians(second.latitude)) *
            math.sin(lonDelta / 2) *
            math.sin(lonDelta / 2);
    return radius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double _radians(double degrees) => degrees * math.pi / 180;

  void _startElapsedTimer() {
    _elapsedTimer?.cancel();
    _elapsedTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => elapsed.value = _stopwatch.elapsed,
    );
  }

  void _startDebugBatterySampling() {
    if (!kDebugMode) return;
    _batteryTimer?.cancel();
    unawaited(_sampleDebugBattery());
    _batteryTimer = Timer.periodic(_batterySampleInterval, (_) {
      unawaited(_sampleDebugBattery());
    });
  }

  Future<void> _sampleDebugBattery() async {
    if (!kDebugMode || !isTracking.value || isPaused.value) return;
    try {
      final level = await Battery().batteryLevel;
      debugBatteryPercent.value = level;
      _debugLog('[Battery] elapsed=${elapsed.value.inMinutes}m '
          'level=$level%');
    } catch (_) {
      _debugLog('[Battery] unavailable');
    }
  }

  void _debugGps(GpsPoint point,
      {required double? speed, required bool passed}) {
    if (!kDebugMode) return;
    final accuracy = point.accuracy;
    final weak = accuracy != null && accuracy > 20;
    _debugLog(
        '[GPS${weak ? ' WEAK' : ''}] lat=${point.latitude.toStringAsFixed(6)} '
        'lng=${point.longitude.toStringAsFixed(6)} accuracy=${accuracy?.toStringAsFixed(1) ?? 'n/a'}m '
        'speed=${speed?.toStringAsFixed(2) ?? 'n/a'}m/s '
        'jump=${passed ? 'pass' : 'rejected'}');
  }

  void _debugGpsDistanceUpdate(GpsDistanceUpdate update) {
    if (!kDebugMode) return;
    final status = switch (update.kind) {
      GpsDistanceUpdateKind.waitingForWarmUp => 'waiting-for-warmup',
      GpsDistanceUpdateKind.anchorEstablished => 'anchor-established',
      GpsDistanceUpdateKind.buffered => 'buffered',
      GpsDistanceUpdateKind.accepted => 'accepted',
      GpsDistanceUpdateKind.rejectedJump => 'rejected-jump',
      GpsDistanceUpdateKind.ignored => 'ignored',
    };
    _debugLog(
        '[GPS FILTER] rawSegment=${update.rawSegmentDistanceMetres.toStringAsFixed(2)}m '
        'accuracy=${update.point.accuracy?.toStringAsFixed(2) ?? 'n/a'}m '
        'pending=${update.pendingCount}/${update.requiredConfirmations} '
        'credited=${update.creditedDistanceMetres.toStringAsFixed(2)}m '
        'status=$status');
  }

  void _debugLog(String message) {
    if (!kDebugMode) return;
    debugPrint(message);
    unawaited(_fieldTestLog.append(message));
  }

  @override
  void onClose() {
    _positionSubscription?.cancel();
    _elapsedTimer?.cancel();
    _batteryTimer?.cancel();
    unawaited(_stepCadenceDetector.stop());
    unawaited(_stopSpeaking());
    super.onClose();
  }
}
