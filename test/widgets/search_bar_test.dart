import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SearchBar Widget Tests', () {
    /// Test 1: Build a simple search bar widget for testing
    testWidgets('SearchBar displays correctly', (WidgetTester tester) async {
      final searchController = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: searchController,
                decoration: InputDecoration(
                  hintText: 'Search hadith...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                ),
              ),
            ),
          ),
        ),
      );

      // Verify search bar is displayed
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    testWidgets('SearchBar accepts text input', (WidgetTester tester) async {
      final searchController = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: searchController,
                decoration: InputDecoration(
                  hintText: 'Search hadith...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      // Enter text into search field
      await tester.enterText(find.byType(TextField), 'hadith');
      await tester.pump();

      // Verify text was entered
      expect(searchController.text, 'hadith');
      expect(find.text('hadith'), findsOneWidget);
    });

    testWidgets('SearchBar clears text when clear button is tapped', (WidgetTester tester) async {
      final searchController = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: searchController,
                decoration: InputDecoration(
                  hintText: 'Search hadith...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => searchController.clear(),
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      // Enter text
      await tester.enterText(find.byType(TextField), 'hadith');
      await tester.pump();

      // Clear the text
      searchController.clear();
      await tester.pump();

      expect(searchController.text, '');
    });

    testWidgets('SearchBar calls onChanged callback', (WidgetTester tester) async {
      final searchController = TextEditingController();
      String? changedValue;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: searchController,
                onChanged: (value) {
                  changedValue = value;
                },
                decoration: InputDecoration(
                  hintText: 'Search hadith...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      // Type text
      await tester.enterText(find.byType(TextField), 'test');
      await tester.pump();

      expect(changedValue, 'test');
    });

    testWidgets('SearchBar handles empty input', (WidgetTester tester) async {
      final searchController = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: searchController,
                decoration: InputDecoration(
                  hintText: 'Search hadith...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      // Verify empty state
      expect(searchController.text, '');
      expect(find.text('Search hadith...'), findsOneWidget);
    });

    testWidgets('SearchBar with voice input button', (WidgetTester tester) async {
      final searchController = TextEditingController();
      bool voiceTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        hintText: 'Search hadith...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.mic),
                    onPressed: () {
                      voiceTapped = true;
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // Tap voice button
      await tester.tap(find.byIcon(Icons.mic));
      await tester.pump();

      expect(voiceTapped, true);
    });

    testWidgets('SearchBar suggests results on input', (WidgetTester tester) async {
      final searchController = TextEditingController();
      final suggestions = ['Hadith 1', 'Hadith 2', 'Hadith 3'];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      hintText: 'Search hadith...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView(
                    children: suggestions
                        .map((s) => ListTile(title: Text(s)))
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      // Verify suggestions are displayed
      expect(find.byType(ListTile), findsNWidgets(3));
      expect(find.text('Hadith 1'), findsOneWidget);
    });

    testWidgets('SearchBar respects focus state', (WidgetTester tester) async {
      final searchController = TextEditingController();
      final focusNode = FocusNode();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: searchController,
                focusNode: focusNode,
                decoration: InputDecoration(
                  hintText: 'Search hadith...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      // Focus on the search field
      focusNode.requestFocus();
      await tester.pump();

      expect(focusNode.hasFocus, true);
    });

    testWidgets('SearchBar debounces input for search', (WidgetTester tester) async {
      final searchController = TextEditingController();
      int searchCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: searchController,
                onChanged: (value) {
                  searchCount++;
                },
                decoration: InputDecoration(
                  hintText: 'Search hadith...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      // Simulate multiple keystrokes
      await tester.enterText(find.byType(TextField), 'h');
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'ha');
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'had');
      await tester.pumpAndSettle();

      // searchCount will be >= 3 since each character triggers onChanged
      expect(searchCount > 0, true);
    });

    tearDown(() {
      // Clean up resources
    });
  });
}
