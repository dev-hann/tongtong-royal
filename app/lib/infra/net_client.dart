import 'dart:async';

import 'package:app/infra/connection.dart';
import 'package:app/infra/net_log.dart';
import 'package:app/infra/net_status.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

/// Clock used by the network layer: elapsed time since an arbitrary
/// epoch. Injectable so tests never depend on wall time.
typedef NetClock = Duration Function();

/// Reconnect delay before attempt [attempt] (1-based). Injectable so
/// tests run instantly.
typedef ReconnectBackoff = FutureOr<void> Function(int attempt);

/// Fixed delay between reconnect attempts (network doc § 5).
const Duration reconnectBaseDelay = Duration(seconds: 1);

/// Maximum automatic reconnect attempts per outage episode.
const int maxReconnectAttempts = 5;

/// Grace window for rejoining a room after a disconnect or background
/// pause (network doc § 5.1–5.3: 10 s).
const Duration rejoinGraceWindow = Duration(seconds: 10);

/// No game snapshot for this long during an active match marks the
/// connection unstable (network doc § 6: 2 s).
const Duration snapshotStarvationTimeout = Duration(seconds: 2);

final Stopwatch _defaultClockEpoch = Stopwatch()..start();

Duration _defaultNetClock() => _defaultClockEpoch.elapsed;

FutureOr<void> _defaultReconnectBackoff(int attempt) =>
    Future<void>.delayed(reconnectBaseDelay);

Future<Connection> _defaultFactory(Uri uri) async =>
    WebSocketConnection.connect(uri);

/// Client network state machine: handshake, room join, typed message
/// fan-out, backgrounding, snapshot watchdog and reconnect.
///
/// Pure logic: no Flutter imports, no UI, no rules. All time comes from
/// an injected [NetClock], all transport from an injected
/// [NetConnectionFactory]; the widget shell supplies real ones and
/// drives [onWatchdogTick]/lifecycle hooks.
final class NetClient {
  /// Creates a client. Every collaborator is injectable; defaults use
  /// real WebSocket connections, real elapsed time and a fixed backoff.
  NetClient({
    NetConnectionFactory? connectionFactory,
    NetClock? clock,
    ReconnectBackoff? backoff,
    NetLog? log,
  }) : _factory = connectionFactory ?? _defaultFactory,
       _clock = clock ?? _defaultNetClock,
       _backoff = backoff ?? _defaultReconnectBackoff,
       _log = log ?? const SilentNetLog();

  final NetConnectionFactory _factory;
  final NetClock _clock;
  final ReconnectBackoff _backoff;
  final NetLog _log;

  final StreamController<NetStatus> _statusController =
      StreamController<NetStatus>.broadcast();
  final StreamController<RoomSnapshot> _snapshotsController =
      StreamController<RoomSnapshot>.broadcast();
  final StreamController<Snapshot> _gameSnapshotsController =
      StreamController<Snapshot>.broadcast();
  final StreamController<RoundStarting> _roundStartingController =
      StreamController<RoundStarting>.broadcast();
  final StreamController<RoundResultsMessage> _resultsController =
      StreamController<RoundResultsMessage>.broadcast();
  final StreamController<RoomClosed> _roomClosedController =
      StreamController<RoomClosed>.broadcast();
  final StreamController<PlayerInputMessage> _memberInputsController =
      StreamController<PlayerInputMessage>.broadcast();
  final StreamController<WireMessage> _noticesController =
      StreamController<WireMessage>.broadcast();

  NetConnectionState _state = const NetDisconnected();
  Duration? _pingRtt;
  bool _unstable = false;
  String? _lastError;

  Uri? _uri;
  PlayerId? _playerId;
  String? _nickname;
  Connection? _connection;

  // Assigned per connection; cancelled by `_teardownConnection` when a
  // connection closes, reconnects or the client is disposed.
  // ignore: cancel_subscriptions
  StreamSubscription<String>? _subscription;
  int _generation = 0;
  bool _intentionalClose = false;

