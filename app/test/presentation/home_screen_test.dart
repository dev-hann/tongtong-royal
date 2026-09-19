import 'package:app/design/ttr_icons.dart';
import 'package:app/design/widgets/ttr_button.dart';
import 'package:app/presentation/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('shows the typographic logo and tagline', (tester) async {
    await tester.pumpWidget(wrap(const HomeScreen()));

    expect(find.text('TONGTONG'), findsOneWidget);
    expect(find.text('ROYAL'), findsOneWidget);
    expect(find.text('One button. Total chaos.'), findsOneWidget);
  });

  testWidgets('PLAY SOLO is the large primary action and fires callback', (
    tester,
  ) async {
    var soloStarted = false;
    await tester.pumpWidget(
      wrap(HomeScreen(onPlaySolo: () => soloStarted = true)),
    );

    final button = tester.widget<TtrButton>(
      find.byKey(HomeScreen.playSoloButtonKey),
    );
    expect(button.onPressed, isNotNull);

    await tester.tap(find.byKey(HomeScreen.playSoloButtonKey));
    await tester.pump();
    expect(soloStarted, isTrue);
  });

  testWidgets('PLAY FRIENDS is disabled with a Coming soon chip', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const HomeScreen()));

    expect(find.text('PLAY FRIENDS'), findsOneWidget);
    expect(find.text('Coming soon'), findsOneWidget);

    final button = tester.widget<TtrButton>(
      find.byKey(HomeScreen.playFriendsButtonKey),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('content is protected by SafeArea (design guide 8)', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const HomeScreen()));

    expect(find.byType(SafeArea), findsOneWidget);
  });

  testWidgets('top-left avatar entry shows profile color and initial', (
    tester,
  ) async {
    var opened = false;
    await tester.pumpWidget(
      wrap(
        HomeScreen(
          nickname: 'HANN',
          colorIndex: 2,
          onOpenProfile: () => opened = true,
        ),
      ),
    );

    expect(find.byKey(HomeScreen.profileButtonKey), findsOneWidget);
    expect(find.text('H'), findsOneWidget);

    await tester.tap(find.byKey(HomeScreen.profileButtonKey));
    await tester.pump();
    expect(opened, isTrue);
  });

  testWidgets('top-right settings gear opens the settings screen', (
    tester,
  ) async {
    var opened = false;
    await tester.pumpWidget(
      wrap(HomeScreen(onOpenSettings: () => opened = true)),
    );

    await tester.tap(find.byKey(HomeScreen.settingsButtonKey));
    await tester.pump();
    expect(opened, isTrue);
    expect(find.byIcon(TtrIcons.gear), findsOneWidget);
  });
}
