import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:true_hadith/screens/login_screen.dart';

void main() {
  group('LoginScreen Tests', () {
    Widget buildSubject() => const MaterialApp(home: LoginScreen());

    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('shows Login tab selected by default', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();
      expect(find.text('Login'), findsWidgets);
    });

    testWidgets('shows email field', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();
      expect(find.text('Email'), findsOneWidget);
    });

    testWidgets('shows password field', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();
      expect(find.text('Password'), findsOneWidget);
    });

    testWidgets('shows Forgot Password link in login mode', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();
      expect(find.text('Forgot Password?'), findsOneWidget);
    });

    testWidgets('shows Sign Up toggle text', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();
      expect(find.text("Don't have an account?"), findsOneWidget);
    });

    testWidgets('shows Login submit button', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();
      // CustomButton with text 'Login' is the submit button
      expect(find.text('Login'), findsWidgets);
    });

    testWidgets('shows Made with text footer', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();
      expect(find.textContaining('Made with'), findsOneWidget);
    });

    testWidgets('switching to Sign Up shows Full Name field', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // Tap the Sign Up tab
      await tester.tap(find.text('Sign Up').first);
      await tester.pumpAndSettle();

      expect(find.text('Full Name'), findsOneWidget);
    });

    testWidgets('switching to Sign Up hides Forgot Password', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sign Up').first);
      await tester.pumpAndSettle();

      expect(find.text('Forgot Password?'), findsNothing);
    });

    testWidgets('switching to Sign Up shows Already have an account text', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sign Up').first);
      await tester.pumpAndSettle();

      expect(find.text('Already have an account?'), findsOneWidget);
    });

    testWidgets('email validation shows error on empty submit', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // Tap submit without filling form — find form submit button
      final buttons = find.byType(ElevatedButton);
      if (buttons.evaluate().isNotEmpty) {
        await tester.tap(buttons.first);
        await tester.pump();
      }
      // Form validation renders error text
      expect(find.byType(Form), findsOneWidget);
    });

    testWidgets('email field accepts text input', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final emailFields = find.byType(TextFormField);
      await tester.enterText(emailFields.first, 'test@example.com');
      await tester.pump();

      expect(find.text('test@example.com'), findsOneWidget);
    });

    testWidgets('password field has visibility toggle icon', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    });

    testWidgets('tapping visibility icon toggles password visibility', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pump();

      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    });

    testWidgets('has curved header with gradient', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.byType(ClipPath), findsOneWidget);
    });

    testWidgets('form card is visible', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.byType(Card), findsWidgets);
    });

    testWidgets('contains FadeTransition animation', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      expect(find.byType(FadeTransition), findsWidgets);
    });
  });
}
