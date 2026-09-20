// Part of the show controller (same library): the shell-facing
// command surface — start, rematch, exit, abandon and flash skip.
// Split out so the controller file stays within the repo line limit
// (docs/05 § 2); extensions in parts see the library's privates.
part of 'show_controller.dart';

/// Shell-facing commands (start / rematch / exit / abandon / skip).
/// An extension in a part of the controller's library: the bodies
/// touch the controller's private flow state directly.
extension ShowControllerCommands on ShowController {
  /// LOBBY -> SHOW_INTRO: opens the show (fresh seed, clean slate —
  /// any stale outcome from a previous show is discarded).
  void startShow() {
    if (_machine.phase != ShowPhase.lobby) {
      return;
    }
    if (_verdict != null || _summary != null || _champions != null) {
      _clearShowOutcome();
    }
    _showSeed = showSeedFactory();
    _machine.startShow();
    _beginIntro();
  }

  /// PODIUM or elimination summary -> fresh show (new seed, fresh
  /// field; GDD v2 § 1 PLAY AGAIN).
  void playAgain() {
    if (_machine.phase == ShowPhase.podium) {
      _machine.toLobby();
    } else if (_machine.phase != ShowPhase.lobby || _summary == null) {
      return;
    }
    _clearShowOutcome();
    _showSeed = showSeedFactory();
    _machine.startShow();
    _beginIntro();
  }

  /// PODIUM or elimination summary -> LOBBY for the home screen
  /// (GDD v2 § 1 HOME).
  void exitToHome() {
    if (_machine.phase == ShowPhase.podium) {
      _machine.toLobby();
    } else if (_machine.phase != ShowPhase.lobby || _summary == null) {
      return;
    }
    _clearShowOutcome();
  }

  /// In-show phases -> LOBBY with nothing recorded (GDD v2 § 7.4
  /// abandon): releases the running round and resets the outcome
  /// state. A no-op when nothing is at stake (LOBBY/PODIUM).
  void abandonShow() {
    if (_machine.phase != ShowPhase.showIntro &&
        _machine.phase != ShowPhase.roundPlay &&
        _machine.phase != ShowPhase.qualifyFlash) {
      return;
    }
    _releaseRound();
    _machine.abandon();
    _clearShowOutcome();
  }

  /// Skips the remaining QUALIFY_FLASH wait (back gesture on a
  /// FINAL or an eliminated-human flash — ux-checklist back
  /// matrix). A no-op outside the flash.
  void skipFlash() {
    if (_machine.phase != ShowPhase.qualifyFlash) {
      return;
    }
    _advanceAfterFlash();
  }
}
