/// Protocol versioning for the TongTong Royal wire protocol
/// (architecture doc § 7).
///
/// The server supports the current version N and one previous version N-1.
/// Breaking message-format changes must bump [protocolVersion].
const int protocolVersion = 1;

/// Outcome of comparing a client's declared version against the server's
/// supported range.
enum VersionStatus {
  /// Client version is N or N-1; handshake proceeds.
  ok,

  /// Client is older than N-1; client must update.
  clientTooOld,

  /// Client is newer than N; server must be updated.
  serverTooOld,
}

/// Checks [clientVersion] from the server's perspective:
/// N or N-1 → [VersionStatus.ok], below N-1 → [VersionStatus.clientTooOld],
/// above N → [VersionStatus.serverTooOld].
VersionStatus checkVersion(int clientVersion) {
  if (clientVersion > protocolVersion) {
    return VersionStatus.serverTooOld;
  }
  if (clientVersion < protocolVersion - 1) {
    return VersionStatus.clientTooOld;
  }
  return VersionStatus.ok;
}
