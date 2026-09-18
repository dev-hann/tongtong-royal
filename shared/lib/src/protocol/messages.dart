/// Sealed base type for every message that crosses the WebSocket wire.
///
/// All concrete message classes live in the parts `client_messages.dart`
/// (client → server) and `server_messages.dart` (server → client). The
/// envelope codec is `codec.dart`.
library;

import 'package:meta/meta.dart';
import 'package:tongtong_shared/src/domain/models.dart';
import 'package:tongtong_shared/src/domain/round_state_machine.dart';
import 'package:tongtong_shared/src/protocol/protocol_version.dart';

part 'client_messages.dart';
part 'server_messages.dart';

/// Base class of every typed wire message (network doc § 9: typed models
/// only, no hand-rolled JSON).
@immutable
sealed class WireMessage {
  const WireMessage();

  /// Payload of the envelope; the codec adds `{"t": tag, "v": <this>}`.
  Map<String, Object?> toJson();
}
