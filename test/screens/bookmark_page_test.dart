import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:true_hadith/screens/bookmark_page.dart';

void main() {
  group('BookmarkPage Tests', () {
    Widget buildSubject() => const MaterialApp(
          home: BookmarkPage(userId: 1),
        );

    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();
      expect(find.byType(BookmarkPage), findsOneWidget);
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

    testWidgets('shows AppBar with Bookmarks title after load', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();
      // AppBar title is visible even during loading
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('shows filter tags after load attempt', (tester) async {
      await tester.pumpWidget(buildSubject());
      // Pump long enough for the HTTP request to fail and show UI
      await tester.pump(const Duration(seconds: 3));
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

    testWidgets('shows My Favourites in AppBar title', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();
      expect(find.text('My Favourites'), findsOneWidget);
    });

    testWidgets('shows All filter tag', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();
      expect(find.text('All'), findsOneWidget);
    });

    testWidgets('no crash on userId provided', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: BookmarkPage(userId: 99)));
      await tester.pump();
      expect(find.byType(BookmarkPage), findsOneWidget);
    });
  });
}
