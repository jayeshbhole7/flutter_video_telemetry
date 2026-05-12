/// Configuration for the telemetry wrapper.
///
/// All fields have production-ready defaults. Override only what you need.
class TelemetryConfig {
  /// Creates a [TelemetryConfig] with the specified thresholds and intervals.
  const TelemetryConfig({
    this.minimumStallDuration = const Duration(milliseconds: 200),
    this.pollingInterval = const Duration(milliseconds: 100),
    this.seekJumpThreshold = const Duration(milliseconds: 800),
    this.snapshotInterval,
    this.stallHistoryCapacity = 50,
    this.segmentSwitchHistoryCapacity = 20,
    this.enableDebugLogging = false,
  })  : assert(stallHistoryCapacity > 0, 'stallHistoryCapacity must be > 0'),
        assert(
          segmentSwitchHistoryCapacity > 0,
          'segmentSwitchHistoryCapacity must be > 0',
        );

  /// Stalls shorter than this threshold are silently ignored.
  ///
  /// Filters out decoder pipeline hiccups that are not user-visible.
  /// Industry standard is 200 ms.
  final Duration minimumStallDuration;

  /// How often telemetry polls the controller as a fallback.
  ///
  /// Flutter's ValueNotifier can suppress notifications when the value
  /// object reference does not change. The poller catches those cases.
  final Duration pollingInterval;

  /// Position jumps larger than this are classified as seeks rather than
  /// stalls. The effective threshold scales with playback speed.
  final Duration seekJumpThreshold;

  /// When set, snapshotStream emits at this interval.
  /// Set to null to disable periodic snapshots.
  final Duration? snapshotInterval;

  /// Maximum stall events retained in history before the oldest is evicted.
  final int stallHistoryCapacity;

  /// Maximum segment switch events retained in history.
  final int segmentSwitchHistoryCapacity;

  /// Prints internal state transitions. Disable before shipping.
  final bool enableDebugLogging;
}
