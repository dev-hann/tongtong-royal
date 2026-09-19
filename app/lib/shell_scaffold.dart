import 'dart:async' show unawaited;

import 'package:app/design/tokens.dart';
import 'package:app/design/widgets/ttr_phase_transition.dart';
import 'package:app/infra/profile_store.dart';
import 'package:app/presentation/game_screen.dart';
import 'package:app/presentation/home_screen.dart';
import 'package:app/presentation/lobby_screen.dart' show LobbyPlayer;
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

/// Immersive shell: full-bleed (no app bar) with animated phase
/// transitions. The home screen is a presentation-level phase shown
/// until a match starts; the domain [RoundPhase]s drive the rest.
/// Local profile wiring (GDD § 8.1): the persisted profile loads
/// once at startup, gates first launch behind onboarding, injects
/// the stored nickname + color into the solo match config (the
/// solo controller stays pure — no storage reads), and records
/// stats once when the (terminal) results screen appears.
class ShellScaffold extends StatefulWidget {
  /// Creates the shell.
  const ShellScaffold({super.key});

  @override
  State<ShellScaffold> createState() => _ShellScaffoldState();
}

class _ShellScaffoldState extends State<ShellScaffold>
    with WidgetsBindingObserver {
  final ShellController _controller = ShellController();
  final int _matchSeed = DateTime.now().millisecondsSinceEpoch % 1000000;

  ProfileController? _profile;
  StatsRecorder? _recorder;
  SoloMatchController? _solo;
  String _lastNickname = '';
  int _lastColorIndex = -1;
  bool _atHome = true;
  bool _resultsRecorded = false;

  @override
  void initState() {
    super.initState();
    // Foldables/Android may drop immersive-sticky when the activity
    // is recreated (fold state change, cover display): re-apply on
    // every resume (ux-checklist, guide § 8).
    WidgetsBinding.instance.addObserver(this);
    // Fire-and-forget is fine: profile loads into a ChangeNotifier
    // that rebuilds the shell when ready (no ordering dependency).
    unawaited(_loadProfile());
    _controller.addListener(_onPhaseChanged);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_onPhaseChanged);
    _solo?.dispose();
    _profile?.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Re-assert fullscreen + portrait after activity recreation
      // (fold/unfold, cover display handoff — see initState note).
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations(<DeviceOrientation>[
        DeviceOrientation.portraitUp,
      ]);
    }
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

  /// Stats recording (GDD § 8.1): the single-round match's final
  /// rank fires once when the results screen appears — the results
  /// screen is the match's terminal state.
  void _onPhaseChanged() {
    if (_controller.phase != RoundPhase.roundResults) {
      return;
    }
    final solo = _solo;
    final recorder = _recorder;
    if (_resultsRecorded || solo == null || recorder == null) {
      return;
    }
    final human = Rankings.finalRanking(
      _controller.roundResults,
      const {},
    ).finalRankings.where((p) => p.playerId == solo.humanId).toList();
    if (human.isEmpty) {
      return;
    }
    _resultsRecorded = true;
    // Stats are best-effort local persistence; a failed write must
    // not block the results screen.
    unawaited(recorder.recordMatch(finalRank: human.first.rank));
  }

  void _startSoloFromHome() {
    setState(() {
      _atHome = false;
      _resultsRecorded = false;
    });
    _solo?.startSolo();
  }

  void _playAgain() {
    setState(() => _resultsRecorded = false);
    _solo?.playAgain();
  }

  void _exitToHome() {
    if (_controller.phase == RoundPhase.roundResults) {
      _solo?.exitToHome();
    }
    setState(() => _atHome = true);
  }

  /// Quit confirm from the play screen (GDD § 7.11): the solo
  /// match is abandoned to the lobby with no result — abandoned
  /// races never reach the results screen, so no stats record.
  void _abandonSolo() {
    _solo?.abandonMatch();
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
                onSkip: () => setState(() {}),
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
                // ROUND_PLAY mounts the solo round (human + bots) into
                // the GameScreen viewport slot.
                gameView: session == null
                    ? null
                    : KeyedSubtree(
                        key: ValueKey<SoloRoundSession>(session),
                        child: SoloPlayView(
                          session: session,
                          humanColorIndex: solo.config.humanColorIndex,
                          onQuit: _abandonSolo,
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
                onAbandonIntro: _abandonSolo,
                minigameName: solo.introName,
                minigameRule: solo.introRule,
                countdownValue: solo.countdownValue,
                resultsMinigameName: solo.resultsMinigameName,
                resultsStandings: solo.standingsAfterLatestRound,
                onPlayAgain: _playAgain,
                onExitHome: _exitToHome,
              ),
            );
          }
          return TtrPhaseTransition(child: screen);
        },
      ),
    );
  }
}
