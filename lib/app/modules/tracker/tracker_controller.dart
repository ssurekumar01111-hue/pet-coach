import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../data/models/exam_config.dart';
import '../../data/models/gps_point.dart';
import '../../data/models/run_session.dart';
import '../../data/repositories/firestore_repository.dart';
import 'walk_run_detector.dart';

class TrackerController extends GetxController {
  TrackerController({
    FirestoreRepository? repository,
    FirebaseAuth? auth,
  })  : _repository = repository ?? FirestoreRepository(),
        _auth = auth ?? FirebaseAuth.instance;

  static const _sampleInterval = Duration(seconds: 3);
  static const _maxValidSpeedMetresPerSecond = 12.0;

  final FirestoreRepository _repository;
  final FirebaseAuth _auth;
  final isTracking = false.obs;
  final isPaused = false.obs;
  final elapsed = Duration.zero.obs;
  final distanceKm = 0.0.obs;
  final currentPaceSecPerKm = 0.0.obs;
  final movementState = 'walking'.obs;
  final gpsJumpCount = 0.obs;
  final errorMessage = RxnString();

  final List<GpsPoint> _sampledPoints = [];
  final WalkRunDetector _detector = WalkRunDetector();
  final Stopwatch _stopwatch = Stopwatch();
  StreamSubscription<Position>? _positionSubscription;
  Timer? _elapsedTimer;
  GpsPoint? _lastValidRawPoint;
  GpsPoint? _lastPersistedPoint;
  DateTime? _sessionStart;
  String? _sessionId;

  Future<void> start() async {
    if (isTracking.value && !isPaused.value) return;
    errorMessage.value = null;
    if (!await _ensureLocationPermission()) return;

    if (isPaused.value) {
      isPaused.value = false;
      _stopwatch.start();
    } else {
      _detector.reset();
      _sampledPoints.clear();
      _lastValidRawPoint = null;
      _lastPersistedPoint = null;
      _sessionStart = DateTime.now();
      _sessionId = FirebaseFirestore.instance.collection('sessions').doc().id;
      distanceKm.value = 0;
      currentPaceSecPerKm.value = 0;
      gpsJumpCount.value = 0;
      _stopwatch
        ..reset()
        ..start();
      isTracking.value = true;
    }
    _startElapsedTimer();
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
    _elapsedTimer?.cancel();
    await _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  Future<void> stop() async {
    if (!isTracking.value) return;
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    _elapsedTimer?.cancel();
    _stopwatch.stop();
    final endTime = DateTime.now();
    _detector.finish(endTime);
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
        segments: _detector.segments,
        totalDistanceKm: distanceKm.value,
        totalTimeSec: _stopwatch.elapsed.inSeconds,
      );
      await _repository.createSession(session);
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
    final previous = _lastValidRawPoint;
    if (previous != null) {
      final seconds =
          point.timestamp.difference(previous.timestamp).inMilliseconds /
              Duration.millisecondsPerSecond;
      if (seconds <= 0) return;
      final speed = _haversineMetres(previous, point) / seconds;
      if (speed > _maxValidSpeedMetresPerSecond) {
        gpsJumpCount.value++;
        return;
      }
      currentPaceSecPerKm.value = speed <= 0 ? 0 : 1000 / speed;
      _detector.addSpeedSample(speed, point.timestamp);
      movementState.value = _detector.currentState;
    }
    _lastValidRawPoint = point;
    if (_lastPersistedPoint == null ||
        point.timestamp.difference(_lastPersistedPoint!.timestamp) >=
            _sampleInterval) {
      _sampledPoints.add(point);
      _lastPersistedPoint = point;
      distanceKm.value = _distanceFromSampledPoints();
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

  @override
  void onClose() {
    _positionSubscription?.cancel();
    _elapsedTimer?.cancel();
    super.onClose();
  }
}
