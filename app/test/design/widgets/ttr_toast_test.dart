import 'package:app/design/widgets/ttr_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders the message', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: TtrToast(message: 'Saved!')),
      ),
    );

    expect(find.text('Saved!'), findsOneWidget);
  });
}
