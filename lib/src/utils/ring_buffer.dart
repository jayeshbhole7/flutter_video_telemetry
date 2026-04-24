/// A fixed-capacity circular buffer.
///
/// When full, adding an item overwrites the oldest entry. Inserts are O(1);
/// snapshots are O(n).
class RingBuffer<T> {
  RingBuffer(this.capacity) : assert(capacity > 0, 'capacity must be > 0');

  /// Maximum number of elements retained by the buffer.
  final int capacity;

  final List<T?> _buffer = <T?>[];
  int _head = 0;
  int _size = 0;

  /// Adds [item] to the buffer, evicting the oldest entry when full.
  void add(T item) {
    if (_buffer.length < capacity) {
      _buffer.add(item);
      _head = _buffer.length % capacity;
    } else {
      _buffer[_head] = item;
      _head = (_head + 1) % capacity;
    }

    if (_size < capacity) {
      _size++;
    }
  }

  /// Returns all elements in insertion order, oldest first.
  List<T> toList() {
    final result = <T>[];

    if (_buffer.length < capacity) {
      for (var i = 0; i < _size; i++) {
        result.add(_buffer[i] as T);
      }
      return result;
    }

    for (var i = 0; i < _size; i++) {
      result.add(_buffer[(_head + i) % capacity] as T);
    }
    return result;
  }

  /// Removes all elements.
  void clear() {
    _buffer.clear();
    _head = 0;
    _size = 0;
  }

  /// Number of elements currently stored.
  int get length => _size;

  /// Whether the buffer has no elements.
  bool get isEmpty => _size == 0;
}
