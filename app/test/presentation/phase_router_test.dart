import 'package:app/design/tokens.dart';
import 'package:app/design/widgets/ttr_standings_list.dart';
import 'package:app/presentation/game_screen.dart';
import 'package:app/presentation/lobby_screen.dart';
import 'package:app/presentation/phase_router.dart';
import 'package:app/presentation/podium_screen.dart';
import 'package:app/presentation/round_intro_screen.dart';
import 'package:app/presentation/round_results_screen.dart';
import 'package:app/shell_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tongtong_shared/tongtong_shared.dart';

void main() {
  RoundResult roundResult(int roundIndex) => RoundResult(
    roundIndex: roundIndex,
    minigameId: 'trap_race',
    placements: const [
      Placement(playerId: 'p1', rank: 1, points: 4),
      Placement(playerId: 'p2', rank: 2, points: 3),
    ],
  );

  Widget host(ShellController controller) => MaterialApp(
    home: Scaffold(
      body: PhaseRouter(
        controller: controller,
        lobbyPlayers: const [LobbyPlayer(displayName: 'Host', isReady: true)],
        canStart: true,
        minigameName: 'Trap Race',
        minigameRule: 'First to the finish line wins.',
        countdownValue: 3,
        scoreboard: const [ScoreEntry(playerId: 'p1', points: 4)],
        timeRemaining: '42',
        resultsMinigameName: 'Trap Race',
        resultsStandings: const [
          StandingEntry(playerId: 'p1', totalPoints: 7, roundDelta: 4),
        ],
        resultsAutoAdvanceSeconds: 6,
        podiumNicknames: const {'p1': 'Winner'},
        podiumPlayerColors: const {'p1': PlayerPalette.one},
      ),
    ),
  );

  late ShellController controller;

  setUp(() {
    controller = ShellController();
  });

  testWidgets('LOBBY renders LobbyScreen', (tester) async {
    await tester.pumpWidget(host(controller));
    expect(find.byType(LobbyScreen), findsOneWidget);
    expect(find.byType(RoundIntroScreen), findsNothing);
    expect(find.text('Host'), findsOneWidget);
  });

  testWidgets('ROUND_INTRO renders RoundIntroScreen', (tester) async {
    controller.startMatch();
    await tester.pumpWidget(host(controller));
    expect(find.byType(RoundIntroScreen), findsOneWidget);
    expect(find.text('Trap Race'), findsOneWidget);
    expect(find.byType(LobbyScreen), findsNothing);
    // Round badge derives from the controller's round counter.
    expect(find.byKey(RoundIntroScreen.roundBadgeKey), findsOneWidget);
    expect(
      find.text('ROUND 1 / ${MatchRules.roundCount}'),
      findsOneWidget,
    );
  });

  testWidgets('ROUND_PLAY renders GameScreen', (tester) async {
    controller
      ..startMatch()
      ..startPlay();
    await tester.pumpWidget(host(controller));
    expect(find.byType(GameScreen), findsOneWidget);
    expect(find.text('42'), findsOneWidget);
    expect(find.byType(RoundIntroScreen), findsNothing);
  });

  testWidgets('ROUND_RESULTS renders RoundResultsScreen from controller', (
    tester,
  ) async {
    controller
      ..startMatch()
      ..startPlay();
    final result = roundResult(0);
    controller.endRound(result);
    await tester.pumpWidget(host(controller));
    expect(find.byType(RoundResultsScreen), findsOneWidget);
    // p1 appears in the placement list and the standings mini list.
    expect(find.text('p1'), findsNWidgets(2));
    expect(find.text('p2'), findsOneWidget);
    expect(find.byType(GameScreen), findsNothing);
    // Header pill, standings deltas and auto-advance bar forwarded.
    expect(find.byKey(RoundResultsScreen.headerKey), findsOneWidget);
    expect(find.text('ROUND 1 / ${MatchRules.roundCount} · TRAP RACE'),
        findsOneWidget);
    expect(find.text('+4'), findsOneWidget);
    expect(find.byKey(RoundResultsScreen.autoAdvanceKey), findsOneWidget);
  });

  testWidgets('PODIUM renders PodiumScreen from controller rankings', (
    tester,
  ) async {
    controller
      ..startMatch()
      ..startPlay()
      ..endRound(roundResult(0))
      ..toPodium();
    await tester.pumpWidget(host(controller));
    expect(find.byType(PodiumScreen), findsOneWidget);
    // Nickname map wins over the raw player id on the podium.
    expect(find.text('Winner'), findsOneWidget);
    expect(find.byType(RoundResultsScreen), findsNothing);
    // Podium receives the injected nickname.
    expect(find.text('Winner'), findsOneWidget);
  });

  testWidgets('router rebuilds on controller transitions', (tester) async {
    await tester.pumpWidget(host(controller));
    expect(find.byType(LobbyScreen), findsOneWidget);

    controller.startMatch();
    await tester.pump();
    expect(find.byType(RoundIntroScreen), findsOneWidget);

    controller.startPlay();
    await tester.pump();
    expect(find.byType(GameScreen), findsOneWidget);
  });

  testWidgets('onSolo shows the lobby solo button and fires it', (
    tester,
  ) async {
    var soloStarted = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PhaseRouter(
            controller: controller,
            lobbyPlayers: const [
              LobbyPlayer(displayName: 'Host', isReady: true),
            ],
            canStart: true,
            onSolo: () => soloStarted = true,
          ),
        ),
      ),
    );

    expect(find.byKey(LobbyScreen.soloButtonKey), findsOneWidget);
    await tester.tap(find.byKey(LobbyScreen.soloButtonKey));
    await tester.pump();
    expect(soloStarted, isTrue);
  });
}
