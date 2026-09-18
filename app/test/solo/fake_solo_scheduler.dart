/// Test scheduler for the solo controller's clock seam: records
/// scheduled callbacks and fires them when the virtual clock is
/// advanced. No real timers.
final class FakeSoloScheduler {
  final List<ScheduledCallback> _pending = [];

  /// Virtual time, milliseconds.
  int now = 0;

  /// Callbacks still scheduled (tests assert nothing lingers).
  List<ScheduledCallback> get pending => List.unmodifiable(_pending);

  /// Schedules [callback] at `now + [delay]` (the function-typed seam
  /// injected into the controller).
  void call(Duration delay, void Function() callback) {
    _pending.add(
      ScheduledCallback(
        dueMillis: now + delay.inMilliseconds,
        callback: callback,
      ),
    );
  }

  /// Fires callbacks due within [milliseconds] of virtual time, in
  /// schedule order. The clock advances to each callback's due time
  /// before it runs, and callbacks scheduling more work are picked up
  /// while it stays inside the window.
  void elapse(int milliseconds) {
    final target = now + milliseconds;
    while (true) {
      final due = _pending.where((c) => c.dueMillis <= target).toList()
        ..sort((a, b) => a.dueMillis.compareTo(b.dueMillis));
      if (due.isEmpty) {
        break;
      }
      for (final callback in due) {
        _pending.remove(callback);
        now = callback.dueMillis;
        callback.callback();
      }
    }
    now = target;
  }
}

/// One recorded clock-seam call.
final class ScheduledCallback {
  /// Creates the record.
  const ScheduledCallback({required this.dueMillis, required this.callback});

  /// Virtual due time in milliseconds.
  final int dueMillis;

  /// The callback to run.
  final void Function() callback;
}
