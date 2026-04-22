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
}
