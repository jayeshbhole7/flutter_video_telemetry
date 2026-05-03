import 'package:meta/meta.dart';

/// one buffer stall.
///
/// playing + buffering means the player is stuck waiting for data.
/// seek cleanup comes later; refactor this later if it gets weird.
@immutable
class StallEvent {
  const StallEvent({
    required this.timestamp,
    required this.position,
    required this.duration,
    required this.index,
  });

  /// wall-clock time when playback came back.
  final DateTime timestamp;

  /// playback pos when the stall ended.
  final Duration position;

  /// how long it stalled.
  final Duration duration;

  /// 1-based stall number for this session.
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