  String? _lastRoomCode;
  int _inputSeq = 0;
  int? _lastAppliedTick;
  bool _matchActive = false;
  Duration _lastSnapshotAt = Duration.zero;
  Duration? _lastPingSentAt;

  bool _backgrounded = false;
  Duration? _pausedAt;
  Completer<void>? _rejoinWaiter;
  bool _rejoinSucceeded = false;

  /// Current lifecycle state.
  NetConnectionState get state => _state;

  /// Current UI-facing status.
  NetStatus get status => NetStatus(
    state: _state,
    ping: _pingRtt,
    unstable: _unstable,
    lastError: _lastError,
  );

  /// Emits on every status change (state, ping, unstable, lastError).
  Stream<NetStatus> get statusChanges => _statusController.stream;

  /// Lobby snapshots (join/create/rejoin replies and lobby updates).
  Stream<RoomSnapshot> get snapshots => _snapshotsController.stream;

  /// In-match 20 Hz host snapshots (already filtered for stale ticks).
  Stream<Snapshot> get gameSnapshots => _gameSnapshotsController.stream;

  /// Member input samples relayed by the server while this client
  /// hosts a match (network doc § 1: 30 Hz each).
  ///
  /// Attribution: the server stamps the sending connection's
  /// `playerId` before relaying (network doc § 1 "Input attribution");
  /// a null playerId means unattributed and must be dropped by the
  /// consumer.
  Stream<PlayerInputMessage> get memberInputs => _memberInputsController.stream;

  /// Round announcements (`ROUND_INTRO`, network doc § 4).
  Stream<RoundStarting> get roundStarting => _roundStartingController.stream;

  /// Judged standings of finished rounds.
  Stream<RoundResultsMessage> get results => _resultsController.stream;

  /// Room-ended notices; reasons are surfaced for the UI (e.g.
  /// `hostLeft` → back to home, network doc § 5.1).
  Stream<RoomClosed> get roomClosed => _roomClosedController.stream;

  /// Infrequent server notices (`RateLimited`, `AlreadyConnected`,
  /// `ServerFull`).
  Stream<WireMessage> get notices => _noticesController.stream;

  /// Last room code this client joined, if any.
  String? get lastRoomCode => _lastRoomCode;

  /// Sequence number of the last input sent on this connection.
  int get lastInputSeq => _inputSeq;

  /// Opens a socket to [uri], sends `Hello{protocolVersion, playerId,
  /// nickname}` and moves to `connected` (network doc § 2).
  Future<void> connect(Uri uri, PlayerId playerId, String nickname) async {
    _generation++;
    _uri = uri;
    _playerId = playerId;
    _nickname = nickname;
    _intentionalClose = false;
    _backgrounded = false;
    _setState(const NetConnecting());
    final gen = _generation;
    final opened = await _openConnection(rejoinCode: null);
    if (gen != _generation) {
      return;
    }
    if (opened) {
      _setState(const NetConnected());
    } else {
      await _reconnect();
    }
  }

  /// Requests room creation; state becomes `joined(code)` once the
  /// server replies with a `RoomSnapshot`.
  void createRoom() {
    if (!_requireConnected('createRoom')) {
      return;
    }
    _send(const CreateRoom());
  }

  /// Requests joining the room with invite [code].
  void joinRoom(String code) {
    if (!_requireConnected('joinRoom')) {
      return;
    }
    _send(JoinRoom(code: code));
  }

  /// Requests rejoining the room with invite [code] (reconnect path).
  void rejoinRoom(String code) {
    if (!_requireConnected('rejoinRoom')) {
      return;
    }
    _send(RejoinRoom(code: code));
  }

  /// Sends a lobby ready toggle.
  // Positional bool keeps the task-mandated call surface.
  // ignore: avoid_positional_boolean_parameters
  void setReady(bool ready) {
    if (!_requireRoom('setReady')) {
      return;
    }
    _send(SetReady(ready: ready));
  }

  /// Sends the host-only match start request.
  void startMatch() {
    if (!_requireRoom('startMatch')) {
      return;
    }
    _send(const StartMatch());
  }

