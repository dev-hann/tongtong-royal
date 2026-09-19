import 'package:app/design/tokens.dart';
import 'package:app/design/widgets/ttr_button.dart';
import 'package:app/design/widgets/ttr_seat_card.dart';
import 'package:app/presentation/lobby_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const players = [
    LobbyPlayer(displayName: 'Ari', isReady: true, isLocal: true),
    LobbyPlayer(displayName: 'BOT 1', isReady: true, isBot: true),
  ];

  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('renders one seat card per player with names and badges', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(const LobbyScreen(players: players, canStart: false)),
    );

    expect(find.byType(TtrSeatCard), findsNWidgets(2));
    expect(find.text('Ari'), findsOneWidget);
    expect(find.text('BOT 1'), findsOneWidget);
    expect(find.text('YOU'), findsOneWidget);
    expect(find.text('BOT'), findsOneWidget);
  });

  testWidgets('tapping the local card cycles its seat color', (tester) async {
    await tester.pumpWidget(
      wrap(const LobbyScreen(players: players, canStart: false)),
    );

    await tester.tap(find.byKey(TtrSeatCard.cardKey).first);
    await tester.pump();

    final avatar = tester.widget<DecoratedBox>(
      find.byKey(TtrSeatCard.avatarKey).first,
    );
    expect((avatar.decoration as BoxDecoration).color, PlayerPalette.two);
  });

  testWidgets('bot cards render but are not tappable', (tester) async {
    await tester.pumpWidget(
      wrap(const LobbyScreen(players: players, canStart: false)),
    );

    expect(
      tester
          .widget<GestureDetector>(find.byKey(TtrSeatCard.cardKey).last)
          .onTap,
      isNull,
    );
  });

  testWidgets('PLAY SOLO is the large primary action and fires onSolo', (
    tester,
  ) async {
    var soloStarted = false;
    await tester.pumpWidget(
      wrap(
        LobbyScreen(
          players: players,
          canStart: false,
          onSolo: () => soloStarted = true,
        ),
      ),
    );

    final solo = tester.widget<TtrButton>(
      find.byKey(LobbyScreen.soloButtonKey),
    );
    expect(solo.size, TtrButtonSize.large);
    expect(solo.variant, TtrButtonVariant.primary);

    await tester.tap(find.byKey(LobbyScreen.soloButtonKey));
    await tester.pump();
    expect(soloStarted, isTrue);
  });

  testWidgets('Start is the secondary action, gated by canStart', (
    tester,
  ) async {
    var started = false;
    await tester.pumpWidget(
      wrap(
        LobbyScreen(
          players: players,
          canStart: false,
          onStart: () => started = true,
        ),
      ),
    );

    final start = tester.widget<TtrButton>(
      find.byKey(LobbyScreen.startButtonKey),
    );
    expect(start.variant, TtrButtonVariant.secondary);

    await tester.tap(
      find.byKey(LobbyScreen.startButtonKey),
      warnIfMissed: false,
    );
    await tester.pump();
    expect(started, isFalse);
  });

  testWidgets('Start fires when canStart is true', (tester) async {
    var started = false;
    await tester.pumpWidget(
      wrap(
        LobbyScreen(
          players: players,
          canStart: true,
          onStart: () => started = true,
        ),
      ),
    );

    await tester.tap(find.byKey(LobbyScreen.startButtonKey));
    await tester.pump();
    expect(started, isTrue);
  });

  testWidgets('no solo button when onSolo is null (default)', (tester) async {
    await tester.pumpWidget(
      wrap(const LobbyScreen(players: players, canStart: false)),
    );

    expect(find.byKey(LobbyScreen.soloButtonKey), findsNothing);
  });
}
