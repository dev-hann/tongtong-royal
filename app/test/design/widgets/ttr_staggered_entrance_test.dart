import 'package:app/design/widgets/ttr_staggered_entrance.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('startDelayFor (guide § 4 timing math)', () {
    test('first item waits the initial 80ms delay', () {
      expect(
        TtrStaggeredEntrance.startDelayFor(0),
        const Duration(milliseconds: 80),
      );
    });

    test('each later item adds one 40ms gap', () {
      expect(
        TtrStaggeredEntrance.startDelayFor(1),
        const Duration(milliseconds: 120),
      );
      expect(
        TtrStaggeredEntrance.startDelayFor(2),
        const Duration(milliseconds: 160),
      );
      expect(
        TtrStaggeredEntrance.startDelayFor(7),
        const Duration(milliseconds: 360),
      );
    });
  });

  group('entrance animation', () {
    Widget wrap(Widget child) => MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );

    Finder fadeOf(TtrStaggeredEntrance widget) => find.descendant(
      of: find.byWidget(widget),
      matching: find.byType(FadeTransition),
    );

    Finder slideOf(TtrStaggeredEntrance widget) => find.descendant(
      of: find.byWidget(widget),
      matching: find.byType(SlideTransition),
    );

    // Stepped pumps: animations armed by a mid-pump timer only start
    // on the following frame, so fixed 40ms frames simulate the
    // timeline deterministically.
    Future<void> advance(WidgetTester tester, int totalMs) async {
      var elapsed = 0;
      while (elapsed < totalMs) {
        await tester.pump(const Duration(milliseconds: 40));
        elapsed += 40;
      }
    }

    testWidgets('item starts hidden and below its final slot', (tester) async {
      const entrance = TtrStaggeredEntrance(
        key: ValueKey('one'),
        index: 0,
        child: Text('row'),
      );
      await tester.pumpWidget(wrap(entrance));

      final fade = tester.widget<FadeTransition>(fadeOf(entrance));
      expect(fade.opacity.value, 0);

      final slide = tester.widget<SlideTransition>(slideOf(entrance));
      expect(slide.position.value.dy, greaterThan(0));
    });

    testWidgets('item settles visible at its slot after the stagger', (
      tester,
    ) async {
      const entrance = TtrStaggeredEntrance(
        key: ValueKey('one'),
        index: 2,
        child: Text('row'),
      );
      await tester.pumpWidget(wrap(entrance));
      // Well past 80ms start + 2 × 40ms gap + 240ms item run.
      await advance(tester, 640);

      final fade = tester.widget<FadeTransition>(fadeOf(entrance));
      expect(fade.opacity.value, 1);

      final slide = tester.widget<SlideTransition>(slideOf(entrance));
      expect(slide.position.value, Offset.zero);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('later index is still mid-entrance when earlier is done', (
      tester,
    ) async {
      const first = TtrStaggeredEntrance(
        key: ValueKey('first'),
        index: 0,
        child: Text('a'),
      );
      const third = TtrStaggeredEntrance(
        key: ValueKey('third'),
        index: 3,
        child: Text('b'),
      );
      await tester.pumpWidget(wrap(const Column(children: [first, third])));
      await advance(tester, 400);

      expect(tester.widget<FadeTransition>(fadeOf(first)).opacity.value, 1);
      final lateFade = tester
          .widget<FadeTransition>(fadeOf(third))
          .opacity
          .value;
      expect(lateFade, lessThan(1));
      expect(lateFade, greaterThan(0));
    });
  });
}
