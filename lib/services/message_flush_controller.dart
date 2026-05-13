import 'dart:async';

class MessageFlushController<T> {
  final Duration interval;
  final int maxBatchSize;
  final List<T> _pending = [];
  Timer? _timer;

  MessageFlushController({required this.interval, required this.maxBatchSize});

  void enqueue(T item) {
    _pending.add(item);
  }

  void enqueueAll(Iterable<T> items) {
    _pending.addAll(items);
  }

  bool get hasPending => _pending.isNotEmpty;
  int get pendingLength => _pending.length;

  void start(void Function(List<T> batch) onFlush) {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) {
      if (_pending.isEmpty) {
        return;
      }
      final count = _pending.length > maxBatchSize ? maxBatchSize : _pending.length;
      final batch = _pending.sublist(0, count);
      _pending.removeRange(0, count);
      onFlush(batch);
    });
  }

  void clear() {
    _pending.clear();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _pending.clear();
  }
}
