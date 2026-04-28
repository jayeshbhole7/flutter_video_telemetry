/// quality/segment switch event.
///
/// `video_player` hides hls/dash bits, so callers can report this manually
/// or let later code guess. hacky fix for now.
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

  /// wall-clock switch time.
  final DateTime timestamp;

  /// playback pos at switch time.
  final Duration position;

  /// guessed instead of reported.
  final bool isEstimated;

  /// old bitrate, if we know it.
  final int? fromBitrateKbps;

  /// new bitrate, if we know it.
  final int? toBitrateKbps;

  /// old res, like `1280x720`.
  final String? fromResolution;

  /// new res, like `1920x1080`.
  final String? toResolution;

  /// quick reason, when available.
  final String? reason;

  /// bitrate went up.
  bool get isUpgrade =>
      fromBitrateKbps != null &&
      toBitrateKbps != null &&
      toBitrateKbps! > fromBitrateKbps!;

  /// bitrate went down.
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