  /// Sends one input sample; assigns the next per-connection `seq`
  /// (monotonic, reset on every new connection).
  void sendInput(PlayerInputState input) {
    if (_state is! NetJoined) {
      _log.warn('sendInput ignored: not in a room');
      return;
    }
    _inputSeq++;
    _send(
      PlayerInputMessage(
        seq: _inputSeq,
        moveX: input.moveDir.x,
        moveY: input.moveDir.y,
        jump: input.jumpPressed,
        dash: input.dashPressed,
      ),
    );
  }

  /// Sends a host-authored message verbatim over the current
  /// connection (typed transport only — `RoundStarting`, `Snapshot`,
  /// `RoundResultsMessage`). The server enforces host-only relay
  /// (network doc § 3); this layer adds no rules.
  void sendHost(WireMessage message) {
    if (!_requireRoom('sendHost')) {
      return;
    }
    _send(message);
  }

  /// Sends a keepalive ping; the next `Pong` updates `status.ping`.
  void ping() {
    _lastPingSentAt = _clock();
    _send(const Ping());
  }

  /// App backgrounded: immediate clean close, reconnect path armed
  /// (network doc § 5.3). No attempts run while suspended; the resume
  /// path decides based on the grace window.
  void onAppLifecyclePaused() {
    if (_uri == null) {
      return; // never connected: nothing to protect
    }
    if (_state is NetClosed || _state is NetVersionMismatch) {
      return;
    }
    _generation++;
    _backgrounded = true;
    _pausedAt = _clock();
    _intentionalClose = true;
    _completeRejoinWaiter();
    _teardownConnection();
    _matchActive = false;
    _unstable = false;
    _setState(NetReconnecting(roomCode: _lastRoomCode, attempt: 0));
  }

  /// App foregrounded again: automatic `RejoinRoom` if within the grace
  /// window, otherwise terminal `closed(needsManualRejoin: true)`
  /// (network doc § 5.3).
  Future<void> onAppLifecycleResumed() async {
    if (!_backgrounded) {
      return;
    }
    _backgrounded = false;
    final pausedAt = _pausedAt;
    _pausedAt = null;
    if (pausedAt == null) {
      return;
    }
    final awayFor = _clock() - pausedAt;
    if (awayFor > rejoinGraceWindow) {
      _generation++;
      _setState(const NetClosed(needsManualRejoin: true));
      return;
    }
    _generation++;
    _setState(const NetConnecting());
    final gen = _generation;
    final opened = await _openConnection(rejoinCode: _lastRoomCode);
    if (gen != _generation) {
      return;
    }
    if (opened) {
      _setState(const NetConnected());
    } else {
      _setState(NetClosed(needsManualRejoin: _lastRoomCode != null));
    }
  }

  /// Drives the snapshot-starvation watchdog (network doc § 6). The
  /// widget shell calls this from a real timer; logic stays pure.
  void onWatchdogTick() {
    if (!_matchActive || _state is! NetJoined || _unstable) {
      return;
    }
    final elapsed = _clock() - _lastSnapshotAt;
    if (elapsed >= snapshotStarvationTimeout) {
      _unstable = true;
      _log.warn(
        'snapshot starvation: ${elapsed.inMilliseconds}ms without a '
        'snapshot during an active match',
      );
      _emitStatus();
    }
  }

  /// User-initiated clean close: terminal `closed`, no reconnect.
  Future<void> close() async {
    _generation++;
    _backgrounded = false;
    _intentionalClose = true;
    _completeRejoinWaiter();
    _teardownConnection();
    _matchActive = false;
    _unstable = false;
    _setState(const NetClosed(needsManualRejoin: false));
  }

  /// Tears down the client including all streams.
  Future<void> dispose() async {
    await close();
    await _statusController.close();
    await _snapshotsController.close();
    await _gameSnapshotsController.close();
    await _roundStartingController.close();
    await _resultsController.close();
    await _roomClosedController.close();
    await _noticesController.close();
    await _memberInputsController.close();
  }

