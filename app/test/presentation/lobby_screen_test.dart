import 'package:app/presentation/lobby_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const players = [
    LobbyPlayer(displayName: 'Ari', isReady: true),
    LobbyPlayer(displayName: 'Bo', isReady: false),
  ];

  Widget wrap(Widget child) =>
      MaterialApp(home: Scaffold(body: child));

  testWidgets('renders player names and ready state', (tester) async {
    await tester.pumpWidget(
      wrap(const LobbyScreen(players: players, canStart: false)),
    );

    expect(find.text('Ari'), findsOneWidget);
    expect(find.text('Bo'), findsOneWidget);
    expect(find.text('Ready'), findsOneWidget);
    expect(find.text('Not ready'), findsOneWidget);
  });

  testWidgets('Start button disabled when canStart is false', (tester) async {
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

    final button = tester.widget<ElevatedButton>(
      find.byKey(LobbyScreen.startButtonKey),
    );
    expect(button.onPressed, isNull);

    await tester.tap(find.byKey(LobbyScreen.startButtonKey));
    await tester.pump();
    expect(started, isFalse);
  });

  testWidgets('Start button enabled and fires callback when canStart true', (
    tester,
  ) async {
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

    final button = tester.widget<ElevatedButton>(
      find.byKey(LobbyScreen.startButtonKey),
    );
    expect(button.onPressed, isNotNull);

    await tester.tap(find.byKey(LobbyScreen.startButtonKey));
    await tester.pump();
    expect(started, isTrue);
  });
}
