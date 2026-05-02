import 'stall_event.dart';
import 'segment_switch_event.dart';

/// An immutable snapshot of all telemetry metrics at a point in time.
///
/// Obtain via [VideoTelemetry.snapshot] or subscribe to
/// [VideoTelemetry.snapshotStream] for periodic updates.
///
/// All duration fields are zero / null until the corresponding event occurs.
class TelemetrySnapshot {
  const TelemetrySnapshot({
    required this.capturedAt,
    required this.stallCount,
    required this.totalStallDuration,
    required this.rebufferingRatio,
    required this.averageStallDuration,
    required this.seekCount,
    required this.segmentSwitchCount,
    required this.isCurrentlyStalling,
    required this.effectivePlayDuration,
    required this.stallHistory,
    required this.segmentSwitchHistory,
    this.timeToFirstFrame,
  });

  /// When this snapshot was captured.
  final DateTime capturedAt;

  /// Time from [VideoPlayerController.play] to the first rendered frame.
  /// Null until the first frame has been rendered.
  final Duration? timeToFirstFrame;

  /// Number of buffer stalls in the current session.
  final int stallCount;

  /// Cumulative time spent in buffer stalls.
  final Duration totalStallDuration;

  /// Fraction [0.0–1.0] of session time spent rebuffering.
  /// 0.10 means 10 % of wall-clock session time was a stall.
  final double rebufferingRatio;

  /// Mean stall duration. [Duration.zero] when [stallCount] == 0.
  final Duration averageStallDuration;

  /// Number of times the user (or app) seeked.
  final int seekCount;

  /// Number of quality / segment switches recorded.
  final int segmentSwitchCount;

  /// Whether a stall is actively in progress at snapshot time.
  final bool isCurrentlyStalling;

  /// Wall-clock time the video was actually playing (session – stalls).
  final Duration effectivePlayDuration;

  /// Recent stall events (up to [TelemetryConfig.stallHistoryCapacity]).
  final List<StallEvent> stallHistory;

  /// Recent segment switch events (up to [TelemetryConfig.segmentSwitchHistoryCapacity]).
  final List<SegmentSwitchEvent> segmentSwitchHistory;


  /// Stalls per minute of effective play time.
  /// Returns 0.0 when no playback has occurred.
  double get stallsPerMinute {
    final minutes = effectivePlayDuration.inSeconds / 60.0;
    if (minutes == 0) return 0.0;
    return stallCount / minutes;
  }

  /// True when at least one metric indicates degraded playback.
  bool get hasQualityIssues => rebufferingRatio > 0.02 || stallCount > 2 || stallsPerMinute > 1.0;

  /// Percentage representation of [rebufferingRatio], rounded to 2 decimals.
  String get rebufferingPercent => '${(rebufferingRatio * 100).toStringAsFixed(2)}%';

  @override
  String toString() => 'TelemetrySnapshot('
      'ttff: ${timeToFirstFrame?.inMilliseconds}ms, '
      'stalls: $stallCount, '
      'stallDuration: ${totalStallDuration.inMilliseconds}ms, '
      'rebuffering: $rebufferingPercent, '
      'seeks: $seekCount'
      ')';
}
