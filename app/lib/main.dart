import 'dart:async' show unawaited;

import 'package:app/design/theme.dart';
import 'package:app/design/tokens.dart';
import 'package:app/design/widgets/ttr_phase_transition.dart';
import 'package:app/infra/profile_store.dart';
import 'package:app/presentation/game_screen.dart';
import 'package:app/presentation/home_screen.dart';
import 'package:app/presentation/lobby_screen.dart';
import 'package:app/presentation/onboarding_screen.dart';
import 'package:app/presentation/phase_router.dart';
import 'package:app/presentation/profile_screen.dart';
import 'package:app/presentation/settings_screen.dart';
import 'package:app/presentation/solo_standings.dart';
import 'package:app/profile/profile_controller.dart';
import 'package:app/profile/stats_recorder.dart';
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
/// Local profile wiring (GDD § 8.1): the persisted profile loads
/// once at startup, gates first launch behind onboarding, injects
/// the stored nickname + color into the solo match config (the
/// solo controller stays pure — no storage reads), and records
/// stats at podium confirm.
class ShellScaffold extends StatefulWidget {
  /// Creates the shell.
  const ShellScaffold({super.key});

  @override
  State<ShellScaffold> createState() => _ShellScaffoldState();
}

class _ShellScaffoldState extends State<ShellScaffold> {
  final ShellController _controller = ShellController();
  final int _matchSeed = DateTime.now().millisecondsSinceEpoch % 1000000;

  ProfileController? _profile;
  StatsRecorder? _recorder;
  SoloMatchController? _solo;
  String _lastNickname = '';
  int _lastColorIndex = -1;
  bool _atHome = true;
  bool _podiumRecorded = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadProfile());
  }

  @override
  void dispose() {
    _solo?.dispose();
    _profile?.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final store = await ProfileStore.create();
    final profile = ProfileController(store: store);
    await profile.load();
    if (!mounted) {
      profile.dispose();
      return;
    }
    profile.addListener(_onProfileChanged);
    setState(() {
      _profile = profile;
      _recorder = StatsRecorder(store: store);
      _lastNickname = profile.profile.nickname;
      _lastColorIndex = profile.profile.colorIndex;
      _solo = _createSolo(profile.profile);
    });
  }

  SoloMatchController _createSolo(Profile profile) => SoloMatchController(
    shell: _controller,
    config: SoloMatchConfig(
      matchSeed: _matchSeed,
      humanNickname: profile.nickname,
      humanColorIndex: profile.colorIndex,
    ),
  );

  /// Profile edits while idling at home re-seat the solo match with
  /// the stored nickname + color; mid-match edits apply next match.
  void _onProfileChanged() {
    final profile = _profile;
    if (profile == null || !_atHome || _controller.phase != RoundPhase.lobby) {
      return;
    }
    final current = profile.profile;
    if (current.nickname == _lastNickname &&
        current.colorIndex == _lastColorIndex) {
      return;
    }
    _lastNickname = current.nickname;
    _lastColorIndex = current.colorIndex;
    setState(() {
      _solo?.dispose();
      _solo = _createSolo(current);
    });
  }

  void _startSoloFromHome() {
    setState(() {
      _atHome = false;
      _podiumRecorded = false;
    });
    _solo?.startSolo();
  }

  /// Records the confirmed podium result (GDD § 8.1) once per match,
  /// then runs the chosen follow-up (rematch or exit).
  void _confirmPodium(VoidCallback action) {
    final solo = _solo;
    final recorder = _recorder;
    final result = _controller.matchResult;
    if (!_podiumRecorded && solo != null && recorder != null) {
      final human = result?.finalRankings
          .where((p) => p.playerId == solo.humanId)
          .toList(growable: false);
      if (human != null && human.isNotEmpty) {
        _podiumRecorded = true;
        unawaited(recorder.recordMatch(finalRank: human.first.rank));
      }
    }
    action();
  }

  void _exitToHome() {
    // Podium -> lobby (replans for the next match), then home.
    if (_controller.phase == RoundPhase.podium) {
      _solo?.rematch();
    }
    setState(() => _atHome = true);
  }

  void _openProfile() {
    final profile = _profile;
    if (profile == null) {
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProfileScreen(controller: profile),
      ),
    );
  }

  void _openSettings() {
    final profile = _profile;
    if (profile == null) {
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsScreen(controller: profile),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: ListenableBuilder(
        listenable: Listenable.merge([_controller, _solo, _profile]),
        builder: (context, _) {
          final profile = _profile;
          final solo = _solo;
          final Widget screen;
          if (profile == null || solo == null) {
            // Profile still loading (first frames after launch).
            screen = const ColoredBox(color: ColorPalette.background);
          } else if (profile.needsOnboarding) {
            // First launch only (GDD § 8.1): setup before home.
            screen = KeyedSubtree(
              key: const ValueKey('onboarding'),
              child: OnboardingScreen(
                controller: profile,
                onStart: () => setState(() {}),
              ),
            );
          } else if (_atHome && _controller.phase == RoundPhase.lobby) {
            screen = KeyedSubtree(
              key: const ValueKey('home'),
              child: HomeScreen(
                onPlaySolo: _startSoloFromHome,
                nickname: profile.profile.nickname,
                colorIndex: profile.profile.colorIndex,
                onOpenProfile: _openProfile,
                onOpenSettings: _openSettings,
              ),
            );
          } else if (_controller.phase == RoundPhase.roundPlay) {
            final session = solo.currentRound;
            screen = KeyedSubtree(
              key: const ValueKey('roundPlay'),
              child: GameScreen(
                scoreboard: solo.standings,
                timeRemaining: '',
                remainingSeconds: solo.remainingSeconds,
                roundNumber: _controller.roundIndex + 1,
                totalRounds: _controller.totalRounds,
                // ROUND_PLAY mounts the solo round (human + bots) into
                // the GameScreen viewport slot.
                gameView: session == null
                    ? null
                    : KeyedSubtree(
                        key: ValueKey<SoloRoundSession>(session),
                        child: SoloPlayView(
                          session: session,
                          humanColorIndex: solo.config.humanColorIndex,
                        ),
                      ),
              ),
            );
          } else {
            screen = KeyedSubtree(
              key: ValueKey('phase_${_controller.phase.name}'),
              child: PhaseRouter(
                controller: _controller,
                lobbyPlayers: [
                  for (final (i, seat) in solo.seats.indexed)
                    LobbyPlayer(
                      displayName: seat.nickname,
                      isReady: true,
                      isBot: i > 0,
                      isLocal: i == 0,
                    ),
                ],
                lobbyLocalColorIndex: solo.config.humanColorIndex,
                onSolo: solo.startSolo,
                minigameName: solo.introName,
                minigameRule: solo.introRule,
                countdownValue: solo.countdownValue,
                resultsMinigameName: solo.resultsMinigameName,
                resultsStandings: solo.standingsAfterLatestRound,
                resultsAutoAdvanceSeconds: soloResultsSeconds,
                podiumNicknames: {
                  for (final seat in solo.seats) seat.id: seat.nickname,
                },
                podiumPlayerColors: {
                  for (final (i, seat) in solo.seats.indexed)
                    seat.id: PlayerPalette.forSeat(
                      i,
                      localIndex: solo.config.humanColorIndex,
                    ),
                },
                onRematch: () => _confirmPodium(() {
                  _podiumRecorded = false;
                  solo.rematch();
                }),
                onExitToHome: () => _confirmPodium(_exitToHome),
              ),
            );
          }
          return TtrPhaseTransition(child: screen);
        },
      ),
    );
  }
}
