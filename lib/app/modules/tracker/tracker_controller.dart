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
import 'gps_movement_filter.dart';
import 'movement_segment_recorder.dart';
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
  static const _minimumGpsSpeedForRunningMetresPerSecond = 1.9;

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

  final List<GpsPoint> _sampledPoints = [];
  final WalkRunDetector _detector = WalkRunDetector();
  final MovementSegmentRecorder _movementSegmentRecorder =
      MovementSegmentRecorder();
  final StepCadenceDetector _stepCadenceDetector = StepCadenceDetector();
  final Stopwatch _stopwatch = Stopwatch();
  StreamSubscription<Position>? _positionSubscription;
  Timer? _elapsedTimer;
  Timer? _batteryTimer;
  GpsPoint? _lastObservedRawPoint;
  GpsPoint? _lastSmoothedPoint;
  GpsPoint? _lastValidRawPoint;
  GpsPoint? _lastPersistedPoint;
  DateTime? _sessionStart;
  String? _sessionId;
  double _nextVoiceCueAtKm = _voiceCueIntervalKm;
  bool _isSpeaking = false;
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
      isPaused.value = false;
      _stopwatch.start();
      _movementSegmentRecorder.resume(DateTime.now());
    } else {
      _detector.reset();
      _sampledPoints.clear();
      _lastObservedRawPoint = null;
      _lastSmoothedPoint = null;
      _lastValidRawPoint = null;
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

  Future<void> pause() async {
    if (!isTracking.value || isPaused.value) return;
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
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    _elapsedTimer?.cancel();
    _batteryTimer?.cancel();
    await _stepCadenceDetector.stop();
    _stopwatch.stop();
    await _stopSpeaking();
    final endTime = DateTime.now();
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
    final previousObserved = _lastObservedRawPoint;
    _lastObservedRawPoint = point;
    if (previousObserved == null) {
      _debugGpsFilter(
        rawDistanceMetres: 0,
        accuracyMetres: point.accuracy,
        passed: true,
        isInitialPoint: true,
      );
      _acceptMovementPoint(point);
      return;
    }

    final rawDistance =
        GpsMovementFilter.haversineMetres(previousObserved, point);
    final movement = GpsMovementFilter.evaluate(
      rawDistanceMetres: rawDistance,
      currentAccuracyMetres: point.accuracy,
    );
    _debugGpsFilter(
      rawDistanceMetres: movement.rawDistanceMetres,
      accuracyMetres: movement.accuracyMetres,
      passed: movement.countsAsMovement,
      requiredDisplacementMetres: movement.requiredDisplacementMetres,
    );
    if (!movement.countsAsMovement) return;

    _acceptMovementPoint(point);
  }

  void _acceptMovementPoint(GpsPoint rawPoint) {
    final point = _emaSmoothedPoint(rawPoint);
    final previous = _lastValidRawPoint;
    if (previous != null) {
      final seconds =
          point.timestamp.difference(previous.timestamp).inMilliseconds /
              Duration.millisecondsPerSecond;
      if (seconds <= 0) return;
      final speed = _haversineMetres(previous, point) / seconds;
      if (speed > _maxValidSpeedMetresPerSecond) {
        _debugGps(point, speed: speed, passed: false);
        gpsJumpCount.value++;
        return;
      }
      _debugGps(point, speed: speed, passed: true);
      currentPaceSecPerKm.value = speed <= 0 ? 0 : 1000 / speed;
      final oldGpsState = _detector.currentState;
      _detector.addSpeedSample(speed, point.timestamp);
      final gpsState = _detector.currentState;
      if (!isStepSensorAvailable.value) {
        _setMovementState(gpsState, point.timestamp, trigger: 'gps-fallback');
      }
      _movementSegmentRecorder.addSpeedSample(speed);
      if (kDebugMode && oldGpsState != gpsState) {
        _debugLog(
            '[WalkRun] transition at ${point.timestamp.toIso8601String()} '
            'trigger=gps ${_cadenceDebugSummary(point.timestamp)} '
            'gpsAvg=${_detector.rollingAverageSpeed?.toStringAsFixed(2) ?? 'n/a'}m/s '
            'gpsState=$oldGpsState->$gpsState '
            'primaryState=${movementState.value}');
      }
    } else {
      _debugGps(point, speed: null, passed: true);
    }
    _lastSmoothedPoint = point;
    _lastValidRawPoint = point;
    if (_lastPersistedPoint == null ||
        point.timestamp.difference(_lastPersistedPoint!.timestamp) >=
            _sampleInterval) {
      _sampledPoints.add(point);
      _lastPersistedPoint = point;
      distanceKm.value = _distanceFromSampledPoints();
      _maybeSpeakProgressCue();
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
    _stepCadenceDetector.setTransitionGuard(_canCommitCadenceTransition);
    await _stepCadenceDetector.start(
      onReading: _onStepCadenceReading,
      onUnavailable: _activateGpsFallback,
    );
  }

  void _onStepCadenceReading(StepCadenceReading reading) {
    _lastCadenceReading = reading;
    stepCadenceSpm.value = reading.cadenceSpm;
    isStepSensorAvailable.value = reading.isSensorAvailable;
    if (kDebugMode) {
      if (reading.runningTransitionVetoed) {
        final gpsAverage = _detector.rollingAverageSpeed;
        _debugLog('[WalkRun] cadence-running VETOED '
            'cadence=${reading.cadenceSpm.toStringAsFixed(1)}spm '
            'confirmed=${reading.confirmationCount}/${reading.transitionConfirmationsRequired} '
            'gpsAvg=${gpsAverage?.toStringAsFixed(2) ?? 'n/a'}m/s '
            'required>=${_minimumGpsSpeedForRunningMetresPerSecond.toStringAsFixed(1)}m/s');
      } else if (reading.transitioned) {
        _debugLog('[WalkRun] cadence confirmed ${reading.confirmationCount}/'
            '${reading.transitionConfirmationsRequired} '
            '${reading.classification} '
            'cadence=${reading.cadenceSpm.toStringAsFixed(1)}spm');
      } else if (reading.hasPendingTransition) {
        _debugLog(
            '[WalkRun] pending ${reading.pendingClassification}, confirmed '
            '${reading.pendingConfirmations}/${reading.transitionConfirmationsRequired} '
            'cadence=${reading.cadenceSpm.toStringAsFixed(1)}spm '
            'gpsState=${_detector.currentState}');
      }
    }
    if (reading.isSensorAvailable) {
      _setMovementState(
        reading.classification,
        DateTime.now(),
        trigger: 'cadence',
      );
    }
  }

  /// Cadence remains authoritative for walking and stationary transitions.
  /// GPS only vetoes a cadence-led transition *to* running when its rolling
  /// speed still clearly indicates walking-level movement.
  bool _canCommitCadenceTransition(StepCadenceTransition transition) {
    if (transition.to != 'running') return true;
    final gpsAverage = _detector.rollingAverageSpeed;
    return gpsAverage != null &&
        gpsAverage >= _minimumGpsSpeedForRunningMetresPerSecond;
  }

  void _activateGpsFallback(Object reason) {
    isStepSensorAvailable.value = false;
    stepCadenceSpm.value = 0;
    _setMovementState(
      _detector.currentState,
      DateTime.now(),
      trigger: 'gps-fallback',
    );
    if (kDebugMode) {
      _debugLog('[StepCadence] unavailable; GPS fallback enabled: $reason');
    }
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

  double _distanceFromSampledPoints() {
    var metres = 0.0;
    for (var index = 1; index < _sampledPoints.length; index++) {
      metres +=
          _haversineMetres(_sampledPoints[index - 1], _sampledPoints[index]);
    }
    return metres / 1000;
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

  void _debugGpsFilter({
    required double rawDistanceMetres,
    required double? accuracyMetres,
    required bool passed,
    double? requiredDisplacementMetres,
    bool isInitialPoint = false,
  }) {
    if (!kDebugMode) return;
    _debugLog(
        '[GPS FILTER] rawDistance=${rawDistanceMetres.toStringAsFixed(2)}m '
        'accuracy=${accuracyMetres?.toStringAsFixed(2) ?? 'n/a'}m '
        'threshold=${requiredDisplacementMetres?.toStringAsFixed(2) ?? 'n/a'}m '
        '${isInitialPoint ? 'initial' : (passed ? 'passed' : 'filtered-noise')}');
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
