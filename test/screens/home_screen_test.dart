import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:true_hadith/screens/home_screen.dart';

void main() {
  group('HomeScreen Tests', () {
    setUp(() {
      // Mock permission_handler — must return Map<int,int> (permission→status)
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('flutter.baseflow.com/permissions/methods'),
        (call) async {
          if (call.method == 'requestPermissions') {
            final permissions = call.arguments as List;
            // Return every requested permission as granted (status = 1)
            return Map<int, int>.fromEntries(
              permissions.map((p) => MapEntry(p as int, 1)),
            );
          }
          if (call.method == 'checkPermissionStatus') return 1;
          return null;
        },
      );
      // Mock speech_to_text
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugin.csdcorp.com/speech_to_text'),
        (call) async {
          if (call.method == 'initialize') return false;
          return null;
        },
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('flutter.baseflow.com/permissions/methods'),
        null,
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugin.csdcorp.com/speech_to_text'),
        null,
      );
    });

    Widget buildSubject() => MaterialApp(
          routes: {
            '/bookmarks': (_) => const Scaffold(body: Text('Bookmarks')),
            '/history': (_) => const Scaffold(body: Text('History')),
            '/translations': (_) => const Scaffold(body: Text('Translations')),
            '/crop_image': (_) => const Scaffold(body: Text('Crop Image')),
            '/audio_trimming': (_) => const Scaffold(body: Text('Audio Trimming')),
          },
          home: HomeScreen(
            userId: 1,
            username: 'Test User',
            createdAt: DateTime(2024, 1, 1),
            profilePhotoUrl: null,
          ),
        );

    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('shows AppBar with menu icon', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();
      expect(find.byIcon(Icons.menu), findsOneWidget);
    });

    testWidgets('shows bookmark icon in AppBar', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();
      expect(find.byIcon(Icons.bookmark_border), findsOneWidget);
    });

    testWidgets('shows search bar with hint text', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();
      expect(find.text('Search Hadiths by text, image...'), findsOneWidget);
    });

    testWidgets('shows mic icon in search bar', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();
      expect(find.byIcon(Icons.mic_none), findsOneWidget);
    });

    testWidgets('shows add icon for input options', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('shows browse description text', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();
      expect(
        find.text('Browse and search authentic Hadith collections.'),
        findsOneWidget,
      );
    });

    testWidgets('shows FloatingActionButton', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('FAB has auto_awesome icon', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();
      expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
    });

    testWidgets('search bar accepts text input', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'prayer at night');
      await tester.pump();

      expect(find.text('prayer at night'), findsOneWidget);
    });

    testWidgets('clear button appears when text is entered', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'hadith');
      await tester.pump();

      expect(find.byIcon(Icons.clear), findsOneWidget);
    });

    testWidgets('clear button removes text', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'hadith');
      await tester.pump();

      await tester.tap(find.byIcon(Icons.clear));
      await tester.pump();

      expect(find.text('hadith'), findsNothing);
    });

    testWidgets('tapping bookmark icon navigates to bookmarks', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      await tester.tap(find.byIcon(Icons.bookmark_border));
      await tester.pumpAndSettle();

      expect(find.text('Bookmarks'), findsOneWidget);
    });

    testWidgets('Scaffold has drawer', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(scaffold.drawer, isNotNull);
    });
  });
}
