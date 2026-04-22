/// Describes a quality or segment switch event.
///
/// The `video_player` package does not expose HLS or DASH segment metadata
/// directly. These events can be reported manually by an app integration or
/// inferred by higher-level telemetry logic.
class SegmentSwitchEvent {
  const SegmentSwitchEvent({
    required this.timestamp,
    required this.position,
    required this.isEstimated,
    this.fromBitrateKbps,
    this.toBitrateKbps,
    this.fromResolution,
    this.toResolution,
    this.reason,
  });

  /// Wall-clock time of the switch.
  final DateTime timestamp;

  /// Playback position at switch time.
  final Duration position;

  /// Whether this event was inferred rather than explicitly reported.
  final bool isEstimated;

  /// Outgoing bitrate in kilobits per second, or null if unknown.
  final int? fromBitrateKbps;

  /// Incoming bitrate in kilobits per second, or null if unknown.
  final int? toBitrateKbps;

  /// Outgoing resolution string, for example `1280x720`, or null if unknown.
  final String? fromResolution;

  /// Incoming resolution string, for example `1920x1080`, or null if unknown.
  final String? toResolution;

  /// Optional human-readable reason for the switch.
  final String? reason;

  /// True if this was an upgrade to a higher bitrate.
  bool get isUpgrade =>
      fromBitrateKbps != null &&
      toBitrateKbps != null &&
      toBitrateKbps! > fromBitrateKbps!;

  /// True if this was a downgrade to a lower bitrate.
  bool get isDowngrade =>
      fromBitrateKbps != null &&
      toBitrateKbps != null &&
      toBitrateKbps! < fromBitrateKbps!;

  @override
  String toString() {
    final direction = isUpgrade ? 'up' : (isDowngrade ? 'down' : 'same');
    return 'SegmentSwitchEvent($direction '
        '${fromBitrateKbps ?? "?"}->${toBitrateKbps ?? "?"}kbps, '
        'pos: ${position.inMilliseconds}ms)';
  }
}
