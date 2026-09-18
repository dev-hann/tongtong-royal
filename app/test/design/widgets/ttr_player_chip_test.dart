import 'package:app/design/tokens.dart';
import 'package:app/design/widgets/ttr_player_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );

  testWidgets('shows nickname and ready state', (tester) async {
    await tester.pumpWidget(wrap(const TtrPlayerChip(nickname: 'Ari')));

    expect(find.text('Ari'), findsOneWidget);
    expect(find.text('Ready'), findsOneWidget);
  });

  testWidgets('not ready shows the not-ready label', (tester) async {
    await tester.pumpWidget(
      wrap(const TtrPlayerChip(nickname: 'Bo', isReady: false)),
    );

    expect(find.text('Not ready'), findsOneWidget);
  });

  testWidgets('bot seats show the BOT badge', (tester) async {
    await tester.pumpWidget(
      wrap(const TtrPlayerChip(nickname: 'Bot 1', isBot: true)),
    );

    expect(find.text('BOT'), findsOneWidget);
  });

  testWidgets('human seats show no BOT badge', (tester) async {
    await tester.pumpWidget(wrap(const TtrPlayerChip(nickname: 'Ari')));

    expect(find.text('BOT'), findsNothing);
  });

  testWidgets('disconnected state overrides the ready label', (tester) async {
    await tester.pumpWidget(
      wrap(const TtrPlayerChip(nickname: 'Ari', isDisconnected: true)),
    );

    expect(find.text('Disconnected'), findsOneWidget);
    expect(find.text('Ready'), findsNothing);
  });

  testWidgets('default dot color is seat 1', (tester) async {
    await tester.pumpWidget(wrap(const TtrPlayerChip(nickname: 'Ari')));

    final dotColors = tester
        .widgetList<Container>(find.byType(Container))
        .map((c) => (c.decoration as BoxDecoration?)?.color);
    expect(dotColors, contains(PlayerPalette.one));
  });

  testWidgets('local player has a white ring around the dot', (tester) async {
    await tester.pumpWidget(
      wrap(const TtrPlayerChip(nickname: 'Ari', isLocal: true)),
    );

    final containers = tester.widgetList<Container>(find.byType(Container));
    final ringed = containers
        .map((c) => (c.decoration as BoxDecoration?)?.border)
        .whereType<Border>()
        .any((b) => b.top.color == PlayerPalette.localRing);
    expect(ringed, isTrue);
  });
}
