import '../../data/models/run_segment.dart';

/// Deterministic state machine for smoothing GPS-derived speeds.
class WalkRunDetector {
  WalkRunDetector({this.windowSize = 5, this.transitionSamples = 3});

  final int windowSize;
  final int transitionSamples;
  final List<double> _speeds = [];
  String? _state;
  String? _candidateState;
  var _candidateCount = 0;
  DateTime? _segmentStart;
  final List<double> _segmentSpeeds = [];
  final List<RunSegment> _segments = [];

  String get currentState => _state ?? 'walking';
  double? get rollingAverageSpeed => _speeds.isEmpty
      ? null
      : _speeds.reduce((sum, value) => sum + value) / _speeds.length;
  List<RunSegment> get segments => List.unmodifiable(_segments);

  void reset() {
    _speeds.clear();
    _state = null;
    _candidateState = null;
    _candidateCount = 0;
    _segmentStart = null;
    _segmentSpeeds.clear();
    _segments.clear();
  }

  RunSegment? addSpeedSample(double speedMetresPerSecond, DateTime timestamp) {
    _speeds.add(speedMetresPerSecond);
    if (_speeds.length > windowSize) _speeds.removeAt(0);
    final average =
        _speeds.reduce((sum, value) => sum + value) / _speeds.length;
    final classification = average > 2.2 ? 'running' : 'walking';

    if (_state == null) {
      _state = classification;
      _segmentStart = timestamp;
      _segmentSpeeds.add(speedMetresPerSecond);
      return null;
    }
    _segmentSpeeds.add(speedMetresPerSecond);
    if (classification == _state) {
      _candidateState = null;
      _candidateCount = 0;
      return null;
    }
    if (classification == _candidateState) {
      _candidateCount++;
    } else {
      _candidateState = classification;
      _candidateCount = 1;
    }
    if (_candidateCount < transitionSamples) return null;

    final closed = _closeSegment(timestamp);
    _state = classification;
    _segmentStart = timestamp;
    _segmentSpeeds
      ..clear()
      ..add(speedMetresPerSecond);
    _candidateState = null;
    _candidateCount = 0;
    _segments.add(closed);
    return closed;
  }

  RunSegment? finish(DateTime timestamp) {
    if (_state == null || _segmentStart == null) return null;
    final segment = _closeSegment(timestamp);
    _segments.add(segment);
    _segmentStart = null;
    return segment;
  }

  RunSegment _closeSegment(DateTime endTime) {
    final averageSpeed = _segmentSpeeds.isEmpty
        ? 0.0
        : _segmentSpeeds.reduce((sum, value) => sum + value) /
            _segmentSpeeds.length;
    final duration = endTime.difference(_segmentStart!).inSeconds;
    final distanceKm = averageSpeed * duration / 1000;
    return RunSegment(
      type: _state!,
      startTime: _segmentStart!,
      endTime: endTime,
      distanceKm: distanceKm,
      avgPaceSecPerKm: averageSpeed <= 0 ? 0 : 1000 / averageSpeed,
    );
  }
}
