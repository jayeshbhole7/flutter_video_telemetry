// ignore_for_file: avoid_print
import 'dart:async';

import 'package:video_player/video_player.dart';

import 'models/playback_error_event.dart';
import 'models/segment_switch_event.dart';
import 'models/stall_event.dart';
import 'models/telemetry_snapshot.dart';
import 'telemetry_config.dart';
import 'utils/ring_buffer.dart';

/// wraps a [VideoPlayerController] and tracks playback metrics.
///
/// ```dart
/// final telemetry = VideoTelemetry.wrap(controller);
/// // player still does its thing
/// telemetry.dispose(); // clean it up in dispose()
/// ```
class VideoTelemetry {
  VideoTelemetry._(
    VideoPlayerController controller, {
    required TelemetryConfig config,
  }) : _controller = controller,
       _config = config {
    _attach();
  }

  final VideoPlayerController _controller;
  final TelemetryConfig _config;

  bool _disposed = false;
  VideoPlayerValue? _lastValue;

  // phase 6 - ttff
  bool _wrappedWhilePlaying = false;
  bool _hasFirstFrame = false;
  DateTime? _playStartedAt;
  DateTime? _firstFrameAt;

  // phase 7 - stall bits
  bool _isStalling = false;
  DateTime? _stallStartedAt;
  int _stallCount = 0;
  Duration _totalStallDuration = Duration.zero;

  // phase 8 - seek bits
  bool _isSeekBuffering = false;
  int _seekCount = 0;

  // phase 9 - active play window
  Duration _activePlayDuration = Duration.zero;
  DateTime? _activePlayWindowStart;

  // phase 11 - manual segment switches
  int _segmentSwitchCount = 0;

  Timer? _pollTimer;
  Timer? _snapshotTimer;

  // bounded history so long sessions don't balloon.
  late final RingBuffer<StallEvent> _stallHistory = RingBuffer(
    _config.stallHistoryCapacity,
  );
  late final RingBuffer<SegmentSwitchEvent> _segmentHistory = RingBuffer(
    _config.segmentSwitchHistoryCapacity,
  );

  // broadcast streams; more than one listener is fine.
  final _stallSC = StreamController<StallEvent>.broadcast();
  final _ttffSC = StreamController<Duration>.broadcast();
  final _segmentSC = StreamController<SegmentSwitchEvent>.broadcast();
  final _errorSC = StreamController<PlaybackErrorEvent>.broadcast();
  final _snapshotSC = StreamController<TelemetrySnapshot>.broadcast();

  // factory

  /// wraps [controller] with telemetry.
  static VideoTelemetry wrap(
    VideoPlayerController controller, {
    TelemetryConfig config = const TelemetryConfig(),
  }) {
    return VideoTelemetry._(controller, config: config);
  }

  // lifecycle

  void _attach() {
    _lastValue = _controller.value;

    if (_controller.value.isPlaying) {
      _wrappedWhilePlaying = true;
      _playStartedAt = DateTime.now();
      if (_controller.value.isInitialized && !_controller.value.isBuffering) {
        _activePlayWindowStart = DateTime.now();
      }
      _debugLog('wrapped while playing - TTFF unavailable');
    }

    _controller.addListener(_onValueChanged);

    _pollTimer = Timer.periodic(_config.pollingInterval, (_) {
      if (_disposed) return;
      final current = _controller.value;
      if (!identical(current, _lastValue)) {
        _processValue(current);
      }
    });

    if (_config.snapshotInterval != null) {
      _snapshotTimer = Timer.periodic(_config.snapshotInterval!, (_) {
        if (_disposed) return;
        _emit(_snapshotSC, snapshot);
      });
    }
  }

  void _onValueChanged() {
    if (_disposed) return;
    _processValue(_controller.value);
  }

