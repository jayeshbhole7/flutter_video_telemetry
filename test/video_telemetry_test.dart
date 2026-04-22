import 'package:flutter_test/flutter_test.dart';
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
}
