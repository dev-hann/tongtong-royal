import 'package:app/design/theme.dart';
import 'package:app/presentation/game_screen.dart';
import 'package:app/presentation/lobby_screen.dart';
import 'package:app/presentation/phase_router.dart';
import 'package:app/shell_controller.dart';
import 'package:app/solo/solo_match_config.dart';
import 'package:app/solo/solo_match_controller.dart';
import 'package:app/solo/solo_play_view.dart';
import 'package:flutter/material.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

void main() {
  runApp(const TongTongApp());
}

/// Root widget: wires [ShellController] into the phase router.
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

/// Hosts the [PhaseRouter] with a stable app bar chrome.
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('TongTong Royal')),
      // ROUND_PLAY mounts the solo round (human + bots) into the
      // GameScreen viewport slot; every other phase routes through
      // PhaseRouter. The solo controller provides all injected view
      // data (intro, countdown, lobby, rematch).
      body: ListenableBuilder(
        listenable: Listenable.merge([_controller, _solo]),
        builder: (context, _) {
          if (_controller.phase == RoundPhase.roundPlay) {
            final session = _solo.currentRound;
            return GameScreen(
              scoreboard: const [],
              timeRemaining: '',
              gameView: session == null
                  ? null
                  : KeyedSubtree(
                      key: ValueKey<SoloRoundSession>(session),
                      child: SoloPlayView(session: session),
                    ),
            );
          }
          return PhaseRouter(
            controller: _controller,
            lobbyPlayers: [
              for (final (i, seat) in _solo.seats.indexed)
                LobbyPlayer(
                  displayName: seat.nickname,
                  isReady: true,
                  isBot: i > 0,
                ),
            ],
            onSolo: _solo.startSolo,
            minigameName: _solo.introName,
            minigameRule: _solo.introRule,
            countdownValue: _solo.countdownValue,
            onRematch: _solo.rematch,
          );
        },
      ),
    );
  }
}