  void _processValue(VideoPlayerValue current) {
    final previous = _lastValue;
    _lastValue = current;
    if (previous == null) return;

    // error detection
    if (current.hasError && !previous.hasError) {
      final event = PlaybackErrorEvent(
        timestamp: DateTime.now(),
        position: current.position,
        errorDescription: current.errorDescription,
      );
      _emit(_errorSC, event);
      _debugLog('error: ${current.errorDescription}');
    }

    if (!current.isInitialized) return;

    // first play timestamp
    if (current.isPlaying && !previous.isPlaying && _playStartedAt == null) {
      _playStartedAt = DateTime.now();
      _debugLog('first play() detected');
    }

    // ttff
    if (!_hasFirstFrame &&
        !_wrappedWhilePlaying &&
        _playStartedAt != null &&
        current.isPlaying &&
        current.position > Duration.zero &&
        !current.isBuffering) {
      _hasFirstFrame = true;
      _firstFrameAt = DateTime.now();
      final ttff = _firstFrameAt!.difference(_playStartedAt!);
      _emit(_ttffSC, ttff);
      _debugLog('TTFF: ${ttff.inMilliseconds}ms');
    }

    // active play window
    final wasActive = previous.isPlaying && !previous.isBuffering;
    final isActive = current.isPlaying && !current.isBuffering;

    if (wasActive && !isActive) {
      if (_activePlayWindowStart != null) {
        _activePlayDuration += DateTime.now().difference(
          _activePlayWindowStart!,
        );
        _activePlayWindowStart = null;
      }
    } else if (!wasActive && isActive) {
      _activePlayWindowStart = DateTime.now();
    }

    // seek detection
    final positionDelta = current.position - previous.position;
    final absPositionDelta = Duration(
      microseconds: positionDelta.inMicroseconds.abs(),
    );
    final maxNormalDelta = Duration(
      microseconds:
          (_config.pollingInterval.inMicroseconds * current.playbackSpeed * 5)
              .round(),
    );
    final isLoopReset = _detectLoopReset(previous, current);
    final isSeek =
        !isLoopReset &&
        absPositionDelta > maxNormalDelta &&
        absPositionDelta > _config.seekJumpThreshold;

    if (isSeek) {
      _seekCount++;
      _isSeekBuffering = true;
      if (_isStalling) {
        _isStalling = false;
        _stallStartedAt = null;
        _debugLog('seek mid-stall - stall cancelled');
      }
      _debugLog(
        'seek: ${previous.position.inMilliseconds}ms -> '
        '${current.position.inMilliseconds}ms',
      );
    }

    if (_isSeekBuffering && !current.isBuffering) {
      _isSeekBuffering = false;
      _debugLog('seek buffering resolved');
    }

    // stall entry
    if (current.isPlaying &&
        current.isBuffering &&
        !_isStalling &&
        !_isSeekBuffering) {
      _isStalling = true;
      _stallStartedAt = DateTime.now();
      _debugLog('stall started at ${current.position.inMilliseconds}ms');
    }

    // stall exit
    if (_isStalling && !current.isBuffering) {
      final duration = DateTime.now().difference(_stallStartedAt!);
      _isStalling = false;
      _stallStartedAt = null;

      if (duration >= _config.minimumStallDuration) {
        _stallCount++;
        _totalStallDuration += duration;
        final event = StallEvent(
          timestamp: DateTime.now(),
          position: current.position,
          duration: duration,
          index: _stallCount,
        );
        _stallHistory.add(event);
        _emit(_stallSC, event);
        _debugLog('stall #$_stallCount ended: ${duration.inMilliseconds}ms');
      } else {
        _debugLog('micro-stall ignored: ${duration.inMilliseconds}ms');
      }
    }
  }

