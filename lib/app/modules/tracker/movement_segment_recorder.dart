import '../../data/models/run_segment.dart';

/// Records the same fused movement state displayed by [TrackerController].
///
/// GPS samples are used only to estimate pace/distance within a segment; state
/// boundaries are supplied by the cadence-primary, GPS-vetoed classifier. A
/// Pauses do not split a matching state into duplicate segments. Their time is
/// recorded separately and excluded from each segment's active duration.
class MovementSegmentRecorder {
  final List<RunSegment> _segments = [];
  final List<double> _currentSpeedSamples = [];

  String? _currentState;
  DateTime? _currentStartTime;
  DateTime? _pausedAt;
  var _pausedDuration = Duration.zero;

  List<RunSegment> get segments => List.unmodifiable(_segments);

  void reset() {
    _segments.clear();
    _currentSpeedSamples.clear();
    _currentState = null;
    _currentStartTime = null;
    _pausedAt = null;
    _pausedDuration = Duration.zero;
  }

  void begin({required String state, required DateTime at}) {
    reset();
    _currentState = state;
    _currentStartTime = at;
  }

  void transitionTo({required String state, required DateTime at}) {
    if (_currentState == null) {
      begin(state: state, at: at);
      return;
    }
    // A repeated reading confirms the existing state. Keep its segment open;
    // it will receive the latest end time only when a real state change or
    // session finish occurs.
    if (_currentState == state) return;

    _closeCurrentSegment(at);
    _currentState = state;
    _currentStartTime = at;
    _pausedAt = null;
    _pausedDuration = Duration.zero;
    _currentSpeedSamples.clear();
  }

  void addSpeedSample(double metresPerSecond) {
    if (_currentStartTime == null ||
        _pausedAt != null ||
        !metresPerSecond.isFinite ||
        metresPerSecond < 0) {
      return;
    }
    _currentSpeedSamples.add(metresPerSecond);
  }

  void pause(DateTime at) {
    if (_currentStartTime == null ||
        _pausedAt != null ||
        at.isBefore(_currentStartTime!)) {
      return;
    }
    _pausedAt = at;
  }

  void resume(DateTime at) {
    final pausedAt = _pausedAt;
    if (pausedAt != null && !at.isBefore(pausedAt)) {
      _pausedDuration += at.difference(pausedAt);
      _pausedAt = null;
    }
  }

  List<RunSegment> finish(DateTime at) {
    _closeCurrentSegment(at);
    _currentStartTime = null;
    _pausedAt = null;
    _pausedDuration = Duration.zero;
    return segments;
  }

  void _closeCurrentSegment(DateTime endTime) {
    final state = _currentState;
    final startTime = _currentStartTime;
    if (state == null || startTime == null || endTime.isBefore(startTime)) {
      return;
    }

    var pausedDuration = _pausedDuration;
    final pausedAt = _pausedAt;
    if (pausedAt != null && !endTime.isBefore(pausedAt)) {
      pausedDuration += endTime.difference(pausedAt);
    }
    final activeDurationSeconds =
        (endTime.difference(startTime).inMilliseconds -
                    pausedDuration.inMilliseconds)
                .clamp(0, endTime.difference(startTime).inMilliseconds) /
            Duration.millisecondsPerSecond;
    final averageSpeed = _currentSpeedSamples.isEmpty
        ? 0.0
        : _currentSpeedSamples.reduce((sum, speed) => sum + speed) /
            _currentSpeedSamples.length;
    final distanceKm = averageSpeed * activeDurationSeconds / 1000;
    final paceSecPerKm = averageSpeed <= 0 ? 0.0 : 1000 / averageSpeed;
    _segments.add(
      RunSegment(
        type: state,
        startTime: startTime,
        endTime: endTime,
        distanceKm: distanceKm,
        avgPaceSecPerKm: paceSecPerKm,
        activeDurationSec: activeDurationSeconds,
      ),
    );
    _currentSpeedSamples.clear();
    _pausedAt = null;
    _pausedDuration = Duration.zero;
  }
}
