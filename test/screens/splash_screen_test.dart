import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:true_hadith/screens/splash_screen.dart';

// Advances past all SplashScreen delays so no pending timers remain.
// Total sequence: 80ms + 600ms + 700ms + 1400ms + 700ms transition = 3480ms
Future<void> _flushSplashTimers(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 80));
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pump(const Duration(milliseconds: 1400));
  await tester.pumpAndSettle();
}

void main() {
  group('SplashScreen Tests', () {
    Widget buildSubject() => MaterialApp(
          home: SplashScreen(
            nextScreen: const Scaffold(body: Text('NextScreen')),
          ),
        );

    testWidgets('renders Scaffold without error', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();
      expect(find.byType(Scaffold), findsWidgets);
      await _flushSplashTimers(tester);
    });

    testWidgets('shows CustomPaint watercolor background', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();
      expect(find.byType(CustomPaint), findsWidgets);
      await _flushSplashTimers(tester);
    });

    testWidgets('contains AnimatedBuilder for animations', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();
      expect(find.byType(AnimatedBuilder), findsWidgets);
      await _flushSplashTimers(tester);
    });

    testWidgets('has Stack layout', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();
      expect(find.byType(Stack), findsWidgets);
      await _flushSplashTimers(tester);
    });

    testWidgets('shows True Hadith title after animation starts', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump(const Duration(milliseconds: 80));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 800));
      expect(find.text('True Hadith'), findsOneWidget);
      await _flushSplashTimers(tester);
    });

    testWidgets('shows tagline text after animation sequence', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump(const Duration(milliseconds: 80));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.text('VERIFY  ·  AUTHENTICATE  ·  TRUST'), findsOneWidget);
      await _flushSplashTimers(tester);
    });

    testWidgets('shows AI-Powered caption text', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump(const Duration(milliseconds: 80));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.text('AI-Powered Hadith Authentication'), findsOneWidget);
      await _flushSplashTimers(tester);
    });

    testWidgets('navigates to nextScreen after full sequence', (tester) async {
      await tester.pumpWidget(buildSubject());
      await _flushSplashTimers(tester);
      expect(find.text('NextScreen'), findsOneWidget);
    });

    testWidgets('has FadeTransition for title', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();
      expect(find.byType(FadeTransition), findsWidgets);
      await _flushSplashTimers(tester);
    });

    testWidgets('has SlideTransition for title', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();
      expect(find.byType(SlideTransition), findsWidgets);
      await _flushSplashTimers(tester);
    });

    testWidgets('has SafeArea for content layout', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();
      expect(find.byType(SafeArea), findsWidgets);
      await _flushSplashTimers(tester);
    });
  });
}
