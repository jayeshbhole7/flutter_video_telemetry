import 'package:flutter_test/flutter_test.dart';
import 'package:video_telemetry/src/utils/ring_buffer.dart';

void main() {
  group('RingBuffer', () {
    test('stores elements up to capacity', () {
      final buffer = RingBuffer<int>(3);

      buffer.add(1);
      buffer.add(2);
      buffer.add(3);

      expect(buffer.toList(), <int>[1, 2, 3]);
      expect(buffer.length, 3);
      expect(buffer.isEmpty, isFalse);
    });

    test('evicts oldest when full', () {
      final buffer = RingBuffer<int>(3);

      buffer.add(1);
      buffer.add(2);
      buffer.add(3);
      buffer.add(4);

      expect(buffer.toList(), <int>[2, 3, 4]);
      expect(buffer.length, 3);
    });

    test('evicts across multiple wraps', () {
      final buffer = RingBuffer<int>(3);

      for (var i = 1; i <= 9; i++) {
        buffer.add(i);
      }

      expect(buffer.toList(), <int>[7, 8, 9]);
      expect(buffer.length, 3);
    });

    test('clear resets to empty', () {
      final buffer = RingBuffer<int>(3)
        ..add(1)
        ..add(2);

      buffer.clear();

      expect(buffer.toList(), isEmpty);
      expect(buffer.length, 0);
      expect(buffer.isEmpty, isTrue);
    });

    test('isEmpty is true before adding elements', () {
      final buffer = RingBuffer<int>(5);

      expect(buffer.isEmpty, isTrue);
      expect(buffer.length, 0);
    });

    test('single-element capacity retains only the latest value', () {
      final buffer = RingBuffer<int>(1);

      buffer.add(42);
      expect(buffer.toList(), <int>[42]);

      buffer.add(99);
      expect(buffer.toList(), <int>[99]);
      expect(buffer.length, 1);
    });

    test('insertion order is preserved through wrap', () {
      final buffer = RingBuffer<String>(4);

      buffer.add('a');
      buffer.add('b');
      buffer.add('c');
      buffer.add('d');
      buffer.add('e');

      expect(buffer.toList(), <String>['b', 'c', 'd', 'e']);
    });

    test('toList returns an independent copy', () {
      final buffer = RingBuffer<int>(3)
        ..add(1)
        ..add(2);

      final list = buffer.toList();
      list.add(99);

      expect(buffer.toList(), <int>[1, 2]);
      expect(buffer.length, 2);
    });

    test('preserves null values for nullable element types', () {
      final buffer = RingBuffer<int?>(3);

      buffer.add(1);
      buffer.add(null);
      buffer.add(3);

      expect(buffer.toList(), <int?>[1, null, 3]);
    });
  });
}
