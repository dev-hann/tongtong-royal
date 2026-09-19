import 'dart:async' show unawaited;

import 'package:app/app_config.dart';
import 'package:app/design/tokens.dart';
import 'package:app/design/ttr_icons.dart';
import 'package:app/design/widgets/ttr_card_group.dart';
import 'package:app/design/widgets/ttr_page_header.dart';
import 'package:app/design/widgets/ttr_page_shell.dart';
import 'package:app/design/widgets/ttr_settings_row.dart';
import 'package:app/design/widgets/ttr_switch.dart';
import 'package:app/presentation/credits_screen.dart';
import 'package:app/profile/profile_controller.dart';
import 'package:flutter/material.dart';

/// Settings screen (GDD § 8.1, guide § 6 FORM): fixed `TtrPageHeader`
/// over card groups — GENERAL (sound toggle, active = primary) and
/// ABOUT (credits row) — with the version footer pinned below the
/// scroll. All state lives in [controller]; this widget only renders
/// and forwards taps.
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
    return TtrPageShell(
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const TtrPageHeader(title: 'SETTINGS'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(SpacingScale.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TtrCardGroup(
                      label: 'GENERAL',
                      staggerIndex: 0,
                      children: [
                        TtrSettingsRow(
                          leading: TtrIcons.speakerHigh,
                          title: 'Sound',
                          subtitle: 'Sound effects and music',
                          trailing: TtrSwitch(
                            key: soundToggleKey,
                            value: controller.soundEnabled,
                            onChanged: (value) =>
                                // Local-only persistence; UI flipped.
                                unawaited(
                                  controller.setSoundEnabled(value: value),
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: SpacingScale.xl),
                    TtrCardGroup(
                      label: 'ABOUT',
                      staggerIndex: 1,
                      children: [
                        TtrSettingsRow(
                          key: creditsRowKey,
                          leading: TtrIcons.bookOpen,
                          title: 'Credits',
                          subtitle: 'Fonts and asset attribution',
                          trailing: const Icon(
                            TtrIcons.caretRight,
                            color: ColorPalette.neutral500,
                          ),
                          onTap: () => _openCredits(context),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
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
    );
  }

  void _openCredits(BuildContext context) {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const CreditsScreen()));
  }
}
