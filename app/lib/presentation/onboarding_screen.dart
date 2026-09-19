import 'package:app/design/tokens.dart';
import 'package:app/design/widgets/ttr_button.dart';
import 'package:app/design/widgets/ttr_card_group.dart';
import 'package:app/design/widgets/ttr_color_swatch.dart';
import 'package:app/design/widgets/ttr_identity_fields.dart';
import 'package:app/design/widgets/ttr_page_header.dart';
import 'package:app/design/widgets/ttr_page_shell.dart';
import 'package:app/infra/profile_store.dart';
import 'package:app/profile/profile_controller.dart';
import 'package:flutter/material.dart';

/// First-launch profile setup (GDD § 8.1): nickname + color + START.
///
/// Shown once — the shell gates on `controller.needsOnboarding`;
/// after START completes the onboarded flag is persisted and the
/// screen never appears again. Guide § 6 FORM skeleton: backless
/// `TtrPageHeader` carrying SKIP in the trailing slot, over one
/// scroll of `TtrCardGroup` sections — IDENTITY (avatar + nickname
/// field + full-width START) and COLOR (palette).
class OnboardingScreen extends StatefulWidget {
  /// Creates the onboarding screen.
  const OnboardingScreen({
    required this.controller,
    required this.onStart,
    required this.onSkip,
    super.key,
  });

  /// Key of the nickname field (tests).
  static const Key nicknameFieldKey = Key('onboarding_nickname_field');

  /// Key of the START button (tests).
  static const Key startButtonKey = Key('onboarding_start_button');

  /// Key of the SKIP button (tests).
  static const Key skipButtonKey = Key('onboarding_skip_button');

  /// Key prefix of palette swatches: `onboarding_swatch_$i`.
  static const String swatchKeyPrefix = 'onboarding_swatch_';

  /// Owns the persisted profile state.
  final ProfileController controller;

  /// Fired after the profile was saved and onboarding completed.
  final VoidCallback onStart;

  /// Fired when the player skips setup: the default profile (PLAYER,
  /// color 0) stays stored and remains editable via Profile later.
  final VoidCallback onSkip;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  // First launch: the stored value is the default nickname, so the
  // field starts empty; an edited profile re-fills its nickname.
  late final TextEditingController _nickname = TextEditingController(
    text: widget.controller.profile.nickname == Profile.defaultNickname
        ? ''
        : widget.controller.profile.nickname,
  );
  bool _invalid = false;

  @override
  void dispose() {
    _nickname.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final accepted = await widget.controller.setNickname(_nickname.text);
    if (!mounted) {
      return;
    }
    if (!accepted) {
      setState(() => _invalid = true);
      return;
    }
    await widget.controller.completeOnboarding();
    if (!mounted) {
      return;
    }
    widget.onStart();
  }

  /// SKIP (GDD § 8.1): completes onboarding storing the untouched
  /// defaults — typed-but-unsaved input is discarded.
  Future<void> _skip() async {
    await widget.controller.completeOnboarding();
    if (!mounted) {
      return;
    }
    widget.onSkip();
  }

  @override
  Widget build(BuildContext context) {
    return TtrPageShell(
      child: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          final profile = widget.controller.profile;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TtrPageHeader(
                title: 'WELCOME',
                showBack: false,
                trailing: TextButton(
                  key: OnboardingScreen.skipButtonKey,
                  onPressed: _skip,
                  style: TextButton.styleFrom(
                    foregroundColor: ColorPalette.neutral700,
                    textStyle: TypeScale.label,
                  ),
                  child: const Text('SKIP'),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(SpacingScale.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TtrCardGroup(
                        label: 'IDENTITY',
                        staggerIndex: 0,
                        children: [
                          Text(
                            'Pick your name and color.',
                            style: TypeScale.body.copyWith(
                              color: ColorPalette.neutral500,
                            ),
                          ),
                          TtrAvatar(
                            colorIndex: profile.colorIndex,
                            nickname: profile.nickname,
                          ),
                          TtrNicknameField(
                            key: OnboardingScreen.nicknameFieldKey,
                            controller: _nickname,
                            invalid: _invalid,
                            onSubmitted: (_) => _start(),
                          ),
                          TtrButton(
                            key: OnboardingScreen.startButtonKey,
                            label: 'START',
                            size: TtrButtonSize.large,
                            onPressed: _start,
                          ),
                        ],
                      ),
                      const SizedBox(height: SpacingScale.xl),
                      TtrCardGroup(
                        label: 'COLOR',
                        staggerIndex: 1,
                        children: [
                          _PaletteGrid(
                            selectedIndex: profile.colorIndex,
                            onSelect: widget.controller.selectColor,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PaletteGrid extends StatelessWidget {
  const _PaletteGrid({required this.selectedIndex, required this.onSelect});

  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final (index, color) in PlayerPalette.all.indexed)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: SpacingScale.sm),
            child: TtrColorSwatch(
              key: ValueKey<String>(
                '${OnboardingScreen.swatchKeyPrefix}$index',
              ),
              color: color,
              selected: index == selectedIndex,
              onTap: () => onSelect(index),
            ),
          ),
      ],
    );
  }
}
