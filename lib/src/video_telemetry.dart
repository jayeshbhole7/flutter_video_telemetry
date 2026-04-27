// ignore_for_file: avoid_print
import 'dart:async';

import 'package:video_player/video_player.dart';

import 'models/playback_error_event.dart';
import 'models/segment_switch_event.dart';
import 'models/stall_event.dart';
import 'models/telemetry_snapshot.dart';
import 'telemetry_config.dart';
import 'utils/ring_buffer.dart';

/// Attaches to a [VideoPlayerController] and measures real playback
/// performance without interfering with playback.
///
/// ```dart
/// final telemetry = VideoTelemetry.wrap(controller);
/// // your player works exactly as before
/// telemetry.dispose(); // call in widget dispose()
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

  // Phase 6 - TTFF
  bool _wrappedWhilePlaying = false;
  bool _hasFirstFrame = false;
  DateTime? _playStartedAt;
  DateTime? _firstFrameAt;

  Timer? _pollTimer;
  Timer? _snapshotTimer;

  // History buffers - capacity-bounded so long streams don't leak memory.
  late final RingBuffer<StallEvent> _stallHistory = RingBuffer(
    _config.stallHistoryCapacity,
  );
  late final RingBuffer<SegmentSwitchEvent> _segmentHistory = RingBuffer(
    _config.segmentSwitchHistoryCapacity,
  );

  // Stream controllers - all broadcast so multiple listeners are supported.
  final _stallSC = StreamController<StallEvent>.broadcast();
  final _ttffSC = StreamController<Duration>.broadcast();
  final _segmentSC = StreamController<SegmentSwitchEvent>.broadcast();
  final _errorSC = StreamController<PlaybackErrorEvent>.broadcast();
  final _snapshotSC = StreamController<TelemetrySnapshot>.broadcast();

  // Factory

  /// Wraps [controller] with telemetry.
  ///
  /// The controller may be uninitialized, paused, or already playing.
  static VideoTelemetry wrap(
    VideoPlayerController controller, {
    TelemetryConfig config = const TelemetryConfig(),
  }) {
    return VideoTelemetry._(controller, config: config);
  }

  // Lifecycle

  void _attach() {
    _lastValue = _controller.value;

    if (_controller.value.isPlaying) {
      _wrappedWhilePlaying = true;
      _playStartedAt = DateTime.now();
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
    if (!current.isInitialized) return;

    // Play-start timestamp
    if (current.isPlaying && !previous.isPlaying && _playStartedAt == null) {
      _playStartedAt = DateTime.now();
      _debugLog('first play() detected');
    }

    // TTFF
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
  }

  /// Detaches from the controller and closes all streams. Safe to call
  /// multiple times.
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

  // Public streams

  Stream<StallEvent> get stallStream => _stallSC.stream;
  Stream<Duration> get firstFrameStream => _ttffSC.stream;
  Stream<SegmentSwitchEvent> get segmentSwitchStream => _segmentSC.stream;
  Stream<PlaybackErrorEvent> get errorStream => _errorSC.stream;
  Stream<TelemetrySnapshot> get snapshotStream => _snapshotSC.stream;

  // Metrics (stubs - filled in per phase)

  Duration? get timeToFirstFrame {
    if (!_hasFirstFrame || _playStartedAt == null || _firstFrameAt == null) {
      return null;
    }
    return _firstFrameAt!.difference(_playStartedAt!);
  }

  bool get ttffAvailable => !_wrappedWhilePlaying;
  int get stallCount => 0; // Phase 7
  Duration get totalStallDuration => Duration.zero;
  double get rebufferingRatio => 0.0; // Phase 9
  Duration get averageStallDuration => Duration.zero;
  int get seekCount => 0; // Phase 8
  int get segmentSwitchCount => 0;
  bool get isCurrentlyStalling => false;
  List<StallEvent> get stallHistory => _stallHistory.toList();
  List<SegmentSwitchEvent> get segmentSwitchHistory => _segmentHistory.toList();

  TelemetrySnapshot get snapshot => TelemetrySnapshot(
    capturedAt: DateTime.now(),
    stallCount: stallCount,
    totalStallDuration: totalStallDuration,
    rebufferingRatio: rebufferingRatio,
    averageStallDuration: averageStallDuration,
    seekCount: seekCount,
    segmentSwitchCount: segmentSwitchCount,
    isCurrentlyStalling: isCurrentlyStalling,
    effectivePlayDuration: Duration.zero,
    stallHistory: stallHistory,
    segmentSwitchHistory: segmentSwitchHistory,
  );

  // Internal helpers

  void _emit<T>(StreamController<T> sc, T event) {
    if (!sc.isClosed) sc.add(event);
  }

  void _debugLog(String msg) {
    if (_config.enableDebugLogging) print('[VideoTelemetry] $msg');
  }
}
