/// Tiny injectable logger for the network layer (conventions doc § 3:
/// no `print`, logs carry context).
///
/// The infra layer must stay pure Dart and testable, so it never imports
/// a concrete logging backend. The composition root (app shell) injects
/// an implementation that forwards to the app-wide logger; tests inject
/// an in-memory recorder.
abstract interface class NetLog {
  /// Routine trace information (message dropped, reconnect attempt, ...).
  void info(String message);

  /// Recoverable problems (malformed server data, watchdog tripping).
  void warn(String message);

  /// Failures that break or suspect the connection.
  void error(String message, [Object? error, StackTrace? stackTrace]);
}

/// Default no-op [NetLog] used when no logger is injected.
///
/// The network layer still surfaces failures through its state machine
/// (`NetStatus.lastError`, disconnect transitions); this sink only
/// silences the diagnostic trail for embedding code that has no logger
/// yet.
final class SilentNetLog implements NetLog {
  /// Creates the discarding sink.
  const SilentNetLog();

  @override
  void info(String message) {}

  @override
  void warn(String message) {}

  @override
  void error(String message, [Object? error, StackTrace? stackTrace]) {}
}
