import 'package:app/design/theme.dart';
import 'package:app/design/tokens.dart';
import 'package:app/design/widgets/ttr_phase_transition.dart';
import 'package:app/presentation/game_screen.dart';
import 'package:app/presentation/home_screen.dart';
import 'package:app/presentation/lobby_screen.dart';
import 'package:app/presentation/phase_router.dart';
import 'package:app/presentation/solo_standings.dart';
import 'package:app/shell_controller.dart';
import 'package:app/solo/solo_match_config.dart';
import 'package:app/solo/solo_match_controller.dart';
import 'package:app/solo/solo_play_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Immersive fullscreen (design guide § 8): hide status and
  // navigation bars; content still respects SafeArea for display
  // cutouts. Portrait-only: the whole shell is designed vertical.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
  ]);
  runApp(const TongTongApp());
}

/// Root widget: wires [ShellController] into the shell.
class TongTongApp extends StatelessWidget {
  /// Creates the app root.
  const TongTongApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TongTong Royal',
      theme: buildTtrTheme(),
      home: const ShellScaffold(),
    );
  }
}

/// Immersive shell: full-bleed (no app bar) with animated phase
/// transitions. The home screen is a presentation-level phase shown
/// until a match starts; the domain [RoundPhase]s drive the rest.
class ShellScaffold extends StatefulWidget {
  /// Creates the shell scaffold.
  const ShellScaffold({super.key});

  @override
  State<ShellScaffold> createState() => _ShellScaffoldState();
}

class _ShellScaffoldState extends State<ShellScaffold> {
  final ShellController _controller = ShellController();
  final int _matchSeed = DateTime.now().millisecondsSinceEpoch % 1000000;
  late final SoloMatchController _solo;
  bool _atHome = true;

  @override
  void initState() {
    super.initState();
    _solo = SoloMatchController(
      shell: _controller,
      config: SoloMatchConfig(matchSeed: _matchSeed),
    );
  }

  @override
  void dispose() {
    _solo.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _startSoloFromHome() {
    setState(() => _atHome = false);
    _solo.startSolo();
  }

  void _exitToHome() {
    // Podium -> lobby (replans for the next match), then home.
    if (_controller.phase == RoundPhase.podium) {
      _solo.rematch();
    }
    setState(() => _atHome = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: ListenableBuilder(
        listenable: Listenable.merge([_controller, _solo]),
        builder: (context, _) {
          final Widget screen;
          if (_atHome && _controller.phase == RoundPhase.lobby) {
            screen = KeyedSubtree(
              key: const ValueKey('home'),
              child: HomeScreen(onPlaySolo: _startSoloFromHome),
            );
          } else if (_controller.phase == RoundPhase.roundPlay) {
            final session = _solo.currentRound;
            screen = KeyedSubtree(
              key: const ValueKey('roundPlay'),
              child: GameScreen(
                scoreboard: _solo.standings,
                timeRemaining: '',
                remainingSeconds: _solo.remainingSeconds,
                roundNumber: _controller.roundIndex + 1,
                totalRounds: _controller.totalRounds,
                // ROUND_PLAY mounts the solo round (human + bots) into
                // the GameScreen viewport slot.
                gameView: session == null
                    ? null
                    : KeyedSubtree(
                        key: ValueKey<SoloRoundSession>(session),
                        child: SoloPlayView(session: session),
                      ),
              ),
            );
          } else {
            screen = KeyedSubtree(
              key: ValueKey('phase_${_controller.phase.name}'),
              child: PhaseRouter(
                controller: _controller,
                lobbyPlayers: [
                  for (final (i, seat) in _solo.seats.indexed)
                    LobbyPlayer(
                      displayName: seat.nickname,
                      isReady: true,
                      isBot: i > 0,
                      isLocal: i == 0,
                    ),
                ],
                onSolo: _solo.startSolo,
                minigameName: _solo.introName,
                minigameRule: _solo.introRule,
                countdownValue: _solo.countdownValue,
                resultsMinigameName: _solo.resultsMinigameName,
                resultsStandings: _solo.standingsAfterLatestRound,
                resultsAutoAdvanceSeconds: soloResultsSeconds,
                podiumNicknames: {
                  for (final seat in _solo.seats) seat.id: seat.nickname,
                },
                podiumPlayerColors: {
                  for (final (i, seat) in _solo.seats.indexed)
                    seat.id: PlayerPalette.forIndex(i),
                },
                onRematch: _solo.rematch,
                onExitToHome: _exitToHome,
              ),
            );
          }
          return TtrPhaseTransition(child: screen);
        },
      ),
    );
  }
}
