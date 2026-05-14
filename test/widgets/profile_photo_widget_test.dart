import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:true_hadith/widgets/profile_photo_widget.dart';

void main() {
  testWidgets('ProfilePhoto shows placeholder and opens menu', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfilePhotoWidget(userId: 1),
        ),
      ),
    );

    // Placeholder icon should be visible when no photoUrl provided
    expect(find.byIcon(Icons.person), findsOneWidget);

    // Tap the widget and expect the bottom sheet menu to appear
    await tester.tap(find.byType(ProfilePhotoWidget));
    await tester.pumpAndSettle();

    expect(find.text('Update Photo'), findsOneWidget);
  });
}
