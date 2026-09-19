import 'package:app/design/tokens.dart';
import 'package:flutter/material.dart';

/// One drifting shape of the [TtrAmbientBackdrop] (token data).
typedef _ShapeSpec = ({Color color, double size, double left, double top});

/// Subtle animated backdrop: soft token-colored circles drifting
/// upward on a slow loop ([MotionDurations.ambient]).
///
/// Purely decorative — paints behind existing content via a Stack;
/// owns no game state.
class TtrAmbientBackdrop extends StatefulWidget {
  /// Creates the ambient backdrop.
  const TtrAmbientBackdrop({super.key});

  /// Key of every drifting shape (for tests).
  static const Key shapeKey = Key('ambient_shape');

  @override
  State<TtrAmbientBackdrop> createState() => _TtrAmbientBackdropState();
}

class _TtrAmbientBackdropState extends State<TtrAmbientBackdrop>
    with SingleTickerProviderStateMixin {
  static const List<_ShapeSpec> _shapes = [
    (
      color: ColorPalette.primarySoft,
      size: 220,
      left: 0.05,
      top: 0.55,
    ),
    (
      color: ColorPalette.secondarySoft,
      size: 160,
      left: 0.68,
      top: 0.62,
    ),
    (
      color: ColorPalette.warningSoft,
      size: 120,
      left: 0.38,
      top: 0.70,
    ),
  ];

  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: MotionDurations.ambient,
  )..repeat();

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.biggest.height;
        return AnimatedBuilder(
          animation: _drift,
          builder: (context, _) {
            return Stack(
              clipBehavior: Clip.none,
              children: [
                for (final (index, shape) in _shapes.indexed)
                  Positioned(
                    left: shape.left * constraints.maxWidth,
                    top: _driftTop(shape, index, height),
                    child: DecoratedBox(
                      key: TtrAmbientBackdrop.shapeKey,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: shape.color,
                      ),
                      child: SizedBox(
                        width: shape.size,
                        height: shape.size,
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  /// Vertical position: rises one shape-height over the loop, then
  /// restarts; per-shape phase offset keeps the shapes unsynchronized.
  double _driftTop(_ShapeSpec shape, int index, double height) {
    final phase = (_drift.value + index * 0.33) % 1.0;
    return shape.top * height - phase * shape.size;
  }
}
