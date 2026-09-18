/// Minimal logging seam for the WS layer.
///
/// Every log site takes an injected [Log] instead of a logging
/// package; the default implementation drops everything (AGENTS § 6.6:
/// no `print`, network doc § 6: log-and-drop, never crash).
typedef Log = void Function(String message);

/// Default no-op [Log]; ignores every message.
void noopLog(String message) {}
