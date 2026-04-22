import 'segment_switch_event.dart';
import 'stall_event.dart';

/// An immutable snapshot of telemetry metrics at a point in time.
///
/// Obtain this from the higher-level telemetry API when snapshot support is
/// added.
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

  /// Time from play to the first rendered frame.
  ///
  /// Null until the first frame has been rendered.
  final Duration? timeToFirstFrame;

  /// Number of buffer stalls in the current session.
  final int stallCount;

  /// Cumulative time spent in buffer stalls.
  final Duration totalStallDuration;

  /// Fraction [0.0-1.0] of session time spent rebuffering.
  final double rebufferingRatio;

  /// Mean stall duration.
  ///
  /// `Duration.zero` when `stallCount == 0`.
  final Duration averageStallDuration;

  /// Number of times the user or app seeked.
  final int seekCount;

  /// Number of quality or segment switches recorded.
  final int segmentSwitchCount;

  /// Whether a stall is actively in progress at snapshot time.
  final bool isCurrentlyStalling;

  /// Wall-clock time the video was actually playing, excluding stalls.
  final Duration effectivePlayDuration;

  /// Recent stall events.
  final List<StallEvent> stallHistory;

  /// Recent segment switch events.
  final List<SegmentSwitchEvent> segmentSwitchHistory;

  @override
  String toString() =>
      'TelemetrySnapshot('
      'ttff: ${timeToFirstFrame?.inMilliseconds}ms, '
      'stalls: $stallCount, '
      'stallDuration: ${totalStallDuration.inMilliseconds}ms, '
      'rebuffering: ${(rebufferingRatio * 100).toStringAsFixed(2)}%, '
      'seeks: $seekCount'
      ')';
}
