import 'package:app/design/tokens.dart';
import 'package:app/design/ttr_icons.dart';
import 'package:app/design/widgets/ttr_pulse.dart';
import 'package:flutter/material.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

/// Key of the 1st-place trophy icon (shared with the podium screen's
/// public key constant).
const Key trophyIconKey = Key('podium_trophy');

/// One podium pedestal: a rank group of players standing on a
/// colored block; the first-place block carries the trophy gradient
/// and an optional celebration pulse.
///
/// Pure renderer: placements arrive domain-judged; a rank shared by
/// several players stacks every sharer on the same pedestal with
/// `T-<ordinal>` labels.
class PodiumPedestal extends StatefulWidget {
  /// Creates a pedestal.
  const PodiumPedestal({
    required this.blockKey,
    required this.placements,
    required this.height,
    this.trophy = false,
    this.pulse = false,
    this.nicknames = const {},
    this.playerColors = const {},
    super.key,
  });

  /// Key applied to the height-holding block (for tests).
  final Key blockKey;

  /// Rank group standing on this pedestal.
  final List<Placement> placements;

  /// Pedestal block height.
  final double height;

  /// Whether this is the first-place pedestal (trophy + gradient).
  final bool trophy;

  /// Whether to run the repeating celebration pulse.
  final bool pulse;

  /// Display names by player id (falls back to the id).
  final Map<String, String> nicknames;

  /// Seat colors by player id (falls back to the seat palette).
  final Map<String, Color> playerColors;

  @override
  State<PodiumPedestal> createState() => _PodiumPedestalState();
}

class _PodiumPedestalState extends State<PodiumPedestal> {
  @override
  Widget build(BuildContext context) {
    final shared = widget.placements.length > 1;
    final column = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.trophy)
          const Icon(
            TtrIcons.trophy,
            key: trophyIconKey,
            color: ColorPalette.warning,
            size: SpacingScale.xxxl,
          ),
        for (final (index, placement) in widget.placements.indexed) ...[
          if (index > 0) const SizedBox(height: SpacingScale.xs),
          _PlayerFigure(
            placement: placement,
            label: shared
                ? 'T-${ordinalOf(placement.rank)}'
                : ordinalOf(placement.rank),
            name:
                widget.nicknames[placement.playerId] ?? placement.playerId,
            color:
                widget.playerColors[placement.playerId] ??
                PlayerPalette.forIndex(placement.rank - 1),
          ),
        ],
        const SizedBox(height: SpacingScale.sm),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: widget.trophy
                ? const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [ColorPalette.primary, ColorPalette.warning],
                  )
                : null,
            color: widget.trophy ? null : ColorPalette.secondary,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(RadiusScale.card),
            ),
          ),
          child: SizedBox(
            key: widget.blockKey,
            width: SpacingScale.xxxl * 2,
            height: widget.height,
          ),
        ),
      ],
    );
    if (!widget.pulse) {
      return column;
    }
    return TtrPulse(child: column);
  }
}

class _PlayerFigure extends StatelessWidget {
  const _PlayerFigure({
    required this.placement,
    required this.label,
    required this.name,
    required this.color,
  });

  final Placement placement;
  final String label;
  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: Border.all(color: PlayerPalette.localRing, width: 2),
          ),
          child: const SizedBox(width: 32, height: 32),
        ),
        const SizedBox(height: SpacingScale.xs),
        Text(
          label,
          style: TypeScale.label.copyWith(
            color: ColorPalette.neutral500,
          ),
        ),
        Text(name, style: TypeScale.bodyEmphasis),
        Text(
          '${placement.points} pt',
          style: TypeScale.label.copyWith(
            color: ColorPalette.neutral700,
          ),
        ),
      ],
    );
  }
}

/// Ordinal label of [rank] (1st, 2nd, 3rd, 4th...).
String ordinalOf(int rank) => switch (rank) {
  1 => '1st',
  2 => '2nd',
  3 => '3rd',
  _ => '${rank}th',
};
