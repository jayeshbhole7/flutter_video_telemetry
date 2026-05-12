import 'package:meta/meta.dart';

/// Describes a playback error surfaced by the underlying video player.
@immutable
class PlaybackErrorEvent {
  /// Creates a [PlaybackErrorEvent] to record playback errors.
  const PlaybackErrorEvent({
    required this.timestamp,
    required this.position,
    this.errorDescription,
  });

  /// Wall-clock time when the error was detected.
  final DateTime timestamp;

  /// Playback position at the time of the error.
  ///
  /// This may be `Duration.zero` if the error occurred before the first frame.
  final Duration position;

  /// Raw error text reported by the platform player, if available.
  final String? errorDescription;

  @override
  String toString() => 'PlaybackErrorEvent(pos: ${position.inMilliseconds}ms, '
      'error: $errorDescription)';
}
