import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';
import 'package:video_telemetry/video_telemetry.dart';

/// Adapter that makes [VideoPlayerController] observable by video_telemetry.
///
/// ```dart
/// final telemetry = VideoTelemetry.wrap(
///   VideoPlayerObserver(controller),
/// );
/// ```
class VideoPlayerObserver implements TelemetryPlayerObserver {
  VideoPlayerObserver(this._controller);

  final VideoPlayerController _controller;

  @override
  bool get isPlaying => _controller.value.isPlaying;
  @override
  bool get isBuffering => _controller.value.isBuffering;
  @override
  bool get isInitialized => _controller.value.isInitialized;
  @override
  Duration get position => _controller.value.position;
  @override
  Duration? get duration => _controller.value.duration;
  @override
  bool get hasError => _controller.value.hasError;
  @override
  String? get errorDescription => _controller.value.errorDescription;
  @override
  double get playbackSpeed => _controller.value.playbackSpeed;

  @override
  void addListener(VoidCallback l) => _controller.addListener(l);
  @override
  void removeListener(VoidCallback l) => _controller.removeListener(l);
}
