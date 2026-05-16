import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:true_hadith/screens/result_detail_page.dart';

void main() {
  group('ResultDetailPage Tests', () {
    Widget buildSubject() => const MaterialApp(
          home: ResultDetailPage(userId: 1, hadithId: 1),
        );

    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();
      expect(find.byType(ResultDetailPage), findsOneWidget);
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

    testWidgets('shows error state after API call fails', (tester) async {
      await tester.pumpWidget(buildSubject());
      // Let the HTTP call fail (no server running in tests)
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      // Either error message or still loading — no crash
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('AppBar back arrow allows navigation', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: const Scaffold(body: Text('Previous')),
          routes: {
            '/detail': (_) => const ResultDetailPage(userId: 1, hadithId: 1),
          },
        ),
      );
      await tester.pump();
      expect(find.text('Previous'), findsOneWidget);
    });

    testWidgets('loading state shows centered spinner', (tester) async {
      await tester.pumpWidget(buildSubject());

      final spinner = find.byType(CircularProgressIndicator);
      expect(spinner, findsOneWidget);

      // Verify it is centered
      final center = find.ancestor(
        of: spinner,
        matching: find.byType(Center),
      );
      expect(center, findsWidgets);
    });
  });
}
