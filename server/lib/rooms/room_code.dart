import 'dart:math';

/// Alphabet for invite codes: uppercase alphanumeric minus the visually
/// ambiguous `0`, `O`, `1`, `I` (network doc § 8).
const String roomCodeAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

/// Number of characters in an invite code (network doc § 8).
const int roomCodeLength = 6;

/// Generates one invite code from [random].
///
/// Pure function: no server state is consulted. Collision handling
/// (regenerating until the code is unused) is owned by
/// `RoomManager.createRoom`, which knows the live-code set.
String generateRoomCode(Random random) {
  final buffer = StringBuffer();
  for (var i = 0; i < roomCodeLength; i++) {
    buffer.write(roomCodeAlphabet[random.nextInt(roomCodeAlphabet.length)]);
  }
  return buffer.toString();
}
