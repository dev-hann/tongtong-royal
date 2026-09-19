import 'package:app/design/tokens.dart';
import 'package:app/design/widgets/ttr_seat_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('renders avatar block, nickname and badges', (tester) async {
    await tester.pumpWidget(
      wrap(
        const TtrSeatCard(
          nickname: 'You',
          playerColor: PlayerPalette.one,
          isLocal: true,
        ),
      ),
    );

    expect(find.text('You'), findsOneWidget);
    expect(find.text('YOU'), findsOneWidget);
    expect(find.text('Ready'), findsOneWidget);

    final avatar = tester.widget<DecoratedBox>(
      find.byKey(TtrSeatCard.avatarKey),
    );
    final deco = avatar.decoration as BoxDecoration;
    expect(deco.color, PlayerPalette.one);
  });

  testWidgets('bot card shows BOT badge instead of ready state', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const TtrSeatCard(
          nickname: 'BOT 1',
          playerColor: PlayerPalette.two,
          isBot: true,
        ),
      ),
    );

    expect(find.text('BOT'), findsOneWidget);
    expect(find.text('Ready'), findsNothing);
  });

  testWidgets('local card tap cycles to the next seat color', (tester) async {
    await tester.pumpWidget(
      wrap(
        const TtrSeatCard(
          nickname: 'You',
          playerColor: PlayerPalette.one,
          isLocal: true,
        ),
      ),
    );

    await tester.tap(find.byKey(TtrSeatCard.cardKey));
    await tester.pump();

    final avatar = tester.widget<DecoratedBox>(
      find.byKey(TtrSeatCard.avatarKey),
    );
    expect((avatar.decoration as BoxDecoration).color, PlayerPalette.two);
  });

  testWidgets('non-local card is not tappable', (tester) async {
    await tester.pumpWidget(
      wrap(
        const TtrSeatCard(
          nickname: 'BOT 1',
          playerColor: PlayerPalette.two,
          isBot: true,
        ),
      ),
    );

    expect(
      tester.widget<GestureDetector>(
        find.byKey(TtrSeatCard.cardKey),
      ).onTap,
      isNull,
    );
  });
}