  /// detach and close streams; safe to call twice.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _pollTimer?.cancel();
    _snapshotTimer?.cancel();
    try {
      _controller.removeListener(_onValueChanged);
    } catch (_) {}
    _stallSC.close();
    _ttffSC.close();
    _segmentSC.close();
    _errorSC.close();
    _snapshotSC.close();
    _debugLog('disposed');
  }

  /// report a quality switch from the native player layer.
  void reportSegmentSwitch({
    int? fromBitrateKbps,
    int? toBitrateKbps,
    String? fromResolution,
    String? toResolution,
    String? reason,
  }) {
    if (_disposed) return;
    _segmentSwitchCount++;
    final event = SegmentSwitchEvent(
      timestamp: DateTime.now(),
      position: _safePosition,
      fromBitrateKbps: fromBitrateKbps,
      toBitrateKbps: toBitrateKbps,
      fromResolution: fromResolution,
      toResolution: toResolution,
      reason: reason,
      isEstimated: false,
    );
    _segmentHistory.add(event);
    _emit(_segmentSC, event);
  }

  void reset() {
    if (_disposed) return;
    _hasFirstFrame = false;
    _wrappedWhilePlaying = false;
    _isStalling = false;
    _isSeekBuffering = false;
    _stallCount = 0;
    _totalStallDuration = Duration.zero;
    _seekCount = 0;
    _segmentSwitchCount = 0;
    _activePlayDuration = Duration.zero;
    _activePlayWindowStart = null;
    _playStartedAt = null;
    _firstFrameAt = null;
    _stallStartedAt = null;
    _lastValue = _controller.value;
    _stallHistory.clear();
    _segmentHistory.clear();
    _debugLog('session reset');
  }

  // streams

  Stream<StallEvent> get stallStream => _stallSC.stream;
  Stream<Duration> get firstFrameStream => _ttffSC.stream;
  Stream<SegmentSwitchEvent> get segmentSwitchStream => _segmentSC.stream;
  Stream<PlaybackErrorEvent> get errorStream => _errorSC.stream;
  Stream<TelemetrySnapshot> get snapshotStream => _snapshotSC.stream;

  StreamSubscription<Duration> onFirstFrame(void Function(Duration) callback) {
    final sub = firstFrameStream.listen(callback);
    if (_hasFirstFrame && timeToFirstFrame != null) {
      final ttff = timeToFirstFrame!;
      Future.microtask(() {
        if (!_disposed) callback(ttff);
      });
    }
    return sub;
  }

  StreamSubscription<StallEvent> onStall(void Function(StallEvent) callback) =>
      stallStream.listen(callback);

  StreamSubscription<PlaybackErrorEvent> onError(
    void Function(PlaybackErrorEvent) callback,
  ) => errorStream.listen(callback);

  StreamSubscription<SegmentSwitchEvent> onSegmentSwitch(
    void Function(SegmentSwitchEvent) callback,
  ) => segmentSwitchStream.listen(callback);

  // metrics

  Duration? get timeToFirstFrame {
    if (!_hasFirstFrame || _playStartedAt == null || _firstFrameAt == null) {
      return null;
    }
    return _firstFrameAt!.difference(_playStartedAt!);
  }

  bool get ttffAvailable => !_wrappedWhilePlaying;
  int get stallCount => _stallCount;
  Duration get totalStallDuration => _totalStallDuration;
  double get rebufferingRatio {
    final active = _currentActivePlay;
    final total = active + _totalStallDuration;
    if (total == Duration.zero) return 0.0;
    return _totalStallDuration.inMicroseconds / total.inMicroseconds;
  }

  Duration get averageStallDuration {
    if (_stallCount == 0) return Duration.zero;
    return Duration(
      microseconds: _totalStallDuration.inMicroseconds ~/ _stallCount,
    );
  }

  int get seekCount => _seekCount;
  int get segmentSwitchCount => _segmentSwitchCount;
  bool get isCurrentlyStalling => _isStalling;
  List<StallEvent> get stallHistory => _stallHistory.toList();
  List<SegmentSwitchEvent> get segmentSwitchHistory => _segmentHistory.toList();

  Duration get _currentActivePlay {
    if (_activePlayWindowStart == null) return _activePlayDuration;
    return _activePlayDuration +
        DateTime.now().difference(_activePlayWindowStart!);
  }

  TelemetrySnapshot get snapshot => TelemetrySnapshot(
    capturedAt: DateTime.now(),
    timeToFirstFrame: timeToFirstFrame,
    stallCount: stallCount,
    totalStallDuration: totalStallDuration,
    rebufferingRatio: rebufferingRatio,
    averageStallDuration: averageStallDuration,
    seekCount: seekCount,
    segmentSwitchCount: segmentSwitchCount,
    isCurrentlyStalling: isCurrentlyStalling,
    effectivePlayDuration: _currentActivePlay,
    stallHistory: stallHistory,
    segmentSwitchHistory: segmentSwitchHistory,
  );

  // tiny helpers

  void _emit<T>(StreamController<T> sc, T event) {
    if (!sc.isClosed) sc.add(event);
  }

  bool _detectLoopReset(VideoPlayerValue previous, VideoPlayerValue current) {
    final duration = current.duration;
    if (duration == Duration.zero) return false;
    return previous.position >= duration * 0.95 &&
        current.position <= duration * 0.05;
  }

  Duration get _safePosition {
    try {
      return _controller.value.position;
    } catch (_) {
      return Duration.zero;
    }
  }

  void _debugLog(String msg) {
    if (_config.enableDebugLogging) print('[VideoTelemetry] $msg');
  }
}
