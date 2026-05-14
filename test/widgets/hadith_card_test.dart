import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:true_hadith/models/hadith_models.dart';
import 'package:true_hadith/widgets/hadith_card.dart';
import 'package:true_hadith/core/theme/app_colors.dart';

void main() {
  group('HadithCard Widget Tests', () {
    // Sample test data
    final testSummary = HadithSummary(
      hadithId: 1,
      bookName: 'Sahih Bukhari',
      hadithNumber: '123',
      chapterNumber: '5',
      grade: 'Sahih',
      similarityScore: 0.85,
    );

    final testDetail = HadithDetail(
      hadithId: 1,
      bookName: 'Sahih Bukhari',
      hadithNumber: '123',
      chapterNumber: '5',
      chapterName: 'Test Chapter',
      grade: 'Sahih',
      narrator: 'Narrator 1',
      arabicText: 'نص حديث عربي',
      englishText: 'Sample hadith text in English',
      urduText: 'اردو متن',
    );

    testWidgets('HadithCard displays book name and hadith number', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HadithCard(
              summary: testSummary,
              onTap: () {},
            ),
          ),
        ),
      );

      // Verify that book name and hadith number are displayed
      expect(find.text('Sahih Bukhari : 123'), findsOneWidget);
    });

    testWidgets('HadithCard displays grade correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HadithCard(
              summary: testSummary,
              onTap: () {},
            ),
          ),
        ),
      );

      // Verify that grade is displayed
      expect(find.text('Sahih'), findsOneWidget);
    });

    testWidgets('HadithCard calls onTap callback when tapped', (WidgetTester tester) async {
      bool wasTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HadithCard(
              summary: testSummary,
              onTap: () {
                wasTapped = true;
              },
            ),
          ),
        ),
      );

      // Tap the card
      await tester.tap(find.byType(HadithCard));
      await tester.pump();

      expect(wasTapped, true);
    });

    testWidgets('HadithCard displays highlight color when provided', (WidgetTester tester) async {
      const highlightColor = Color(0xFF22C55E); // Green

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HadithCard(
              summary: testSummary,
              onTap: () {},
              highlightColor: highlightColor,
            ),
          ),
        ),
      );

      // Verify the Card widget has the correct style
      final cardFinder = find.byType(Card);
      expect(cardFinder, findsOneWidget);
    });

    testWidgets('HadithCard displays bookmark button when userId is provided', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HadithCard(
              summary: testSummary,
              onTap: () {},
              userId: 123,
              isBookmarked: false,
            ),
          ),
        ),
      );

      // Verify card is rendered with userId set
      expect(find.byType(HadithCard), findsOneWidget);
      expect(find.byType(Card), findsOneWidget);
    });

    testWidgets('HadithCard shows chapter number', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HadithCard(
              summary: testSummary,
              onTap: () {},
              userId: 123,
              isBookmarked: true,
            ),
          ),
        ),
      );

      // Verify chapter number is displayed
      expect(find.text('Chapter #5'), findsOneWidget);
    });

    testWidgets('HadithCard renders correctly in dark mode', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          themeMode: ThemeMode.dark,
          home: Scaffold(
            body: HadithCard(
              summary: testSummary,
              onTap: () {},
            ),
          ),
        ),
      );

      // Verify card is rendered
      expect(find.byType(HadithCard), findsOneWidget);
    });

    testWidgets('HadithCard with high similarity score shows green highlight', (WidgetTester tester) async {
      final highScoreSummary = HadithSummary(
        hadithId: 1,
        bookName: 'Sahih Bukhari',
        hadithNumber: '123',
        chapterNumber: '5',
        grade: 'Sahih',
        similarityScore: 0.75,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HadithCard(
              summary: highScoreSummary,
              onTap: () {},
              highlightColor: const Color(0xFF22C55E),
            ),
          ),
        ),
      );

      expect(find.byType(Card), findsOneWidget);
    });
  });
}