  /// Opens the next connection, sends `Hello` (and `RejoinRoom` when
  /// [rejoinCode] is set). Returns false when the factory failed; the
  /// caller decides about retries.
  Future<bool> _openConnection({required String? rejoinCode}) async {
    final uri = _uri;
    final playerId = _playerId;
    final nickname = _nickname;
    if (uri == null || playerId == null || nickname == null) {
      return false;
    }
    Connection connection;
    try {
      connection = await _factory(uri);
    } on Object catch (error, stack) {
      _lastError = 'connect failed: $error';
      _log.error('connection attempt failed', error, stack);
      _emitStatus();
      return false;
    }
    _connection = connection;
    _intentionalClose = false;
    _inputSeq = 0;
    _lastAppliedTick = null;
    _lastPingSentAt = null;
    if (rejoinCode != null) {
      _rejoinWaiter = Completer<void>();
      _rejoinSucceeded = false;
    }
    _subscription = connection.incoming.listen(
      _onData,
      onError: (Object error, StackTrace stack) {
        // Contract says incoming never errors; treat a violation as a
        // dead transport rather than crashing (network doc § 9).
        _log.error('incoming stream errored', error, stack);
        _onConnectionLost();
      },
      onDone: _onConnectionLost,
    );
    _send(
      Hello(
        protocolVersion: protocolVersion,
        playerId: playerId,
        nickname: nickname,
      ),
    );
    if (rejoinCode != null) {
      _send(RejoinRoom(code: rejoinCode));
    }
    return true;
  }

  Future<void> _reconnect() async {
    final gen = ++_generation;
    final roomCode = _lastRoomCode;
    for (var attempt = 1; attempt <= maxReconnectAttempts; attempt++) {
      _setState(NetReconnecting(roomCode: roomCode, attempt: attempt));
      try {
        await _backoff(attempt);
      } on Object catch (error, stack) {
        _log.error('backoff failed', error, stack);
      }
      if (gen != _generation) {
        return;
      }
      final opened = await _openConnection(rejoinCode: roomCode);
      if (gen != _generation) {
        return;
      }
      if (!opened) {
        continue;
      }
      if (roomCode == null) {
        _setState(const NetConnected());
        return;
      }
      final waiter = _rejoinWaiter;
      if (waiter != null) {
        // Resolved by the RoomSnapshot handler (success) or by
        // connection loss (retry below / superseded loop).
        await waiter.future;
      }
      if (gen != _generation) {
        return;
      }
      if (_rejoinSucceeded) {
        return;
      }
    }
    _setState(NetClosed(needsManualRejoin: roomCode != null));
  }

  void _onData(String data) {
    final WireMessage message;
    try {
      message = decode(data);
    } on ProtocolException catch (error) {
      _log.warn('dropped malformed frame: $error');
      return;
    } on Object catch (error, stack) {
      _log.error('unexpected decode failure; transport suspect', error, stack);
      _handleTransportFailure();
      return;
    }
    switch (message) {
      case final RoomSnapshot snapshot:
        _handleRoomSnapshot(snapshot);
      case final Snapshot snapshot:
        _handleGameSnapshot(snapshot);
      case final RoundStarting starting:
        _roundStartingController.add(starting);
        _matchActive = true;
        _lastSnapshotAt = _clock();
      case final RoundResultsMessage result:
        _resultsController.add(result);
        _matchActive = false;
      case final RoomClosed closed:
        _handleRoomClosed(closed);
      case final VersionMismatch mismatch:
        _intentionalClose = true;
        _setState(NetVersionMismatch(status: mismatch.status));
        _teardownConnection();
      case Pong():
        if (_lastPingSentAt != null) {
          _pingRtt = _clock() - _lastPingSentAt!;
          _emitStatus();
        }
      case final PlayerInputMessage input:
        _memberInputsController.add(input);
      case RateLimited() || AlreadyConnected() || ServerFull():
        _noticesController.add(message);
      default:
        _log.warn(
          'dropped ${message.runtimeType}: not a client-facing message',
        );
    }
  }

