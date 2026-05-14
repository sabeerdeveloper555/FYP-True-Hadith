import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:true_hadith/widgets/hadith_card.dart';
import 'package:true_hadith/models/hadith_models.dart';

void main() {
  final sample = HadithSummary(
    hadithId: 1,
    bookName: 'Sahih Bukhari',
    hadithNumber: '123',
    chapterNumber: '5',
    grade: 'Sahih',
    similarityScore: 0.9,
  );

  testWidgets('HadithCard onTap is called and highlight sets elevation', (WidgetTester tester) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HadithCard(
            summary: sample,
            onTap: () => tapped = true,
            highlightColor: Colors.green,
          ),
        ),
      ),
    );

    // Card elevation should be 4 when highlightColor is provided
    final card = tester.widget<Card>(find.byType(Card).first);
    expect(card.elevation, equals(4));

    // Tap the card (InkWell) and ensure onTap is invoked
    await tester.tap(find.byType(InkWell));
    await tester.pump();

    expect(tapped, isTrue);
  });
}
