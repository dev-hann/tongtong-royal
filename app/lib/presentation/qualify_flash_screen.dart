import 'package:app/design/game_art/jelly_primitives.dart';
import 'package:app/design/tokens.dart';
import 'package:app/design/ttr_icons.dart';
import 'package:app/design/widgets/ttr_ambient_backdrop.dart';
import 'package:app/design/widgets/ttr_pop_on_change.dart';
import 'package:app/design/widgets/ttr_staggered_entrance.dart';
import 'package:flutter/material.dart';

/// One player's verdict chip data (pure renderer input).
@immutable
final class QualifyFlashEntry {
  /// Creates an entry.
  const QualifyFlashEntry({
    required this.playerId,
    required this.nickname,
    required this.color,
    required this.qualified,
    this.isChampion = false,
    this.isLocal = false,
  });

  /// Player id.
  final String playerId;

  /// Display nickname.
  final String nickname;

  /// Seat color (a [PlayerPalette] value).
  final Color color;

  /// Verdict: qualified or eliminated.
  final bool qualified;

  /// Crown holder (FINAL champion, shared pair included).
  final bool isChampion;

  /// Whether this is the local human's chip.
  final bool isLocal;
}

/// QUALIFY_FLASH phase screen (GDD v2 § 5, FOCUSED archetype, 4 s
/// auto-advance — guide § 6): per-player chips drop in staggered,
/// verdict-colored `QUALIFIED` / `ELIMINATED` text, quota counter
/// `k / N QUALIFIED`. The FINAL's flash is the crown moment: `CROWN`
/// reveal with a pop and the champion chip(s) crowned (shared pair
/// per GDD v2 § 7.2).
///
/// Pure renderer: entries arrive pre-ordered (qualified first, then
/// eliminated; champions first in the FINAL); the auto-advance timer
/// lives in the show controller, not here.
class QualifyFlashScreen extends StatelessWidget {
  /// Creates the flash screen.
  const QualifyFlashScreen({
    required this.quota,
    required this.isFinal,
    this.entries = const [],
    this.humanEliminated = false,
    this.onAdvanceNow,
    super.key,
  });

  /// Key of the quota counter (tests and integration finds).
  static const Key counterKey = Key('qualify_flash_counter');

  /// Key of the CROWN reveal (tests and integration finds).
  static const Key crownKey = Key('qualify_flash_crown');

  /// Verdict chips in reveal order.
  final List<QualifyFlashEntry> entries;

  /// The round's quota (N of the counter).
  final int quota;

  /// Whether this flash is the FINAL's crown moment.
  final bool isFinal;

  /// Whether the local human was eliminated this round (back skips
  /// to the summary instead of waiting out the reveal).
  final bool humanEliminated;

  /// Invoked when system back skips the remaining reveal wait
  /// (eliminated human or FINAL — ux-checklist back matrix).
  final VoidCallback? onAdvanceNow;

  @override
  Widget build(BuildContext context) {
    final qualifiedCount =
        entries.where((entry) => entry.qualified).length;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && (isFinal || humanEliminated)) {
          onAdvanceNow?.call();
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          const TtrAmbientBackdrop(),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  if (isFinal)
                    ColorPalette.warningSoft
                  else
                    ColorPalette.secondarySoft,
                  ColorPalette.background,
                ],
              ),
            ),
            child: SafeArea(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isFinal)
                      const _CrownReveal(key: QualifyFlashScreen.crownKey)
                    else
                      _QuotaCounter(
                        key: counterKey,
                        qualified: qualifiedCount,
                        quota: quota,
                      ),
                    const SizedBox(height: SpacingScale.xl),
                    for (final (index, entry) in entries.indexed)
                      TtrStaggeredEntrance(
                        index: index,
                        child: _VerdictChip(entry: entry),
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

/// `k / N QUALIFIED` — the shared-qualification count can exceed the
/// nominal quota (GDD v2 § 7.1); the counter shows the truth.
class _QuotaCounter extends StatelessWidget {
  const _QuotaCounter({
    required this.qualified,
    required this.quota,
    super.key,
  });

  final int qualified;
  final int quota;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SpacingScale.lg,
        vertical: SpacingScale.xs,
      ),
      decoration: BoxDecoration(
        color: ColorPalette.surface,
        borderRadius: BorderRadius.circular(RadiusScale.pill),
        border: Border.all(color: ColorPalette.neutral200),
      ),
      child: Text(
        '$qualified / $quota QUALIFIED',
        style: TypeScale.label,
      ),
    );
  }
}

/// FINAL crown moment: crown glyph + `CROWN` text popping in (guide
/// § 4 verdict-reveal rule: pop + one pulse family).
class _CrownReveal extends StatelessWidget {
  const _CrownReveal({super.key});

  @override
  Widget build(BuildContext context) {
    return const TtrPopOnChange(
      tag: 'crown',
      initialPop: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            TtrIcons.crown,
            color: ColorPalette.warning,
            size: ComponentSizes.heroIcon,
          ),
          SizedBox(height: SpacingScale.sm),
          Text('CROWN', style: TypeScale.displayNumeral),
        ],
      ),
    );
  }
}

/// One verdict row: mini jelly + nickname + verdict text. Eliminated
/// jellies spin dizzy (guide § 9.1 ragdoll language).
class _VerdictChip extends StatelessWidget {
  const _VerdictChip({required this.entry});

  final QualifyFlashEntry entry;

  @override
  Widget build(BuildContext context) {
    final verdictColor = entry.qualified
        ? ColorPalette.success
        : ColorPalette.danger;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SpacingScale.xs),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: ComponentSizes.homeEntry,
            height: ComponentSizes.homeEntry,
            child: CustomPaint(
              painter: JellyCharacterPainter(
                body: entry.color,
                pose: entry.qualified
                    ? JellyPose.idle
                    : JellyPose.eliminated,
                phase: 0.25,
                isLocal: entry.isLocal,
              ),
            ),
          ),
          const SizedBox(width: SpacingScale.md),
          Text(entry.nickname, style: TypeScale.bodyEmphasis),
          const SizedBox(width: SpacingScale.md),
          if (entry.isChampion) ...[
            const Icon(
              TtrIcons.crown,
              color: ColorPalette.warning,
              size: ComponentSizes.rowIcon,
            ),
            const SizedBox(width: SpacingScale.xs),
          ],
          Text(
            entry.qualified ? 'QUALIFIED' : 'ELIMINATED',
            style: TypeScale.label.copyWith(color: verdictColor),
          ),
        ],
      ),
    );
  }
}
