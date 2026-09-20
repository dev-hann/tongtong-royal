import 'package:app/design/tokens.dart';
import 'package:app/design/ttr_icons.dart';
import 'package:app/design/widgets/ttr_ambient_backdrop.dart';
import 'package:app/design/widgets/ttr_button.dart';
import 'package:app/design/widgets/ttr_pulse.dart';
import 'package:app/design/widgets/ttr_staggered_entrance.dart';
import 'package:flutter/material.dart';

/// One podium player (pure renderer input).
@immutable
final class PodiumPlayer {
  /// Creates a podium player.
  const PodiumPlayer({
    required this.playerId,
    required this.nickname,
    required this.color,
    this.isLocal = false,
  });

  /// Player id.
  final String playerId;

  /// Display nickname.
  final String nickname;

  /// Seat color (a [PlayerPalette] value).
  final Color color;

  /// Whether this is the local human.
  final bool isLocal;
}

/// PODIUM phase screen — the crown ceremony (GDD v2 § 5, FOCUSED
/// archetype): champion pedestal center-tall with the crown and the
/// screen's single pulse (guide § 4/§ 5); a shared crown (GDD v2
/// § 7.2) shows the co-champion pair side by side; `PLAY AGAIN`
/// primary + `HOME` secondary end the show.
///
/// Pure renderer: champions arrive pre-judged from the domain
/// verdict — no ranking logic here.
class PodiumScreen extends StatelessWidget {
  /// Creates the podium.
  const PodiumScreen({
    required this.champions,
    this.humanWon = false,
    this.onPlayAgain,
    this.onExitHome,
    super.key,
  });

  /// Key of the champion pedestal (tests and integration finds).
  static const Key championKey = Key('podium_champion');

  /// Key of the PLAY AGAIN button (tests and integration finds).
  static const Key playAgainButtonKey = Key('podium_play_again');

  /// Key of the HOME button (tests and integration finds).
  static const Key exitHomeButtonKey = Key('podium_exit_home');

  /// Crown winners — exactly one, or the shared pair (GDD v2 § 7.2).
  final List<PodiumPlayer> champions;

  /// Whether the local human holds the crown.
  final bool humanWon;

  /// Starts a fresh show (new seed, GDD v2 § 1 PLAY AGAIN).
  final VoidCallback? onPlayAgain;

  /// Returns to the home screen (GDD v2 § 1 HOME).
  final VoidCallback? onExitHome;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // System back on the terminal podium = HOME (ux-checklist back
      // matrix), never a silent app exit.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          onExitHome?.call();
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          const TtrAmbientBackdrop(),
          DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [ColorPalette.warningSoft, ColorPalette.background],
              ),
            ),
            child: SafeArea(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      humanWon ? 'VICTORY' : 'CROWN',
                      style: TypeScale.display.copyWith(
                        color: ColorPalette.neutral900,
                      ),
                    ),
                    const SizedBox(height: SpacingScale.xl),
                    if (champions.length == 1)
                      TtrStaggeredEntrance(
                        index: 0,
                        child: TtrPulse(
                          // The screen's ONE pulsing element (guide § 4).
                          child: _ChampionPedestal(
                            key: championKey,
                            player: champions.single,
                            shared: false,
                          ),
                        ),
                      )
                    else
                      TtrStaggeredEntrance(
                        index: 0,
                        child: TtrPulse(
                          // Shared crown: the PAIR pulses as one element.
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (final (index, player)
                                  in champions.indexed)
                                _ChampionPedestal(
                                  key: index == 0 ? championKey : null,
                                  player: player,
                                  shared: true,
                                ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: SpacingScale.xxxl),
                    TtrButton(
                      key: playAgainButtonKey,
                      label: 'PLAY AGAIN',
                      onPressed: onPlayAgain,
                    ),
                    const SizedBox(height: SpacingScale.md),
                    TtrButton(
                      key: exitHomeButtonKey,
                      label: 'HOME',
                      variant: TtrButtonVariant.secondary,
                      onPressed: onExitHome,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Champion pedestal: crown glyph, jelly-colored color block, and
/// the display-name plate (pulsing wrapped by the caller — guide § 4
/// one-pulse rule).
class _ChampionPedestal extends StatelessWidget {
  const _ChampionPedestal({
    required this.player,
    required this.shared,
    super.key,
  });

  final PodiumPlayer player;
  final bool shared;

  @override
  Widget build(BuildContext context) {
    return TtrPulse(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            TtrIcons.crown,
            color: ColorPalette.warning,
            size: ComponentSizes.heroIcon,
          ),
          const SizedBox(height: SpacingScale.sm),
          Container(
            width: shared ? ComponentSizes.homeEntry : ComponentSizes.avatar,
            height: shared ? ComponentSizes.homeEntry : ComponentSizes.avatar,
            decoration: BoxDecoration(
              color: player.color,
              shape: BoxShape.circle,
              border: player.isLocal
                  ? Border.all(color: PlayerPalette.localRing, width: 3)
                  : null,
            ),
          ),
          const SizedBox(height: SpacingScale.sm),
          Text(player.nickname, style: TypeScale.bodyEmphasis),
        ],
      ),
    );
  }
}
