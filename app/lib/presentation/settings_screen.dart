import 'dart:async' show unawaited;

import 'package:app/app_config.dart';
import 'package:app/design/tokens.dart';
import 'package:app/design/widgets/ttr_ambient_backdrop.dart';
import 'package:app/presentation/credits_screen.dart';
import 'package:app/profile/profile_controller.dart';
import 'package:flutter/material.dart';

/// Settings screen (GDD § 8.1, guide § 6): grouped list with the
/// sound toggle (active = primary), a credits row and the version
/// footer. All state lives in [controller]; this widget only
/// renders and forwards taps.
class SettingsScreen extends StatelessWidget {
  /// Creates the settings screen.
  const SettingsScreen({required this.controller, super.key});

  /// Key of the sound toggle (tests).
  static const Key soundToggleKey = Key('settings_sound_toggle');

  /// Key of the credits row (tests).
  static const Key creditsRowKey = Key('settings_credits_row');

  /// Owns the persisted settings state.
  final ProfileController controller;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const TtrAmbientBackdrop(),
        SafeArea(
          child: ListenableBuilder(
            listenable: controller,
            builder: (context, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.all(SpacingScale.lg),
                  child: Text(
                    'SETTINGS',
                    style: TypeScale.title,
                    textAlign: TextAlign.center,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: SpacingScale.xl,
                  ),
                  child: Material(
                    color: ColorPalette.surface,
                    borderRadius: BorderRadius.circular(RadiusScale.card),
                    clipBehavior: Clip.antiAlias,
                    child: SwitchListTile(
                      key: soundToggleKey,
                      value: controller.soundEnabled,
                      onChanged: (value) =>
                          unawaited(controller.setSoundEnabled(value: value)),
                      title: const Text('Sound', style: TypeScale.bodyEmphasis),
                      subtitle: Text(
                        'Sound effects and music',
                        style: TypeScale.body.copyWith(
                          color: ColorPalette.neutral500,
                        ),
                      ),
                      activeTrackColor: ColorPalette.primary,
                      inactiveTrackColor: ColorPalette.neutral200,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: SpacingScale.xl,
                    vertical: SpacingScale.md,
                  ),
                  child: Material(
                    color: ColorPalette.surface,
                    borderRadius: BorderRadius.circular(RadiusScale.card),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      key: creditsRowKey,
                      leading: const Icon(
                        Icons.menu_book,
                        color: ColorPalette.neutral700,
                      ),
                      title: const Text(
                        'Credits',
                        style: TypeScale.bodyEmphasis,
                      ),
                      subtitle: Text(
                        'Fonts and asset attribution',
                        style: TypeScale.body.copyWith(
                          color: ColorPalette.neutral500,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.chevron_right,
                        color: ColorPalette.neutral500,
                      ),
                      onTap: () => _openCredits(context),
                    ),
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(bottom: SpacingScale.lg),
                  child: Text(
                    'v$appVersion',
                    style: TypeScale.bodyLabel.copyWith(
                      color: ColorPalette.neutral500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _openCredits(BuildContext context) {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const CreditsScreen()));
  }
}
