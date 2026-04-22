/// Describes a single buffer stall event.
///
/// A stall is a period where `VideoPlayerController` reports playback as
/// active while also buffering, indicating the decoder is waiting for data.
/// Stalls caused by explicit seeks are excluded by higher-level telemetry
/// logic.
class StallEvent {
  const StallEvent({
    required this.timestamp,
    required this.position,
    required this.duration,
    required this.index,
  });

  /// Wall-clock time when the stall ended and playback resumed.
  final DateTime timestamp;

  /// Playback position at the moment the stall ended.
  final Duration position;

  /// Total duration of the stall.
  final Duration duration;

  /// 1-based ordinal of this stall in the current session.
  final int index;

  @override
  String toString() =>
      'StallEvent(#$index, duration: ${duration.inMilliseconds}ms, '
      'position: ${position.inMilliseconds}ms)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StallEvent &&
          other.timestamp == timestamp &&
          other.index == index);

  @override
  int get hashCode => Object.hash(timestamp, index);
}
