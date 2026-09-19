import 'package:app/design/tokens.dart';
import 'package:app/design/widgets/ttr_button.dart';
import 'package:app/design/widgets/ttr_color_swatch.dart';
import 'package:app/design/widgets/ttr_page_shell.dart';
import 'package:app/infra/profile_store.dart';
import 'package:app/profile/profile_controller.dart';
import 'package:flutter/material.dart';

/// First-launch profile setup (GDD § 8.1): nickname + color + START.
///
/// Shown once — the shell gates on `controller.needsOnboarding`;
/// after START completes the onboarded flag is persisted and the
/// screen never appears again. Same building blocks as the profile
/// screen (guide § 6), condensed to one column.
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
      child: Stack(
        children: [
          ListenableBuilder(
            listenable: widget.controller,
            builder: (context, _) {
              final profile = widget.controller.profile;
              return SingleChildScrollView(
                padding: const EdgeInsets.all(SpacingScale.xl),
                child: Column(
                  children: [
                    Text(
                      'WELCOME',
                      style: TypeScale.title.copyWith(
                        color: ColorPalette.primary,
                      ),
                    ),
                    const SizedBox(height: SpacingScale.sm),
                    Text(
                      'Pick your name and color.',
                      style: TypeScale.body.copyWith(
                        color: ColorPalette.neutral500,
                      ),
                    ),
                    const SizedBox(height: SpacingScale.xl),
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: PlayerPalette.forIndex(profile.colorIndex),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          profile.nickname.isEmpty
                              ? '?'
                              : profile.nickname.characters.first.toUpperCase(),
                          style: TypeScale.title.copyWith(
                            color: ColorPalette.onPrimary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: SpacingScale.xl),
                    TextField(
                      key: OnboardingScreen.nicknameFieldKey,
                      controller: _nickname,
                      onSubmitted: (_) => _start(),
                      maxLength: 20,
                      textAlign: TextAlign.center,
                      // Nicknames are names, not words — no spell-check
                      // squiggles (ux-checklist).
                      spellCheckConfiguration:
                          const SpellCheckConfiguration.disabled(),
                      style: TypeScale.title,
                      decoration: InputDecoration(
                        labelText: 'NICKNAME',
                        labelStyle: TypeScale.bodyLabel,
                        helperText: '1-12 characters',
                        helperStyle: TypeScale.body.copyWith(
                          color: ColorPalette.neutral500,
                        ),
                        errorText: _invalid
                            ? '1-12 characters after trimming'
                            : null,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            RadiusScale.button,
                          ),
                          borderSide: const BorderSide(
                            color: ColorPalette.neutral200,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            RadiusScale.button,
                          ),
                          borderSide: const BorderSide(
                            color: ColorPalette.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: SpacingScale.xl),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (final (index, color) in PlayerPalette.all.indexed)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: SpacingScale.sm,
                            ),
                            child: TtrColorSwatch(
                              key: ValueKey<String>(
                                '${OnboardingScreen.swatchKeyPrefix}$index',
                              ),
                              color: color,
                              selected: index == profile.colorIndex,
                              onTap: () => widget.controller.selectColor(index),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: SpacingScale.xxxl),
                    TtrButton(
                      key: OnboardingScreen.startButtonKey,
                      label: 'START',
                      size: TtrButtonSize.large,
                      onPressed: _start,
                    ),
                  ],
                ),
              );
            },
          ),
          // Secondary text affordance pinned to the top-right safe
          // corner (TtrPageShell SafeAreas the stack).
          Positioned(
            top: SpacingScale.sm,
            right: SpacingScale.sm,
            child: TextButton(
              key: OnboardingScreen.skipButtonKey,
              onPressed: _skip,
              style: TextButton.styleFrom(
                foregroundColor: ColorPalette.neutral700,
                textStyle: TypeScale.label,
              ),
              child: const Text('SKIP'),
            ),
          ),
        ],
      ),
    );
  }
}
