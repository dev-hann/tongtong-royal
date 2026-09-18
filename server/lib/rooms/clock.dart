/// Time-source abstraction for the room lifecycle core.
///
/// Choice (documented per task constraint): every timestamp inside
/// this library comes from an injected [Clock] in milliseconds since
/// the Unix epoch. The room core never calls `DateTime.now()` and
/// never starts timers; wall time reaches it only through the adapter
/// that owns the real clock. This keeps the room logic pure,
/// synchronous, and fully deterministic under test.
typedef Clock = int Function();

/// Deterministic [Clock] whose time is advanced by hand.
///
/// Used by tests and by any host embedding that wants stepped time.
/// Instances are callable and can be passed wherever a [Clock] is
/// expected.
final class ManualClock {
  /// Creates a clock positioned at [startMs] (default 0).
  ManualClock({int startMs = 0}) : _nowMs = startMs;

  int _nowMs;

  /// Moves the clock forward by [ms] milliseconds.
  void advanceMs(int ms) {
    _nowMs += ms;
  }

  /// Returns the current time in milliseconds since the Unix epoch.
  int call() => _nowMs;
}
