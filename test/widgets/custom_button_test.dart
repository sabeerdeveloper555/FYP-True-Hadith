import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:true_hadith/widgets/custom_button.dart';

void main() {
  testWidgets('CustomButton displays text and triggers onPressed', (WidgetTester tester) async {
    var pressed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomButton(
            text: 'Tap Me',
            onPressed: () => pressed = true,
          ),
        ),
      ),
    );

    expect(find.text('Tap Me'), findsOneWidget);

    await tester.tap(find.text('Tap Me'));
    await tester.pump();

    expect(pressed, isTrue);
  });

  testWidgets('CustomButton shows loading indicator when isLoading', (WidgetTester tester) async {
    var pressed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomButton(
            text: 'Loading',
            isLoading: true,
            onPressed: () => pressed = true,
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();

    expect(pressed, isFalse);
  });
}
