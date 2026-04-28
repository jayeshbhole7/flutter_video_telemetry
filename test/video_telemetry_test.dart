import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';
import 'package:video_telemetry/video_telemetry.dart';

void main() {
  test('StallEvent compares by timestamp and index', () {
    final timestamp = DateTime.utc(2026, 4, 22, 10, 30);
    final first = StallEvent(
      timestamp: timestamp,
      position: const Duration(seconds: 12),
      duration: const Duration(milliseconds: 750),
      index: 1,
    );
    final second = StallEvent(
      timestamp: timestamp,
      position: const Duration(seconds: 13),
      duration: const Duration(seconds: 2),
      index: 1,
    );

    expect(first, second);
    expect(first.hashCode, second.hashCode);
    expect(
      first.toString(),
      'StallEvent(#1, duration: 750ms, position: 12000ms)',
    );
  });

  test('SegmentSwitchEvent reports upgrade and downgrade state', () {
    final upgrade = SegmentSwitchEvent(
      timestamp: DateTime.utc(2026, 4, 22, 10, 31),
      position: const Duration(seconds: 30),
      isEstimated: false,
      fromBitrateKbps: 1200,
      toBitrateKbps: 2400,
    );
    final downgrade = SegmentSwitchEvent(
      timestamp: DateTime.utc(2026, 4, 22, 10, 32),
      position: const Duration(seconds: 45),
      isEstimated: true,
      fromBitrateKbps: 2400,
      toBitrateKbps: 800,
    );

    expect(upgrade.isUpgrade, isTrue);
    expect(upgrade.isDowngrade, isFalse);
    expect(downgrade.isUpgrade, isFalse);
    expect(downgrade.isDowngrade, isTrue);
    expect(
      upgrade.toString(),
      'SegmentSwitchEvent(up 1200->2400kbps, pos: 30000ms)',
    );
  });

  test('PlaybackErrorEvent formats a readable summary', () {
    final event = PlaybackErrorEvent(
      timestamp: DateTime.utc(2026, 4, 22, 10, 33),
      position: const Duration(seconds: 3),
      errorDescription: 'network failure',
    );

    expect(
      event.toString(),
      'PlaybackErrorEvent(pos: 3000ms, error: network failure)',
    );
  });

  test('TelemetrySnapshot stores the provided metrics and histories', () {
    final stall = StallEvent(
      timestamp: DateTime.utc(2026, 4, 22, 10, 34),
      position: const Duration(seconds: 15),
      duration: const Duration(milliseconds: 900),
      index: 1,
    );
    final switchEvent = SegmentSwitchEvent(
      timestamp: DateTime.utc(2026, 4, 22, 10, 35),
      position: const Duration(seconds: 18),
      isEstimated: false,
      fromBitrateKbps: 1000,
      toBitrateKbps: 1500,
    );
    final snapshot = TelemetrySnapshot(
      capturedAt: DateTime.utc(2026, 4, 22, 10, 36),
      timeToFirstFrame: const Duration(milliseconds: 450),
      stallCount: 1,
      totalStallDuration: const Duration(milliseconds: 900),
      rebufferingRatio: 0.05,
      averageStallDuration: const Duration(milliseconds: 900),
      seekCount: 2,
      segmentSwitchCount: 1,
      isCurrentlyStalling: false,
      effectivePlayDuration: const Duration(minutes: 2),
      stallHistory: <StallEvent>[stall],
      segmentSwitchHistory: <SegmentSwitchEvent>[switchEvent],
    );

    expect(snapshot.capturedAt, DateTime.utc(2026, 4, 22, 10, 36));
    expect(snapshot.timeToFirstFrame, const Duration(milliseconds: 450));
    expect(snapshot.stallCount, 1);
    expect(snapshot.totalStallDuration, const Duration(milliseconds: 900));
    expect(snapshot.rebufferingRatio, 0.05);
    expect(snapshot.averageStallDuration, const Duration(milliseconds: 900));
    expect(snapshot.seekCount, 2);
    expect(snapshot.segmentSwitchCount, 1);
    expect(snapshot.isCurrentlyStalling, isFalse);
    expect(snapshot.effectivePlayDuration, const Duration(minutes: 2));
    expect(snapshot.stallHistory, <StallEvent>[stall]);
    expect(snapshot.segmentSwitchHistory, <SegmentSwitchEvent>[switchEvent]);
    expect(
      snapshot.toString(),
      'TelemetrySnapshot(ttff: 450ms, stalls: 1, '
      'stallDuration: 900ms, rebuffering: 5.00%, seeks: 2)',
    );
  });

  test('VideoTelemetry detects stalls and tracks totals', () async {
    final controller = VideoPlayerController.asset('fake.mp4');
    final telemetry = VideoTelemetry.wrap(
      controller,
      config: const TelemetryConfig(
        minimumStallDuration: Duration(milliseconds: 5),
        pollingInterval: Duration(hours: 1),
      ),
    );
    final stalls = <StallEvent>[];
    final sub = telemetry.onStall(stalls.add);
    addTearDown(() async {
      await sub.cancel();
      telemetry.dispose();
      await controller.dispose();
    });

    controller.value = _playerValue(isPlaying: false);
    controller.value = _playerValue(
      isPlaying: true,
      position: const Duration(milliseconds: 1),
    );
    controller.value = _playerValue(
      isPlaying: true,
      isBuffering: true,
      position: const Duration(milliseconds: 250),
    );

    expect(telemetry.isCurrentlyStalling, isTrue);

    await Future<void>.delayed(const Duration(milliseconds: 10));

    controller.value = _playerValue(
      isPlaying: true,
      position: const Duration(milliseconds: 250),
    );
    await Future<void>.delayed(Duration.zero);

    expect(telemetry.isCurrentlyStalling, isFalse);
    expect(telemetry.stallCount, 1);
    expect(telemetry.stallHistory, hasLength(1));
    expect(stalls, hasLength(1));
    expect(stalls.single.index, 1);
    expect(stalls.single.position, const Duration(milliseconds: 250));
    expect(
      telemetry.totalStallDuration.inMilliseconds,
      greaterThanOrEqualTo(5),
    );
    expect(telemetry.averageStallDuration, telemetry.totalStallDuration);
  });

  test('VideoTelemetry ignores micro-stalls', () async {
    final controller = VideoPlayerController.asset('fake.mp4');
    final telemetry = VideoTelemetry.wrap(
      controller,
      config: const TelemetryConfig(
        minimumStallDuration: Duration(seconds: 30),
        pollingInterval: Duration(hours: 1),
      ),
    );
    final stalls = <StallEvent>[];
    final sub = telemetry.onStall(stalls.add);
    addTearDown(() async {
      await sub.cancel();
      telemetry.dispose();
      await controller.dispose();
    });

    controller.value = _playerValue(isPlaying: true, isBuffering: true);
    await Future<void>.delayed(const Duration(milliseconds: 1));
    controller.value = _playerValue(isPlaying: true);
    await Future<void>.delayed(Duration.zero);

    expect(telemetry.isCurrentlyStalling, isFalse);
    expect(telemetry.stallCount, 0);
    expect(telemetry.totalStallDuration, Duration.zero);
    expect(telemetry.averageStallDuration, Duration.zero);
    expect(telemetry.stallHistory, isEmpty);
    expect(stalls, isEmpty);
  });

  test('VideoTelemetry counts big position jumps as seeks', () async {
    final controller = VideoPlayerController.asset('fake.mp4');
    final telemetry = VideoTelemetry.wrap(
      controller,
      config: const TelemetryConfig(
        pollingInterval: Duration(milliseconds: 100),
      ),
    );
    addTearDown(() async {
      telemetry.dispose();
      await controller.dispose();
    });

    controller.value = _playerValue(isPlaying: true);
    controller.value = _playerValue(
      isPlaying: true,
      position: const Duration(seconds: 2),
    );
    controller.value = _playerValue(
      isPlaying: true,
      position: const Duration(milliseconds: 2100),
    );

    expect(telemetry.seekCount, 1);
    expect(telemetry.snapshot.seekCount, 1);
  });

  test('VideoTelemetry ignores loop resets as seeks', () async {
    final controller = VideoPlayerController.asset('fake.mp4');
    controller.value = _playerValue(
      isPlaying: true,
      duration: const Duration(seconds: 10),
      position: const Duration(milliseconds: 9800),
    );
    final telemetry = VideoTelemetry.wrap(
      controller,
      config: const TelemetryConfig(
        pollingInterval: Duration(milliseconds: 100),
      ),
    );
    addTearDown(() async {
      telemetry.dispose();
      await controller.dispose();
    });

    controller.value = _playerValue(
      isPlaying: true,
      duration: const Duration(seconds: 10),
      position: const Duration(milliseconds: 100),
    );

    expect(telemetry.seekCount, 0);
  });

  test('VideoTelemetry skips stalls during seek buffering', () async {
    final controller = VideoPlayerController.asset('fake.mp4');
    final telemetry = VideoTelemetry.wrap(
      controller,
      config: const TelemetryConfig(
        minimumStallDuration: Duration(milliseconds: 1),
        pollingInterval: Duration(milliseconds: 100),
      ),
    );
    final stalls = <StallEvent>[];
    final sub = telemetry.onStall(stalls.add);
    addTearDown(() async {
      await sub.cancel();
      telemetry.dispose();
      await controller.dispose();
    });

    controller.value = _playerValue(isPlaying: true);
    controller.value = _playerValue(
      isPlaying: true,
      isBuffering: true,
      position: const Duration(seconds: 2),
    );
    await Future<void>.delayed(const Duration(milliseconds: 5));
    controller.value = _playerValue(
      isPlaying: true,
      position: const Duration(seconds: 2),
    );
    await Future<void>.delayed(Duration.zero);

    expect(telemetry.seekCount, 1);
    expect(telemetry.isCurrentlyStalling, isFalse);
    expect(telemetry.stallCount, 0);
    expect(stalls, isEmpty);
  });

  test('VideoTelemetry cancels stalls when a seek lands', () async {
    final controller = VideoPlayerController.asset('fake.mp4');
    final telemetry = VideoTelemetry.wrap(
      controller,
      config: const TelemetryConfig(
        minimumStallDuration: Duration(milliseconds: 1),
        pollingInterval: Duration(milliseconds: 100),
      ),
    );
    addTearDown(() async {
      telemetry.dispose();
      await controller.dispose();
    });

    controller.value = _playerValue(isPlaying: true);
    controller.value = _playerValue(
      isPlaying: true,
      isBuffering: true,
      position: const Duration(milliseconds: 100),
    );
    await Future<void>.delayed(const Duration(milliseconds: 5));

    controller.value = _playerValue(
      isPlaying: true,
      isBuffering: true,
      position: const Duration(seconds: 3),
    );
    controller.value = _playerValue(
      isPlaying: true,
      position: const Duration(seconds: 3),
    );
    await Future<void>.delayed(Duration.zero);

    expect(telemetry.seekCount, 1);
    expect(telemetry.isCurrentlyStalling, isFalse);
    expect(telemetry.stallCount, 0);
  });
}

VideoPlayerValue _playerValue({
  required bool isPlaying,
  bool isBuffering = false,
  Duration duration = const Duration(minutes: 1),
  Duration position = Duration.zero,
}) {
  return VideoPlayerValue(
    duration: duration,
    isInitialized: true,
    isPlaying: isPlaying,
    isBuffering: isBuffering,
    position: position,
  );
}
