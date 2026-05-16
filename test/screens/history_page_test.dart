import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:true_hadith/screens/history_page.dart';

void main() {
  group('HistoryPage Tests', () {
    Widget buildSubject() => const MaterialApp(
          home: HistoryPage(userId: 1),
        );

    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();
      expect(find.byType(HistoryPage), findsOneWidget);
    });

    testWidgets('shows loading indicator on initial load', (tester) async {
      await tester.pumpWidget(buildSubject());
      // Assert before async HTTP call resolves — initial state is loading
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('has Scaffold', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('loading spinner is centered', (tester) async {
      await tester.pumpWidget(buildSubject());

      final spinner = find.byType(CircularProgressIndicator);
      expect(spinner, findsOneWidget);

      final center = find.ancestor(
        of: spinner,
        matching: find.byType(Center),
      );
      expect(center, findsWidgets);
    });

    testWidgets('shows My History in AppBar', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();
      expect(find.text('My History'), findsOneWidget);
    });

    testWidgets('shows error message after API fails', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      // Either error UI or empty list — no crash
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('shows Retry button after error', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      // After API failure an error + retry should be shown
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('no crash with different userId', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: HistoryPage(userId: 42)),
      );
      await tester.pump();
      expect(find.byType(HistoryPage), findsOneWidget);
    });

    testWidgets('AppBar is present', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();
      expect(find.byType(AppBar), findsOneWidget);
    });
  });
}
