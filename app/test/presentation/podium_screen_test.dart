import 'package:app/design/tokens.dart';
import 'package:app/presentation/podium_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('crowns the single champion with PLAY AGAIN and HOME', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const PodiumScreen(
          humanWon: true,
          champions: [
            PodiumPlayer(
              playerId: 'solo-player',
              nickname: 'You',
              color: PlayerPalette.one,
              isLocal: true,
            ),
          ],
        ),
      ),
    );

    expect(find.text('VICTORY'), findsOneWidget);
    expect(find.text('You'), findsOneWidget);
    expect(find.text('PLAY AGAIN'), findsOneWidget);
    expect(find.text('HOME'), findsOneWidget);
    expect(find.byKey(PodiumScreen.championKey), findsOneWidget);
  });

  testWidgets('shared crown shows the co-champion pair', (tester) async {
    await tester.pumpWidget(
      wrap(
        const PodiumScreen(
          champions: [
            PodiumPlayer(
              playerId: 'solo-player',
              nickname: 'You',
              color: PlayerPalette.one,
              isLocal: true,
            ),
            PodiumPlayer(
              playerId: 'bot-2',
              nickname: 'BOT 2',
              color: PlayerPalette.three,
            ),
          ],
        ),
      ),
    );

    expect(find.text('You'), findsOneWidget);
    expect(find.text('BOT 2'), findsOneWidget);
    expect(find.byKey(PodiumScreen.championKey), findsOneWidget);
  });

  testWidgets('bot champion shows the CROWN headline, not VICTORY', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const PodiumScreen(
          champions: [
            PodiumPlayer(
              playerId: 'bot-1',
              nickname: 'BOT 1',
              color: PlayerPalette.two,
            ),
          ],
        ),
      ),
    );

    expect(find.text('CROWN'), findsOneWidget);
    expect(find.text('VICTORY'), findsNothing);
  });

  testWidgets('PLAY AGAIN fires the rematch callback', (tester) async {
    var rematches = 0;
    await tester.pumpWidget(
      wrap(
        PodiumScreen(
          champions: const [
            PodiumPlayer(
              playerId: 'solo-player',
              nickname: 'You',
              color: PlayerPalette.one,
            ),
          ],
          onPlayAgain: () => rematches++,
        ),
      ),
    );

    await tester.tap(find.text('PLAY AGAIN'));
    await tester.pump();

    expect(rematches, 1);
  });

  testWidgets('system back exits to home (back matrix)', (tester) async {
    var exits = 0;
    await tester.pumpWidget(
      wrap(
        PodiumScreen(
          champions: const [
            PodiumPlayer(
              playerId: 'bot-1',
              nickname: 'BOT 1',
              color: PlayerPalette.two,
            ),
          ],
          onExitHome: () => exits++,
        ),
      ),
    );

    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 300));

    expect(exits, 1);
  });
}
