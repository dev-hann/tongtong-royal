import 'package:app/design/tokens.dart';
import 'package:app/design/widgets/ttr_ambient_backdrop.dart';
import 'package:app/design/widgets/ttr_button.dart';
import 'package:flutter/material.dart';

/// Presentation-level home screen (not a domain round phase): shown
/// until a match starts and re-entered from the podium's exit.
///
/// Pure renderer: buttons only forward taps; no game state here.
class HomeScreen extends StatelessWidget {
  /// Creates the home screen.
  const HomeScreen({this.onPlaySolo, super.key});

  /// Key of the PLAY SOLO button (for tests and integration finds).
  static const Key playSoloButtonKey = Key('home_play_solo_button');

  /// Key of the PLAY FRIENDS button (for tests and integration finds).
  static const Key playFriendsButtonKey = Key('home_play_friends_button');

  /// Fired when the player starts a solo match vs bots.
  final VoidCallback? onPlaySolo;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const TtrAmbientBackdrop(),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'TONGTONG',
                style: TextStyle(
                  fontSize: TypeScale.displaySize,
                  fontWeight: FontWeight.w800,
                  color: ColorPalette.primary,
                ),
              ),
              const Text(
                'ROYAL',
                style: TextStyle(
                  fontSize: TypeScale.displaySize,
                  fontWeight: FontWeight.w800,
                  color: ColorPalette.secondary,
                ),
              ),
              const SizedBox(height: SpacingScale.sm),
              const Text(
                'One button. Total chaos.',
                style: TextStyle(
                  fontSize: TypeScale.bodySize,
                  fontWeight: FontWeight.w400,
                  color: ColorPalette.neutral500,
                ),
              ),
              const SizedBox(height: SpacingScale.xxxl),
              TtrButton(
                key: playSoloButtonKey,
                label: 'PLAY SOLO',
                size: TtrButtonSize.large,
                onPressed: onPlaySolo,
              ),
              const SizedBox(height: SpacingScale.md),
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TtrButton(
                    key: playFriendsButtonKey,
                    label: 'PLAY FRIENDS',
                    variant: TtrButtonVariant.secondary,
                  ),
                  SizedBox(width: SpacingScale.sm),
                  _ComingSoonChip(),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ComingSoonChip extends StatelessWidget {
  const _ComingSoonChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SpacingScale.sm,
        vertical: SpacingScale.xs / 2,
      ),
      decoration: BoxDecoration(
        color: ColorPalette.neutral200,
        borderRadius: BorderRadius.circular(RadiusScale.chip),
      ),
      child: const Text(
        'Coming soon',
        style: TextStyle(
          fontSize: TypeScale.labelSize,
          fontWeight: FontWeight.w600,
          color: ColorPalette.neutral700,
        ),
      ),
    );
  }
}