  void _handleRoomSnapshot(RoomSnapshot snapshot) {
    _snapshotsController.add(snapshot);
    _lastRoomCode = snapshot.code;
    _matchActive = snapshot.phase == RoundPhase.roundPlay;
    _setState(NetJoined(roomCode: snapshot.code));
    if (_rejoinWaiter != null && !_rejoinSucceeded) {
      _rejoinSucceeded = true;
      _completeRejoinWaiter();
    }
  }

  void _handleGameSnapshot(Snapshot snapshot) {
    final lastApplied = _lastAppliedTick;
    if (lastApplied != null && snapshot.tick <= lastApplied) {
      _log.warn(
        'dropped stale snapshot tick ${snapshot.tick} '
        '(last applied: $lastApplied)',
      );
      return;
    }
    _lastAppliedTick = snapshot.tick;
    _lastSnapshotAt = _clock();
    _matchActive = true;
    if (_unstable) {
      _unstable = false;
      _log.info('snapshot flow recovered at tick ${snapshot.tick}');
      _emitStatus();
    }
    _gameSnapshotsController.add(snapshot);
  }

  void _handleRoomClosed(RoomClosed closed) {
    _roomClosedController.add(closed);
    _intentionalClose = true;
    _completeRejoinWaiter();
    _teardownConnection();
    _matchActive = false;
    _unstable = false;
    _setState(
      NetClosed(needsManualRejoin: false, roomCloseReason: closed.reason),
    );
  }

  /// Sink errors are logged and fed into the reconnect path — never
  /// fire-and-forget, never thrown to the caller (network doc § 9).
  void _send(WireMessage message) {
    final connection = _connection;
    if (connection == null) {
      _log.warn('send of ${message.runtimeType} with no connection');
      return;
    }
    try {
      connection.send(encode(message));
    } on Object catch (error, stack) {
      _lastError = 'send failed: $error';
      _log.error('send of ${message.runtimeType} failed', error, stack);
      _handleTransportFailure();
    }
  }

  void _handleTransportFailure() {
    if (_state is NetClosed || _state is NetVersionMismatch) {
      return;
    }
    _generation++;
    _completeRejoinWaiter();
    _teardownConnection();
    _setState(NetDisconnected(lastError: _lastError));
    _scheduleReconnect();
  }

  void _onConnectionLost() {
    if (_rejoinWaiter != null && !_rejoinWaiter!.isCompleted) {
      // Wake the parked reconnect loop; the fresh loop below takes over.
      _rejoinWaiter!.complete();
    }
    _teardownConnection();
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_intentionalClose || _backgrounded) {
      return;
    }
    if (_state is NetClosed || _state is NetVersionMismatch) {
      return;
    }
    // The loop logs its own failures and always terminates (bounded
    // attempts), so its future needs no further handling here.
    unawaited(_reconnect());
  }

  void _teardownConnection() {
    final subscription = _subscription;
    _subscription = null;
    if (subscription != null) {
      unawaited(
        subscription.cancel().catchError((Object error) {
          _log.warn('subscription cancel failed: $error');
        }),
      );
    }
    final connection = _connection;
    _connection = null;
    if (connection != null) {
      unawaited(
        connection.close().then(
          (_) {},
          onError: (Object error) {
            _log.warn('connection close failed: $error');
          },
        ),
      );
    }
  }

  void _completeRejoinWaiter() {
    final waiter = _rejoinWaiter;
    _rejoinWaiter = null;
    if (waiter != null && !waiter.isCompleted) {
      waiter.complete();
    }
  }

  bool _requireConnected(String operation) {
    if (_state is! NetConnected && _state is! NetJoined) {
      _log.warn('$operation ignored: not connected');
      return false;
    }
    return true;
  }

  bool _requireRoom(String operation) {
    if (_state is! NetJoined) {
      _log.warn('$operation ignored: not in a room');
      return false;
    }
    return true;
  }

  void _setState(NetConnectionState next) {
    _state = next;
    _emitStatus();
  }

  void _emitStatus() {
    _statusController.add(status);
  }
}
