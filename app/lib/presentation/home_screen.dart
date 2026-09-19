import 'package:app/design/tokens.dart';
import 'package:app/design/ttr_icons.dart';
import 'package:app/design/widgets/ttr_ambient_backdrop.dart';
import 'package:app/design/widgets/ttr_button.dart';
import 'package:flutter/material.dart';

/// Presentation-level home screen (not a domain round phase): shown
/// until a match starts and re-entered from the results screen's
/// HOME button.
///
/// Pure renderer: buttons only forward taps; no game state here.
/// Entry points (guide § 6): profile avatar top-left, settings gear
/// top-right — both inside the SafeArea'd column over the backdrop.
class HomeScreen extends StatelessWidget {
  /// Creates the home screen.
  const HomeScreen({
    this.onPlaySolo,
    this.onOpenProfile,
    this.onOpenSettings,
    this.nickname = 'PLAYER',
    this.colorIndex = 0,
    super.key,
  });

  /// Key of the PLAY SOLO button (for tests and integration finds).
  static const Key playSoloButtonKey = Key('home_play_solo_button');

  /// Key of the PLAY FRIENDS button (for tests and integration finds).
  static const Key playFriendsButtonKey = Key('home_play_friends_button');

  /// Key of the top-left profile avatar entry (tests).
  static const Key profileButtonKey = Key('home_profile_button');

  /// Key of the top-right settings gear entry (tests).
  static const Key settingsButtonKey = Key('home_settings_button');

  /// Fired when the player starts a solo match vs bots.
  final VoidCallback? onPlaySolo;

  /// Fired when the player opens the profile screen.
  final VoidCallback? onOpenProfile;

  /// Fired when the player opens the settings screen.
  final VoidCallback? onOpenSettings;

  /// Local player nickname (avatar label source).
  final String nickname;

  /// Local player [PlayerPalette] index (avatar color source).
  final int colorIndex;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Backdrop bleeds edge-to-edge; content stays inside the
        // safe area (design guide § 8 — display cutouts).
        const TtrAmbientBackdrop(),
        SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(SpacingScale.lg),
                child: Row(
                  children: [
                    _ProfileEntryButton(
                      key: HomeScreen.profileButtonKey,
                      nickname: nickname,
                      colorIndex: colorIndex,
                      onTap: onOpenProfile,
                    ),
                    const Spacer(),
                    IconButton(
                      key: settingsButtonKey,
                      onPressed: onOpenSettings,
                      icon: const Icon(
                        TtrIcons.gear,
                        color: ColorPalette.neutral700,
                        size: ComponentSizes.homeEntryIcon,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'TONGTONG',
                        style: TypeScale.display.copyWith(
                          color: ColorPalette.primary,
                        ),
                      ),
                      Text(
                        'ROYAL',
                        style: TypeScale.display.copyWith(
                          color: ColorPalette.secondary,
                        ),
                      ),
                      const SizedBox(height: SpacingScale.sm),
                      Text(
                        'One button. Total chaos.',
                        style: TypeScale.body.copyWith(
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
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Circular avatar entry (guide § 6): player color block with the
/// nickname's first letter; 56px touch target (guide § 8).
class _ProfileEntryButton extends StatelessWidget {
  const _ProfileEntryButton({
    required this.nickname,
    required this.colorIndex,
    required this.onTap,
    super.key,
  });

  final String nickname;
  final int colorIndex;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: ComponentSizes.homeEntry,
          height: ComponentSizes.homeEntry,
          decoration: BoxDecoration(
            color: PlayerPalette.forIndex(colorIndex),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              nickname.isEmpty ? '?' : nickname.characters.first.toUpperCase(),
              style: TypeScale.title.copyWith(color: ColorPalette.onPrimary),
            ),
          ),
        ),
      ),
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
      child: Text(
        'Coming soon',
        style: TypeScale.bodyLabel.copyWith(color: ColorPalette.neutral700),
      ),
    );
  }
}
