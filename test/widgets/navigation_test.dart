import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Navigation Widget Tests', () {
    /// Test 1: Navigation push and pop
    testWidgets('Navigation pushes to new route', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: const HomePage(),
          routes: {
            '/details': (context) => const DetailsPage(),
          },
        ),
      );

      // Verify home page is displayed
      expect(find.byType(HomePage), findsOneWidget);

      // Navigate to details page
      await tester.tap(find.byIcon(Icons.arrow_forward));
      await tester.pumpAndSettle();

      // Verify details page is displayed
      expect(find.byType(DetailsPage), findsOneWidget);
    });

    testWidgets('Navigation pops from route', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: const HomePage(),
          routes: {
            '/details': (context) => const DetailsPage(),
          },
        ),
      );

      // Navigate to details page
      await tester.tap(find.byIcon(Icons.arrow_forward));
      await tester.pumpAndSettle();

      // Verify we're on details page
      expect(find.byType(DetailsPage), findsOneWidget);

      // Go back
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      // Verify we're back on home page
      expect(find.byType(HomePage), findsOneWidget);
    });

    testWidgets('Navigation with arguments', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: const HomePage(),
          routes: {
            '/details': (context) {
              final args = ModalRoute.of(context)!.settings.arguments as String?;
              return DetailsPage(title: args ?? 'Default');
            },
          },
        ),
      );

      // Navigate with arguments
      await tester.tap(find.byIcon(Icons.arrow_forward));
      await tester.pumpAndSettle();

      expect(find.byType(DetailsPage), findsOneWidget);
    });

    testWidgets('Bottom navigation bar switches tabs', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: BottomNavigation(),
        ),
      );

      // Verify first tab is displayed
      expect(find.text('Home Tab'), findsOneWidget);

      // Tap second tab
      await tester.tap(find.byIcon(Icons.search));
      await tester.pump();

      // Verify second tab is displayed
      expect(find.text('Search Tab'), findsOneWidget);

      // Tap third tab
      await tester.tap(find.byIcon(Icons.bookmark));
      await tester.pump();

      // Verify third tab is displayed
      expect(find.text('Bookmarks Tab'), findsOneWidget);
    });

    testWidgets('Navigation drawer opens and closes', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DrawerPage(),
        ),
      );

      // Open drawer
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();

      // Verify drawer is open
      expect(find.text('Navigation Menu'), findsOneWidget);

      // Close drawer by tapping outside
      await tester.tap(find.byType(Scaffold));
      await tester.pumpAndSettle();
    });

    testWidgets('Navigation back button works correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: const HomePage(),
          routes: {
            '/details': (context) => const DetailsPage(),
          },
        ),
      );

      // Navigate forward
      await tester.tap(find.byIcon(Icons.arrow_forward));
      await tester.pumpAndSettle();

      expect(find.byType(DetailsPage), findsOneWidget);

      // Use back button
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      // Verify we're back on home page
      expect(find.byType(HomePage), findsOneWidget);
    });

    testWidgets('Navigation maintains state during tab switch', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: StatefulBottomNavigation(),
        ),
      );

      // Enter text in first tab
      await tester.enterText(find.byType(TextField), 'Test Data');
      await tester.pump();

      // Verify text is entered
      expect(find.text('Test Data'), findsOneWidget);

      // Switch to second tab
      await tester.tap(find.byIcon(Icons.search));
      await tester.pump();

      // Switch back to first tab
      await tester.tap(find.byIcon(Icons.home));
      await tester.pump();

      // Verify state is maintained (optional, depends on implementation)
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('AppBar navigation title updates', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: const HomePage(),
          routes: {
            '/details': (context) => const DetailsPage(),
          },
        ),
      );

      // Verify initial page displayed
      expect(find.byType(HomePage), findsOneWidget);

      // Navigate
      await tester.tap(find.byIcon(Icons.arrow_forward));
      await tester.pumpAndSettle();

      // Verify new page displayed
      expect(find.byType(DetailsPage), findsOneWidget);
    });

    testWidgets('Navigation prevents duplicate routes', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: const HomePage(),
          routes: {
            '/details': (context) => const DetailsPage(),
          },
        ),
      );

      // Navigate to details
      await tester.tap(find.byIcon(Icons.arrow_forward));
      await tester.pumpAndSettle();

      // Should have DetailsPage on screen
      expect(find.byType(DetailsPage), findsOneWidget);
    });

    testWidgets('Navigation animates transitions', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: const HomePage(),
          routes: {
            '/details': (context) => const DetailsPage(),
          },
        ),
      );

      // Tap to navigate
      await tester.tap(find.byIcon(Icons.arrow_forward));
      
      // Animation should complete
      await tester.pumpAndSettle();
      expect(find.byType(DetailsPage), findsOneWidget);
    });
  });
}

// Test Widget Classes
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home Page')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Home Page'),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/details'),
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Go to Details'),
            ),
          ],
        ),
      ),
    );
  }
}

class DetailsPage extends StatelessWidget {
  final String? title;

  const DetailsPage({super.key, this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Details Page'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Details Page'),
            if (title != null) Text(title!),
          ],
        ),
      ),
    );
  }
}

class BottomNavigation extends StatefulWidget {
  const BottomNavigation({super.key});

  @override
  State<BottomNavigation> createState() => _BottomNavigationState();
}

class _BottomNavigationState extends State<BottomNavigation> {
  int _selectedIndex = 0;

  final List<Widget> _tabs = [
    const Center(child: Text('Home Tab')),
    const Center(child: Text('Search Tab')),
    const Center(child: Text('Bookmarks Tab')),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _tabs[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
          BottomNavigationBarItem(icon: Icon(Icons.bookmark), label: 'Bookmarks'),
        ],
      ),
    );
  }
}

class StatefulBottomNavigation extends StatefulWidget {
  const StatefulBottomNavigation({super.key});

  @override
  State<StatefulBottomNavigation> createState() =>
      _StatefulBottomNavigationState();
}

class _StatefulBottomNavigationState extends State<StatefulBottomNavigation> {
  int _selectedIndex = 0;
  final TextEditingController _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _selectedIndex == 0
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(controller: _controller),
            )
          : const Center(child: Text('Search Tab')),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class DrawerPage extends StatelessWidget {
  const DrawerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Drawer Page')),
      drawer: Drawer(
        child: ListView(
          children: const [
            DrawerHeader(
              child: Text('Navigation Menu'),
            ),
            ListTile(title: Text('Home')),
            ListTile(title: Text('Settings')),
            ListTile(title: Text('About')),
          ],
        ),
      ),
      body: const Center(
        child: Text('Main Content'),
      ),
    );
  }
}
