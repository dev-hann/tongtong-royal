import 'package:app/design/tokens.dart';
import 'package:app/presentation/qualify_flash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('renders per-player verdicts in reveal order', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const QualifyFlashScreen(
          quota: 3,
          isFinal: false,
          entries: [
            QualifyFlashEntry(
              playerId: 'solo-player',
              nickname: 'You',
              color: PlayerPalette.one,
              qualified: true,
              isLocal: true,
            ),
            QualifyFlashEntry(
              playerId: 'bot-1',
              nickname: 'BOT 1',
              color: PlayerPalette.two,
              qualified: true,
            ),
            QualifyFlashEntry(
              playerId: 'bot-3',
              nickname: 'BOT 3',
              color: PlayerPalette.four,
              qualified: false,
            ),
          ],
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('QUALIFIED'), findsNWidgets(2));
    expect(find.text('ELIMINATED'), findsOneWidget);
    expect(find.text('You'), findsOneWidget);
    expect(find.text('BOT 1'), findsOneWidget);
    expect(find.text('BOT 3'), findsOneWidget);
  });

  testWidgets('shows the quota counter k / N QUALIFIED', (tester) async {
    await tester.pumpWidget(
      wrap(
        const QualifyFlashScreen(quota: 3, isFinal: false),
      ),
    );

    expect(find.text('0 / 3 QUALIFIED'), findsOneWidget);
  });

  testWidgets('shared qualification can exceed the nominal quota', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const QualifyFlashScreen(
          quota: 2,
          isFinal: false,
          entries: [
            QualifyFlashEntry(
              playerId: 'a',
              nickname: 'A',
              color: PlayerPalette.one,
              qualified: true,
            ),
            QualifyFlashEntry(
              playerId: 'b',
              nickname: 'B',
              color: PlayerPalette.two,
              qualified: true,
            ),
            QualifyFlashEntry(
              playerId: 'c',
              nickname: 'C',
              color: PlayerPalette.three,
              qualified: true,
            ),
          ],
        ),
      ),
    );

    expect(find.text('3 / 2 QUALIFIED'), findsOneWidget);
  });

  testWidgets('final flash is the crown moment with CROWN text', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const QualifyFlashScreen(
          quota: 1,
          isFinal: true,
          entries: [
            QualifyFlashEntry(
              playerId: 'solo-player',
              nickname: 'You',
              color: PlayerPalette.one,
              qualified: true,
              isChampion: true,
              isLocal: true,
            ),
            QualifyFlashEntry(
              playerId: 'bot-1',
              nickname: 'BOT 1',
              color: PlayerPalette.two,
              qualified: false,
            ),
          ],
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('CROWN'), findsOneWidget);
    expect(find.text('QUALIFIED'), findsOneWidget);
    expect(find.text('ELIMINATED'), findsOneWidget);
    expect(find.byKey(QualifyFlashScreen.crownKey), findsOneWidget);
  });

  testWidgets('back on an eliminated-human flash advances immediately', (
    tester,
  ) async {
    var advanced = 0;
    await tester.pumpWidget(
      wrap(
        QualifyFlashScreen(
          quota: 3,
          isFinal: false,
          humanEliminated: true,
          onAdvanceNow: () => advanced++,
        ),
      ),
    );

    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 300));

    expect(advanced, 1, reason: 'ux-checklist back matrix: flash → summary');
  });

  testWidgets('back on a qualified-human flash waits for the auto-advance', (
    tester,
  ) async {
    var advanced = 0;
    await tester.pumpWidget(
      wrap(
        QualifyFlashScreen(
          quota: 3,
          isFinal: false,
          onAdvanceNow: () => advanced++,
        ),
      ),
    );

    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 300));

    expect(advanced, 0, reason: 'qualified flash auto-advances (4 s timer)');
  });
}
