import 'package:flutter/foundation.dart';

/// The minimal contract any video player must satisfy to be observed
/// by video_telemetry. Implement this for any player you use.
abstract class TelemetryPlayerObserver {
  bool get isPlaying;
  bool get isBuffering;
  bool get isInitialized;
  Duration get position;
  Duration? get duration;
  bool get hasError;
  String? get errorDescription;
  double get playbackSpeed;

  void addListener(VoidCallback listener);
  void removeListener(VoidCallback listener);
}
