import 'package:app/design/tokens.dart';
import 'package:app/profile/profile_controller.dart';
import 'package:flutter/material.dart';

/// Shared nickname input for the identity forms (profile +
/// onboarding). One implementation per the Form Law (guide § 6) —
/// the two screens must not drift apart again.
class TtrNicknameField extends StatelessWidget {
  /// Creates the nickname field.
  const TtrNicknameField({
    required this.controller,
    required this.invalid,
    required this.onSubmitted,
    super.key,
  });

  /// Controls the editable text.
  final TextEditingController controller;

  /// Whether the current value failed validation (shows error text).
  final bool invalid;

  /// Invoked on IME submit.
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onSubmitted: onSubmitted,
      maxLength: ProfileController.maxNicknameLength + 8,
      textAlign: TextAlign.center,
      // Nicknames are names, not words — platform spell-check red
      // squiggles under them are noise (ux-checklist).
      spellCheckConfiguration: const SpellCheckConfiguration.disabled(),
      style: TypeScale.title,
      decoration: InputDecoration(
        labelText: 'NICKNAME',
        labelStyle: TypeScale.bodyLabel,
        helperText: '1-12 characters',
        helperStyle: TypeScale.body.copyWith(color: ColorPalette.neutral500),
        errorText: invalid ? '1-12 characters after trimming' : null,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(RadiusScale.button),
          borderSide: const BorderSide(
            color: ColorPalette.neutral200,
            width: SpacingScale.xs,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(RadiusScale.button),
          borderSide: const BorderSide(
            color: ColorPalette.primary,
            width: SpacingScale.xs,
          ),
        ),
      ),
    );
  }
}

/// Shared avatar circle (player color + first letter) for the
/// identity forms (guide § 6; size from [ComponentSizes.avatar]).
class TtrAvatar extends StatelessWidget {
  /// Creates the avatar.
  const TtrAvatar({
    required this.colorIndex,
    required this.nickname,
    this.avatarKey,
    super.key,
  });

  /// Palette index of the player color.
  final int colorIndex;

  /// Displayed nickname (first letter shown in the circle).
  final String nickname;

  /// Key applied to the circle itself (tests/automation find the
  /// sized circle, not the full-width wrapper).
  final Key? avatarKey;

  @override
  Widget build(BuildContext context) {
    // Centered so FORM card groups (stretch children) cannot widen
    // the circle — the token size is law (guide § 6).
    return Center(
      child: Container(
        key: avatarKey,
        width: ComponentSizes.avatar,
        height: ComponentSizes.avatar,
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
    );
  }
}
