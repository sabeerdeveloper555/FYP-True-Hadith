# Flutter Widget Testing Guide

## Table of Contents
1. [Introduction to Widget Testing](#introduction)
2. [Setup & Prerequisites](#setup)
3. [Core Concepts](#core-concepts)
4. [Common Widget Test Patterns](#patterns)
5. [Testing Your Widgets](#testing-your-widgets)
6. [Best Practices](#best-practices)
7. [Running Tests](#running-tests)

---

## Introduction to Widget Testing {#introduction}

Widget tests are essential for validating Flutter UI behavior. Unlike integration tests (which require a device/emulator), widget tests run on your development machine in a controlled environment.

### What to Test
- **UI Rendering**: Verify widgets render correctly
- **User Interactions**: Test button taps, text input, scrolling
- **State Management**: Ensure state changes update the UI
- **Navigation**: Test route transitions
- **Theme Handling**: Verify dark/light mode rendering
- **Accessibility**: Check semantic labels and text

---

## Setup & Prerequisites {#setup}

### Required Dependencies
Your `pubspec.yaml` should already have:
```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
```

### Test File Structure
```
project_root/
└── test/
    ├── widget_test.dart           # Main test file
    ├── widgets/
    │   ├── hadith_card_test.dart
    │   ├── search_bar_test.dart
    │   └── navigation_test.dart
    └── integration_test/           # For end-to-end tests
```

---

## Core Concepts {#core-concepts}

### 1. WidgetTester
The `WidgetTester` object gives you access to widget testing utilities:
```dart
testWidgets('Description', (WidgetTester tester) async {
  // tester provides methods to interact with widgets
});
```

### 2. Key Methods

#### Finding Widgets
```dart
// Find by widget type
find.byType(TextField)

// Find by text
find.text('Hello')

// Find by icon
find.byIcon(Icons.search)

// Find by key
find.byKey(Key('submit_btn'))

// Find by tooltip
find.byTooltip('Clear')

// Combinations
find.byType(IconButton).first
find.byType(ListTile).at(2)
```

#### Matching Methods
```dart
findsOneWidget          // Exactly one match
findsNWidgets(2)        // Exactly N widgets
findsWidgets            // One or more
findsNothing            // No matches
```

#### User Interactions
```dart
// Tap a widget
await tester.tap(find.byType(ElevatedButton));

// Enter text
await tester.enterText(find.byType(TextField), 'hello');

// Type specific text
await tester.typeText(find.byType(TextField), 'text');

// Drag and drop
await tester.drag(find.byType(Scrollable), Offset(0, -300));

// Long press
await tester.longPress(find.byType(Card));

// Pinch zoom
await tester.pinch(find.byType(Image), scale: 2.0);

// Scroll
await tester.scrollUntilVisible(
  find.text('Item 50'),
  500,
  scrollable: find.byType(Scrollable).first,
);
```

#### Frame Updates
```dart
// Trigger a frame
await tester.pump();

// Trigger multiple frames with delay
await tester.pump(Duration(seconds: 1));

// Waits for all animations to complete
await tester.pumpAndSettle();

// Build and render widget
await tester.pumpWidget(MaterialApp(home: MyWidget()));
```

#### Verifications
```dart
// Verify widget properties
expect(find.text('Save'), findsOneWidget);

// Verify multiple matches
expect(find.byType(ListTile), findsWidgets);

// Verify not found
expect(find.text('Deleted'), findsNothing);

// Custom matchers
expect(widget.isEnabled, true);
expect(Colors.blue, Color(0xFF0000FF));
```

---

## Common Widget Test Patterns {#patterns}

### Pattern 1: Testing Text Input
```dart
testWidgets('TextField accepts input', (WidgetTester tester) async {
  final controller = TextEditingController();
  
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: TextField(controller: controller),
      ),
    ),
  );

  await tester.enterText(find.byType(TextField), 'Hello');
  expect(controller.text, 'Hello');
});
```

### Pattern 2: Testing Button Callbacks
```dart
testWidgets('Button calls onPressed', (WidgetTester tester) async {
  bool wasPressed = false;

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ElevatedButton(
          onPressed: () => wasPressed = true,
          child: Text('Click Me'),
        ),
      ),
    ),
  );

  await tester.tap(find.byType(ElevatedButton));
  expect(wasPressed, true);
});
```

### Pattern 3: Testing Navigation
```dart
testWidgets('Navigation works', (WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: HomePage(),
      routes: {
        '/details': (context) => DetailsPage(),
      },
    ),
  );

  // Navigate
  await tester.tap(find.byIcon(Icons.arrow_forward));
  await tester.pumpAndSettle();

  expect(find.byType(DetailsPage), findsOneWidget);
});
```

### Pattern 4: Testing ListViews
```dart
testWidgets('ListView displays items', (WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ListView(
          children: [
            ListTile(title: Text('Item 1')),
            ListTile(title: Text('Item 2')),
            ListTile(title: Text('Item 3')),
          ],
        ),
      ),
    ),
  );

  expect(find.byType(ListTile), findsNWidgets(3));
  expect(find.text('Item 1'), findsOneWidget);
});
```

### Pattern 5: Testing Forms
```dart
testWidgets('Form validation', (WidgetTester tester) async {
  final formKey = GlobalKey<FormState>();

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Form(
          key: formKey,
          child: Column(
            children: [
              TextFormField(validator: (value) {
                if (value?.isEmpty ?? true) return 'Required';
                return null;
              }),
              ElevatedButton(
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    // Form is valid
                  }
                },
                child: Text('Submit'),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.byType(ElevatedButton));
  await tester.pump();

  // Form validation error should be shown
  expect(find.text('Required'), findsOneWidget);
});
```

### Pattern 6: Testing State Changes
```dart
testWidgets('Widget state updates', (WidgetTester tester) async {
  await tester.pumpWidget(MaterialApp(home: Counter()));

  expect(find.text('0'), findsOneWidget);

  await tester.tap(find.byIcon(Icons.add));
  await tester.pump();

  expect(find.text('1'), findsOneWidget);
});
```

### Pattern 7: Testing Theme/Dark Mode
```dart
testWidgets('Dark mode rendering', (WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: ThemeMode.dark,
      home: MyWidget(),
    ),
  );

  expect(find.byType(MyWidget), findsOneWidget);
});
```

### Pattern 8: Testing Async Operations
```dart
testWidgets('Async operation completes', (WidgetTester tester) async {
  await tester.pumpWidget(MaterialApp(home: DataFetcher()));

  // Wait for API call
  await tester.pumpAndSettle();

  // Verify data is displayed
  expect(find.text('Data Loaded'), findsOneWidget);
});
```

---

## Testing Your Widgets {#testing-your-widgets}

### For HadithCard Widget
Key test areas:
- ✅ Card renders with book name and hadith number
- ✅ Highlight color applies when provided
- ✅ Bookmark button appears when userId is set
- ✅ onTap callback is triggered
- ✅ Text content displays correctly (Arabic, English, Urdu)

### For SearchBar Widget
Key test areas:
- ✅ Text input acceptance
- ✅ Text clearing functionality
- ✅ onChanged callback
- ✅ Voice input button integration
- ✅ Suggestions display

### For Navigation Widgets
Key test areas:
- ✅ Route navigation (push/pop)
- ✅ Bottom navigation tab switching
- ✅ Drawer open/close
- ✅ Back button functionality
- ✅ Route animations

---

## Best Practices {#best-practices}

### 1. Use Keys for Widget Selection
```dart
// ❌ Don't rely on finding by type alone
find.byType(ElevatedButton)

// ✅ Use keys for clarity
ElevatedButton(key: Key('submit'), ...)
find.byKey(Key('submit'))
```

### 2. Clean Up Resources
```dart
tearDown(() {
  controller.dispose();
  focusNode.dispose();
});
```

### 3. Use Semantic Matchers
```dart
// ❌ Fragile
find.text('Item 5')

// ✅ More robust
find.byKey(Key('item_5'))
find.bySemanticsLabel('Item 5')
```

### 4. Test User Flows, Not Implementation
```dart
// ❌ Testing internal state
expect(widget.state.isLoading, false)

// ✅ Testing UI output
expect(find.byType(LoadingSpinner), findsNothing)
```

### 5. Group Related Tests
```dart
group('HadithCard', () {
  group('Rendering', () { ... })
  group('Interactions', () { ... })
  group('Theming', () { ... })
})
```

### 6. Use Fixtures for Test Data
```dart
HadithSummary createTestHadith({
  String bookName = 'Sahih Bukhari',
  double similarityScore = 0.85,
}) {
  return HadithSummary(
    hadithId: 1,
    bookName: bookName,
    similarityScore: similarityScore,
    // ...other fields
  );
}
```

---

## Running Tests {#running-tests}

### Run All Tests
```bash
flutter test
```

### Run Specific Test File
```bash
flutter test test/widgets/hadith_card_test.dart
```

### Run Specific Test
```bash
flutter test -k "HadithCard displays"
```

### Run with Coverage
```bash
# Install coverage tools
pub global activate coverage

# Run tests with coverage
flutter test --coverage

# View coverage report
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

### Run in Verbose Mode
```bash
flutter test -v
```

### Watch Mode (Reruns on File Changes)
```bash
flutter test --watch
```

### Run Integration Tests
```bash
flutter test integration_test/
```

---

## Debugging Tests

### Print Widget Tree
```dart
debugPrintBeginFrame();
debugPrintEndFrame();
debugPrint(find.byType(Text).evaluate().toString());
```

### Use Debugger
```dart
// Add breakpoint in test
await tester.pumpWidget(MyApp());
// Pause here to inspect state
```

### Take Screenshots
```dart
await expectLater(
  find.byType(MyWidget),
  matchesGoldenFile('my_widget.png'),
);
```

### Print All Widgets
```dart
debugPrintWidgetTree();
```

---

## Performance Testing

### Measure Build Time
```dart
testWidgets('Performance test', (WidgetTester tester) async {
  final stopwatch = Stopwatch()..start();
  
  await tester.pumpWidget(MyComplexWidget());
  
  stopwatch.stop();
  print('Build time: ${stopwatch.elapsedMilliseconds}ms');
  expect(stopwatch.elapsedMilliseconds < 1000, true);
});
```

---

## Common Errors & Solutions

| Error | Cause | Solution |
|-------|-------|----------|
| `findsOneWidget` fails | Widget not found | Check widget tree with `debugPrintWidgetTree()` |
| `No Material widget found` | Missing MaterialApp | Wrap test widget with `MaterialApp` |
| `RenderFlex overflow` | Layout too large | Add `SingleChildScrollView` or size constraints |
| `Exception: Could not find a generator...` | Serialization error | Add `@immutable` to model classes |
| `null check operator` | Widget disposed | Check `mounted` before `setState` |

---

## Running Your True Hadith Tests

```bash
# Run all widget tests
flutter test test/widgets/

# Run specific widget tests
flutter test test/widgets/hadith_card_test.dart
flutter test test/widgets/search_bar_test.dart
flutter test test/widgets/navigation_test.dart

# Run with verbose output
flutter test test/widgets/ -v

# Generate coverage report
flutter test --coverage
```

---

## Additional Resources

- [Flutter Testing Documentation](https://flutter.dev/docs/testing)
- [Widget Test API](https://api.flutter.dev/flutter/flutter_test/flutter_test-library.html)
- [Testing Widgets](https://flutter.dev/docs/testing/testing-reference)
- [Integration Testing](https://flutter.dev/docs/testing/integration-tests)
