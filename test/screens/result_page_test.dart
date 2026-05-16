import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:true_hadith/screens/result_page.dart';
import 'package:true_hadith/models/hadith_models.dart';
import 'package:true_hadith/widgets/hadith_card.dart';

void main() {
  group('ResultPage Tests', () {
    final sampleResults = [
      HadithSummary(
        hadithId: 1,
        bookName: 'Sahih Bukhari',
        hadithNumber: '1',
        chapterNumber: '1',
        grade: 'Sahih',
        similarityScore: 0.85,
      ),
      HadithSummary(
        hadithId: 2,
        bookName: 'Sahih Muslim',
        hadithNumber: '200',
        chapterNumber: '3',
        grade: 'Sahih',
        similarityScore: 0.55,
      ),
      HadithSummary(
        hadithId: 3,
        bookName: "Jami' at-Tirmidhi",
        hadithNumber: '42',
        chapterNumber: '2',
        grade: 'Hasan',
        similarityScore: 0.30,
      ),
    ];

    Widget buildSubject({List<HadithSummary>? results}) => MaterialApp(
          routes: {
            '/result_detail': (_) => const Scaffold(body: Text('Detail')),
          },
          home: ResultPage(
            userId: 1,
            query: 'prayer at night',
            results: results ?? sampleResults,
          ),
        );

    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();
      expect(find.byType(ResultPage), findsOneWidget);
    });

    testWidgets('shows Results title in AppBar', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();
      expect(find.text('Results'), findsOneWidget);
    });

    testWidgets('shows back arrow in AppBar', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('displays all result cards', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();
      expect(find.byType(HadithCard), findsNWidgets(3));
    });

    testWidgets('shows filter tag All selected by default', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();
      expect(find.text('All'), findsOneWidget);
    });

    testWidgets('shows Sahih Bukhari filter tag', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();
      expect(find.text('Sahih Bukhari'), findsWidgets);
    });

    testWidgets('shows Sahih Muslim filter tag', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();
      expect(find.text('Sahih Muslim'), findsOneWidget);
    });

    testWidgets('shows Jami-at-Tirmizi filter tag', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();
      expect(find.text('Jami-at-Tirmizi'), findsOneWidget);
    });

    testWidgets('filtering by Sahih Bukhari shows only matching cards', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sahih Bukhari').last);
      await tester.pumpAndSettle();

      expect(find.byType(HadithCard), findsOneWidget);
    });

    testWidgets('filtering by Sahih Muslim shows only matching cards', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sahih Muslim'));
      await tester.pumpAndSettle();

      expect(find.byType(HadithCard), findsOneWidget);
    });

    testWidgets('shows empty state when results list is empty', (tester) async {
      await tester.pumpWidget(buildSubject(results: []));
      await tester.pumpAndSettle();
      expect(find.byType(HadithCard), findsNothing);
    });

    testWidgets('empty state shows no results message', (tester) async {
      await tester.pumpWidget(buildSubject(results: []));
      await tester.pumpAndSettle();
      expect(find.text('No results found'), findsOneWidget);
    });

    testWidgets('tapping All filter after filtering restores full list', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // Filter to Sahih Bukhari
      await tester.tap(find.text('Sahih Bukhari').last);
      await tester.pumpAndSettle();
      expect(find.byType(HadithCard), findsOneWidget);

      // Tap All to restore
      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();
      expect(find.byType(HadithCard), findsNWidgets(3));
    });

    testWidgets('shows search_off icon in empty state', (tester) async {
      await tester.pumpWidget(buildSubject(results: []));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.search_off_rounded), findsOneWidget);
    });
  });
}
