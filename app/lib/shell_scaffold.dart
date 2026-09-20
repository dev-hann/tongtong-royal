import 'dart:async' show unawaited;

import 'package:app/design/tokens.dart';
import 'package:app/design/widgets/ttr_phase_transition.dart';
import 'package:app/design/widgets/ttr_quit_dialog.dart';
import 'package:app/game/controls/action_input_controller.dart';
import 'package:app/infra/profile_store.dart';
import 'package:app/infra/sound_service.dart';
import 'package:app/presentation/home_screen.dart';
import 'package:app/presentation/onboarding_screen.dart';
import 'package:app/presentation/profile_screen.dart';
import 'package:app/presentation/settings_screen.dart';
import 'package:app/presentation/show_intro_screen.dart';
import 'package:app/profile/profile_controller.dart';
import 'package:app/profile/stats_recorder.dart';
import 'package:app/show/show_config.dart';
import 'package:app/show/show_controller.dart';
import 'package:app/show/show_outcome_flow.dart';
import 'package:app/show/show_shell_screens.dart';
import 'package:app/show/show_view_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

/// Immersive shell: full-bleed (no app bar) with animated phase
/// transitions. The GDD v2 show flow (Home → SHOW → podium or
/// elimination summary) is driven by one [ShowController]; the
/// shell wires its write-moments to stats/sound through
/// [ShowResultsFlow] and keeps the profile re-seat rule (identity
/// edits while at home apply to the next show).
class ShellScaffold extends StatefulWidget {
  /// Creates the shell.
  const ShellScaffold({super.key});

  @override
  State<ShellScaffold> createState() => _ShellScaffoldState();
}

class _ShellScaffoldState extends State<ShellScaffold>
    with WidgetsBindingObserver {
  ProfileController? _profile;
  ShowController? _show;
  ShowResultsFlow? _resultsFlow;
  AudioplayersSfxPlayer? _sfxBackend;
  SoundService? _sound;
  String _lastNickname = '';
  int _lastColorIndex = -1;

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
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _show?.dispose();
    _profile?.dispose();
    _sound?.dispose();
    _sfxBackend?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Re-assert fullscreen + portrait after activity recreation.
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
    final sfxBackend = AudioplayersSfxPlayer();
    final sound = SoundService(player: sfxBackend, profile: profile);
    setState(() {
      _profile = profile;
      _sfxBackend = sfxBackend;
      _sound = sound;
      _resultsFlow = ShowResultsFlow(
        recorder: StatsRecorder(store: store),
        sound: sound,
      );
      _lastNickname = profile.profile.nickname;
      _lastColorIndex = profile.profile.colorIndex;
      _show = _createShow(profile.profile);
    });
  }

  ShowController _createShow(Profile profile) {
    final show = ShowController(
      config: ShowConfig(
        humanNickname: profile.nickname,
        humanColorIndex: profile.colorIndex,
      ),
      // GDD v2 § 6: the shell seeds each show from the wall clock.
      showSeedFactory: () => DateTime.now().millisecondsSinceEpoch % 1000000,
    )..addListener(_onShowChanged);
    return show;
  }

  /// Profile edits while idling at home re-seat the show with the
  /// stored nickname + color; mid-show edits apply next show.
  void _onProfileChanged() {
    final profile = _profile;
    final show = _show;
    if (profile == null || show == null || show.phase != ShowPhase.lobby) {
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
      _show?.dispose();
      _show = _createShow(current);
    });
  }

  /// Show write-moments + sound cues fire through the flow on every
  /// controller notification (GDD v2 § 7.3).
  void _onShowChanged() {
    final show = _show;
    if (show == null) {
      return;
    }
    setState(() {});
    _resultsFlow?.handle(show);
  }

  void _startShowFromHome() {
    _sound?.play(Sfx.uiTap);
    _show?.startShow();
  }

  void _playAgain() {
    _sound?.play(Sfx.uiTap);
    _show?.playAgain();
  }

  void _exitToHome() {
    _sound?.play(Sfx.uiTap);
    _show?.exitToHome();
  }

  /// Quit confirm (GDD v2 § 7.4): QUIT abandons the show — no stats
  /// recorded — and returns to Home.
  Future<void> _confirmAbandon() async {
    final quit = await TtrQuitDialog.show(context);
    if (quit && mounted) {
      _show?.abandonShow();
    }
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
        builder: (_) => SettingsScreen(controller: profile, sound: _sound),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: ListenableBuilder(
        listenable: Listenable.merge([_show, _profile]),
        builder: (context, _) {
          final profile = _profile;
          final show = _show;
          final Widget screen;
          if (profile == null || show == null) {
            // Profile still loading (first frames after launch).
            screen = const ColoredBox(color: ColorPalette.background);
          } else if (profile.needsOnboarding) {
            // First launch only (GDD v2 § 8.1): setup before home.
            screen = KeyedSubtree(
              key: const ValueKey('onboarding'),
              child: OnboardingScreen(
                controller: profile,
                onStart: () {
                  _sound?.play(Sfx.uiTap);
                  setState(() {});
                },
                onSkip: () {
                  _sound?.play(Sfx.uiTap);
                  setState(() {});
                },
              ),
            );
          } else {
            screen = switch (show.phase) {
              ShowPhase.lobby => show.summary == null
                  ? KeyedSubtree(
                      key: const ValueKey('home'),
                      child: HomeScreen(
                        onPlaySolo: _startShowFromHome,
                        nickname: profile.profile.nickname,
                        colorIndex: profile.profile.colorIndex,
                        onOpenProfile: _openProfile,
                        onOpenSettings: _openSettings,
                      ),
                    )
                  : showSummaryScreen(
                      show,
                      onPlayAgain: _playAgain,
                      onExitHome: _exitToHome,
                    ),
              ShowPhase.showIntro => ShowIntroScreen(
                roundNumber: show.roundIndex,
                totalRounds: show.roundCount,
                gameName: show.introGameName,
                ruleLine: show.introRuleLine,
                verb: switch (
                  ActionInputController.verbFor(
                    show.schedule.slotFor(show.roundIndex).gameId,
                  )
                ) {
                  GameVerb.jump => 'JUMP',
                  GameVerb.dash => 'DASH',
                },
                isFinal: show.schedule.slotFor(show.roundIndex).isFinal,
                countdownValue: show.countdownValue,
                onQuitAttempt: _confirmAbandon,
              ),
              ShowPhase.roundPlay => showPlayScreen(show: show, sound: _sound),
              ShowPhase.qualifyFlash => showFlashScreen(show),
              ShowPhase.podium => showPodiumScreen(
                show,
                onPlayAgain: _playAgain,
                onExitHome: _exitToHome,
              ),
            };
          }
          return TtrPhaseTransition(child: screen);
        },
      ),
    );
  }
}
