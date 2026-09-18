import 'package:app/game/bots/bot_brain.dart';
import 'package:app/game/course/course_map.dart';
// Vector2 is the repo-wide math type (same seam as
// touch_input_source.dart); no physics-engine types cross it.
import 'package:forge2d/forge2d.dart' show Vector2;
import 'package:tongtong_shared/tongtong_shared.dart';

/// Horizontal x-range of one blocker (wall/hammer column) or one
/// kill-zone gap between platforms, in world meters.
typedef _XRange = ({double minX, double maxX});

/// Heuristic Trap Race runner (GDD § 9.2, basic difficulty): run
/// right at full tilt, jump over walls/hammer columns and gaps
/// when they enter the look-ahead window, and jump+dash when stuck
/// (near-zero speed despite input, mirroring the host's stuck
/// detection pattern). Idles once past the finish line.
final class RaceBot implements BotBrain {
  /// Extracts the map knowledge this brain needs from [map] —
  /// finish x, wall and hammer-column x-ranges, and the x-ranges
  /// of every gap between consecutive platforms. The policy is
  /// fully deterministic, so there is no seed to take.
  factory RaceBot.fromCourseMap(CourseMap map) {
    final obstacles = <_XRange>[
      for (final wall in map.walls)
        (
          minX: wall.center.x - wall.width / 2,
          maxX: wall.center.x + wall.width / 2,
        ),
      for (final hammer in map.hammers)
        (
          minX: hammer.pivot.x - hammer.radius * hammerZoneFraction,
          maxX: hammer.pivot.x + hammer.radius * hammerZoneFraction,
        ),
    ];
    final sorted = [...map.platforms]
      ..sort((a, b) => a.center.x.compareTo(b.center.x));
    final gaps = <_XRange>[];
    for (var i = 0; i + 1 < sorted.length; i++) {
      final left = sorted[i].center.x + sorted[i].width / 2;
      final right = sorted[i + 1].center.x - sorted[i + 1].width / 2;
      if (left < right) {
        gaps.add((minX: left, maxX: right));
      }
    }
    return RaceBot._(map.finishLine.center.x, obstacles, gaps);
  }

  RaceBot._(this._finishX, List<_XRange> obstacles, List<_XRange> gaps)
    : _obstacles = List.unmodifiable(obstacles),
      _gaps = List.unmodifiable(gaps);

  /// Anticipation window for jumping over blockers and gaps,
  /// meters. At the 6 m/s run cap this is ~0.42 s of travel —
  /// enough to clear a 0.3 m-thick wall or 3 m gap when jumping
  /// near the window edge.
  static const double lookAheadMeters = 2.5;

  /// Fraction of a race hammer's radius treated as its blocking
  /// column. The tip sweeps the full radius, but the center column
  /// is the region reliably blocked at any arm angle; basic bots
  /// simply hop through it.
  static const double hammerZoneFraction = 0.5;

  /// A bot whose speed stays below this fraction of
  /// [PhysicsConsts.moveMaxSpeed] while it inputs movement counts
  /// as making no progress.
  static const double stuckSpeedFraction = 0.15;

  /// Consecutive no-progress ticks (at [PhysicsConsts.tickRate])
  /// before the stuck rule fires: ~0.5 s of pushing against
  /// nothing.
  static const int stuckTicks = 30;

  /// Ticks between jumps (~0.5 s): roughly the jump air time from
  /// [PhysicsConsts.jumpImpulse], so the bot never re-presses
  /// mid-air arcs.
  static const int jumpCooldownTicks = 30;

  /// Ticks between dashes (1 s) so a stuck bot bursts instead of
  /// machine-gunning [PhysicsConsts.dashImpulse].
  static const int dashCooldownTicks = 60;

  final double _finishX;
  final List<_XRange> _obstacles;
  final List<_XRange> _gaps;

  int _jumpCooldown = 0;
  int _dashCooldown = 0;
  int _slowTicks = 0;

  @override
  PlayerInputState decide(BotObservation obs) {
    if (_jumpCooldown > 0) _jumpCooldown--;
    if (_dashCooldown > 0) _dashCooldown--;

    final x = obs.self.x;
    if (x >= _finishX) {
      return PlayerInputState(moveDir: Vector2.zero());
    }

    if (obs.grounded && _jumpCooldown == 0) {
      final jumpNow = _blockedAhead(x) || _gapAhead(x);
      if (jumpNow) {
        _jumpCooldown = jumpCooldownTicks;
        return _run(jump: true);
      }
    }

    const slowSpeed = PhysicsConsts.moveMaxSpeed * stuckSpeedFraction;
    if (obs.self.vx.abs() < slowSpeed) {
      _slowTicks++;
    } else {
      _slowTicks = 0;
    }
    if (_slowTicks >= stuckTicks) {
      _slowTicks = 0;
      if (_dashCooldown == 0) {
        _dashCooldown = dashCooldownTicks;
        return _run(jump: true, dash: true);
      }
      return _run(jump: true);
    }
    return _run();
  }

  PlayerInputState _run({bool jump = false, bool dash = false}) {
    return PlayerInputState(
      moveDir: Vector2(fullMoveInput, 0),
      jumpPressed: jump,
      dashPressed: dash,
    );
  }

  bool _blockedAhead(double x) {
    return _obstacles.any((o) => o.maxX > x && o.minX - x <= lookAheadMeters);
  }

  bool _gapAhead(double x) {
    return _gaps.any((g) => x < g.maxX && g.minX - x <= lookAheadMeters);
  }
}
