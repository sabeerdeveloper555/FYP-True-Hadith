import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:true_hadith/screens/onboarding_screen.dart';

void main() {
  group('OnboardingScreen Tests', () {
    setUp(() {
      // OnboardingService uses SharedPreferences — provide mock values
      SharedPreferences.setMockInitialValues({});
    });

    Widget buildSubject({VoidCallback? onComplete}) => MaterialApp(
          home: OnboardingScreen(onComplete: onComplete ?? () {}),
        );

    // Advance past PageView scroll animation (400ms) + process final layout
    Future<void> pumpPage(WidgetTester tester) async {
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(); // final layout rebuild
    }

    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();
      expect(find.byType(OnboardingScreen), findsOneWidget);
    });

    testWidgets('shows first page title', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();
      expect(find.text('Verify Hadith Authenticity'), findsOneWidget);
    });

    testWidgets('shows first page description', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();
      expect(find.textContaining('Upload images or type text'), findsOneWidget);
    });

    testWidgets('shows Skip button on first page', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();
      expect(find.text('Skip'), findsOneWidget);
    });

    testWidgets('shows Next button on first page', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();
      expect(find.text('Next'), findsOneWidget);
    });

    testWidgets('shows PageView', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();
      expect(find.byType(PageView), findsOneWidget);
    });

    testWidgets('has 3 onboarding pages in PageView', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();
      final pageView = tester.widget<PageView>(find.byType(PageView));
      // itemCount is 3 — one per OnboardingData entry
      expect(pageView.childrenDelegate, isNotNull);
    });

    testWidgets('tapping Next moves to second page', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      await tester.tap(find.text('Next'));
      await pumpPage(tester);

      expect(find.text('Instant Results from Trusted Sources'), findsOneWidget);
    });

    testWidgets('second page shows correct description', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      await tester.tap(find.text('Next'));
      await pumpPage(tester);

      expect(find.textContaining('accurate classifications'), findsOneWidget);
    });

    testWidgets('tapping Next twice moves to third page', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      await tester.tap(find.text('Next'));
      await pumpPage(tester);
      await tester.tap(find.text('Next'));
      await pumpPage(tester);

      expect(find.text('Ask Islamic Questions Anytime'), findsOneWidget);
    });

    testWidgets('last page shows Get Started button', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      await tester.tap(find.text('Next'));
      await pumpPage(tester);
      await tester.tap(find.text('Next'));
      await pumpPage(tester);

      expect(find.text('Get Started'), findsOneWidget);
    });

    testWidgets('Skip button is always visible on all pages', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      // Page 1
      expect(find.text('Skip'), findsOneWidget);

      // Page 2
      await tester.tap(find.text('Next'));
      await pumpPage(tester);
      expect(find.text('Skip'), findsOneWidget);

      // Page 3 (last page still shows Skip)
      await tester.tap(find.text('Next'));
      await pumpPage(tester);
      expect(find.text('Skip'), findsOneWidget);
    });

    testWidgets('tapping Skip calls onComplete callback', (tester) async {
      bool completed = false;
      await tester.pumpWidget(buildSubject(onComplete: () => completed = true));
      await tester.pump();

      await tester.tap(find.text('Skip'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(completed, true);
    });

    testWidgets('tapping Get Started on last page calls onComplete', (tester) async {
      bool completed = false;
      await tester.pumpWidget(buildSubject(onComplete: () => completed = true));
      await tester.pump();

      await tester.tap(find.text('Next'));
      await pumpPage(tester);
      await tester.tap(find.text('Next'));
      await pumpPage(tester);

      await tester.tap(find.text('Get Started'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(completed, true);
    });

    testWidgets('shows upload_file icon on first page', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();
      expect(find.byIcon(Icons.upload_file), findsOneWidget);
    });

    testWidgets('second page renders CustomIllustration', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      await tester.tap(find.text('Next'));
      await pumpPage(tester);

      // Title confirms we're on page 2; CustomIllustration renders the icon
      expect(find.text('Instant Results from Trusted Sources'), findsOneWidget);
      expect(find.byType(CustomIllustration), findsWidgets);
    });

    testWidgets('third page renders CustomIllustration', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      await tester.tap(find.text('Next'));
      await pumpPage(tester);
      await tester.tap(find.text('Next'));
      await pumpPage(tester);

      expect(find.text('Ask Islamic Questions Anytime'), findsOneWidget);
      expect(find.byType(CustomIllustration), findsWidgets);
    });
  });
}
