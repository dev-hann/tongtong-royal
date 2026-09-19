import 'package:app/design/tokens.dart';
import 'package:app/design/widgets/ttr_button.dart';
import 'package:app/design/widgets/ttr_card_group.dart';
import 'package:app/design/widgets/ttr_color_swatch.dart';
import 'package:app/design/widgets/ttr_page_header.dart';
import 'package:app/design/widgets/ttr_page_shell.dart';
import 'package:app/presentation/profile_stats.dart';
import 'package:app/profile/profile_controller.dart';
import 'package:flutter/material.dart';

/// Profile screen (GDD § 8.1, guide § 6 FORM): fixed `TtrPageHeader`
/// over one scroll of `TtrCardGroup` sections — IDENTITY (avatar +
/// nickname field + full-width SAVE), COLOR (palette grid), RECORD
/// (stats cards) — staggered as groups 0/1/2.
///
/// Save policy (documented decision): the nickname persists on field
/// submit — IME "done" or the SAVE button; palette swatches persist
/// immediately on tap. All state lives in [controller].
class ProfileScreen extends StatefulWidget {
  /// Creates the profile screen.
  const ProfileScreen({required this.controller, super.key});

  /// Key of the avatar color block (tests).
  static const Key avatarKey = Key('profile_avatar');

  /// Key of the nickname field (tests).
  static const Key nicknameFieldKey = Key('profile_nickname_field');

  /// Key of the save button (tests).
  static const Key saveNicknameButtonKey = Key('profile_save_button');

  /// Key prefix of palette swatches: `profile_swatch_$i`.
  static const String swatchKeyPrefix = 'profile_swatch_';

  /// Owns the persisted profile and stats state.
  final ProfileController controller;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final TextEditingController _nickname = TextEditingController(
    text: widget.controller.profile.nickname,
  );
  bool _invalid = false;

  @override
  void dispose() {
    _nickname.dispose();
    super.dispose();
  }

  Future<void> _saveNickname() async {
    final accepted = await widget.controller.setNickname(_nickname.text);
    if (!mounted) {
      return;
    }
    setState(() => _invalid = !accepted);
    if (accepted) {
      _nickname.value = TextEditingValue(
        text: widget.controller.profile.nickname,
      );
    }
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
              const TtrPageHeader(title: 'PROFILE'),
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
                          _AvatarBlock(
                            colorIndex: profile.colorIndex,
                            nickname: profile.nickname,
                            avatarKey: ProfileScreen.avatarKey,
                          ),
                          _NicknameField(
                            key: ProfileScreen.nicknameFieldKey,
                            controller: _nickname,
                            invalid: _invalid,
                            onSubmitted: (_) => _saveNickname(),
                          ),
                          TtrButton(
                            key: ProfileScreen.saveNicknameButtonKey,
                            label: 'SAVE',
                            onPressed: _saveNickname,
                          ),
                        ],
                      ),
                      const SizedBox(height: SpacingScale.xl),
                      TtrCardGroup(
                        label: 'COLOR',
                        staggerIndex: 1,
                        children: [
                          _PaletteGrid(
                            swatchKeyPrefix: ProfileScreen.swatchKeyPrefix,
                            selectedIndex: profile.colorIndex,
                            onSelect: widget.controller.selectColor,
                          ),
                        ],
                      ),
                      const SizedBox(height: SpacingScale.xl),
                      TtrCardGroup(
                        label: 'RECORD',
                        staggerIndex: 2,
                        children: [
                          ProfileStatsRow(stats: widget.controller.stats),
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

class _AvatarBlock extends StatelessWidget {
  const _AvatarBlock({
    required this.colorIndex,
    required this.nickname,
    required this.avatarKey,
  });

  final int colorIndex;
  final String nickname;
  final Key avatarKey;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
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
        const SizedBox(height: SpacingScale.md),
        Text(nickname, style: TypeScale.bodyEmphasis),
      ],
    );
  }
}

class _NicknameField extends StatelessWidget {
  const _NicknameField({
    required this.controller,
    required this.invalid,
    required this.onSubmitted,
    super.key,
  });

  final TextEditingController controller;
  final bool invalid;
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

/// Palette grid: the four [PlayerPalette] swatches; the selected
/// swatch carries a primary-colored selection ring (guide § 6).
class _PaletteGrid extends StatelessWidget {
  const _PaletteGrid({
    required this.swatchKeyPrefix,
    required this.selectedIndex,
    required this.onSelect,
  });

  final String swatchKeyPrefix;
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
              key: ValueKey<String>('$swatchKeyPrefix$index'),
              color: color,
              selected: index == selectedIndex,
              onTap: () => onSelect(index),
            ),
          ),
      ],
    );
  }
}
