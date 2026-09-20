import 'package:app/show/show_config.dart';
import 'package:app/show/show_controller.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

/// Intro-banner and HUD view data exposed additively on
/// [ShowController] (kept here so the controller file stays within
/// the repo line limit — solo_standings precedent).
extension ShowControllerViewData on ShowController {
  /// Seat lookup by player id.
  ShowSeat seatOf(PlayerId id) =>
      seats.firstWhere((seat) => seat.id == id);

  /// Display name for the upcoming round's game banner.
  String get introGameName {
    final slot = schedule.slotFor(roundIndex);
    return slot.isFinal
        ? showFinalGameName
        : registry.byId(slot.gameId).spec.name;
  }

  /// Rule line for the upcoming round's game banner.
  String get introRuleLine {
    final slot = schedule.slotFor(roundIndex);
    return slot.isFinal
        ? showFinalRuleLine
        : registry.byId(slot.gameId).spec.oneLineRule;
  }

  /// Quota counter context: the quota of the flashed round.
  int get verdictQuota => schedule.slotFor(verdictRoundIndex).quota;

  /// Seconds left in the running round, from the driver's timeout
  /// budget (`timeoutTicks - tickCount` at the fixed rate); null
  /// outside ROUND_PLAY.
  int? get remainingSeconds {
    final driver = currentRound?.driver;
    if (driver == null) {
      return null;
    }
    final left = (driver.timeoutTicks - driver.tickCount).clamp(
      0,
      driver.timeoutTicks,
    );
    return (left * PhysicsConsts.fixedDt).ceil();
  }
}
