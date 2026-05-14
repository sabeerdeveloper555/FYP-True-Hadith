# Flutter Widget Testing - Quick Reference

## 📋 Quick Commands

```bash
# Run all widget tests
flutter test test/widgets/

# Run specific test file
flutter test test/widgets/hadith_card_test.dart
flutter test test/widgets/search_bar_test.dart
flutter test test/widgets/navigation_test.dart

# Run specific test by name
flutter test -k "HadithCard displays"

# Run with verbose output
flutter test test/widgets/ -v

# Run with coverage
flutter test --coverage

# Watch mode (auto-rerun on changes)
flutter test --watch
```

---

## 🧪 Testing Essentials

### Finding Widgets
```dart
find.byType(MyWidget)                 // By type
find.text('Search')                   // By text
find.byIcon(Icons.search)             // By icon
find.byKey(Key('button_id'))         // By key
find.byTooltip('Clear search')       // By tooltip
find.bySemanticsLabel('Search bar')  // By semantic label
```

### User Interactions
```dart
await tester.tap(finder)                           // Single tap
await tester.longPress(finder)                    // Long press
await tester.enterText(finder, 'text')            // Text input
await tester.pumpWidget(widget)                   // Build widget
await tester.pump()                               // One frame
await tester.pump(Duration(seconds: 1))           // Frame + delay
await tester.pumpAndSettle()                      // Wait for animation
await tester.scroll(finder, Offset(0, -300))      // Scroll
```

### Assertions
```dart
expect(find.byType(Card), findsOneWidget)         // Exactly 1
expect(find.byType(ListTile), findsWidgets)       // 1 or more
expect(find.text('Not found'), findsNothing)      // 0 matches
expect(find.byType(Button), findsNWidgets(3))     // Exactly N
```

---

## 📝 Test Template

```dart
void main() {
  group('Widget Tests', () {
    testWidgets('Description', (WidgetTester tester) async {
      // Setup
      await tester.pumpWidget(
        MaterialApp(
          home: MyWidget(),
        ),
      );
      
      // Act
      await tester.tap(find.byType(Button));
      await tester.pump();
      
      // Assert
      expect(find.text('Result'), findsOneWidget);
    });
  });
}
```

---

## 🎯 Common Test Patterns

### Test Button Click
```dart
bool clicked = false;
await tester.pumpWidget(
  MaterialApp(
    home: ElevatedButton(
      onPressed: () => clicked = true,
      child: Text('Click'),
    ),
  ),
);
await tester.tap(find.byType(ElevatedButton));
expect(clicked, true);
```

### Test Text Input
```dart
final controller = TextEditingController();
await tester.pumpWidget(
  MaterialApp(
    home: TextField(controller: controller),
  ),
);
await tester.enterText(find.byType(TextField), 'Hello');
expect(controller.text, 'Hello');
```

### Test Navigation
```dart
await tester.pumpWidget(
  MaterialApp(
    home: HomePage(),
    routes: {
      '/details': (ctx) => DetailsPage(),
    },
  ),
);
await tester.tap(find.byIcon(Icons.arrow_forward));
await tester.pumpAndSettle();
expect(find.byType(DetailsPage), findsOneWidget);
```

### Test ListView
```dart
await tester.pumpWidget(
  MaterialApp(
    home: ListView(
      children: [
        Text('Item 1'),
        Text('Item 2'),
      ],
    ),
  ),
);
expect(find.text('Item 1'), findsOneWidget);
```

---

## 🔧 Debugging

```dart
// Print widget tree
debugPrintWidgetTree();

// Print element tree
tester.element(find.byType(MyWidget));

// Get diagnostics
final diagnostics = tester.getSemantics(find.byType(MyWidget));

// Print all Text widgets
debugPrint(find.byType(Text).evaluate().toString());
```

---

## 📊 Our Test Suite

| Component | Tests | Status |
|-----------|-------|--------|
| HadithCard Widget | 8 | ✅ PASS |
| SearchBar Widget | 9 | ✅ PASS |
| Navigation | 10 | ✅ PASS |
| **Total** | **27** | **✅ PASS** |

---

## 📂 File Structure

```
test/
├── widget_test.dart
└── widgets/
    ├── hadith_card_test.dart    (8 tests)
    ├── search_bar_test.dart     (9 tests)
    └── navigation_test.dart     (10 tests)
```

---

## 🚀 Running Your Tests

**Step 1**: Navigate to project root
```bash
cd "e:\FlutterDev\true hadith"
```

**Step 2**: Run tests
```bash
# All tests
flutter test test/widgets/

# Specific component
flutter test test/widgets/hadith_card_test.dart

# Watch mode for development
flutter test --watch
```

**Step 3**: View results
- All tests should pass with ✅
- Test names will show in output
- Times will be displayed for each test

---

## 🎓 Key Concepts

### WidgetTester
The main object for running tests. Provides methods to:
- Find widgets in the widget tree
- Simulate user interactions
- Trigger frames and animations
- Make assertions

### pump() vs pumpAndSettle()
- `pump()` - Triggers one frame
- `pumpAndSettle()` - Waits for all animations to complete

### Finders
Objects that locate widgets using `find.*` methods:
- `byType()` - Most reliable
- `byText()` - For displayed text
- `byIcon()` - For icon buttons
- `byKey()` - Most specific

### Expectations
Assertions using `expect()`:
- `findsOneWidget` - Exactly 1 match
- `findsWidgets` - 1 or more
- `findsNothing` - 0 matches
- `findsNWidgets(n)` - Exactly n

---

## 📚 Documentation

Full guides available:
- [WIDGET_TESTING_GUIDE.md](WIDGET_TESTING_GUIDE.md) - Comprehensive guide
- [TEST_EXECUTION_SUMMARY.md](TEST_EXECUTION_SUMMARY.md) - Test results & details

---

## ✨ Tips & Tricks

1. **Use Keys for Complex Widgets**
   ```dart
   ElevatedButton(key: Key('submit_btn'), ...)
   find.byKey(Key('submit_btn'))
   ```

2. **Group Related Tests**
   ```dart
   group('Card Rendering', () { ... })
   group('User Interactions', () { ... })
   ```

3. **Create Test Data Builders**
   ```dart
   HadithSummary createTestHadith({String? name}) {
     return HadithSummary(name: name ?? 'Test', ...);
   }
   ```

4. **Clean Up Resources**
   ```dart
   tearDown(() {
     controller.dispose();
     focusNode.dispose();
   });
   ```

5. **Test Semantics for Accessibility**
   ```dart
   expect(find.bySemanticsLabel('Search'), findsOneWidget);
   ```

---

## ❓ FAQ

**Q: Why use `pumpAndSettle()` instead of `pump()`?**  
A: `pumpAndSettle()` waits for animations to complete, preventing flaky tests.

**Q: How do I test async operations?**  
A: Use `await tester.pumpAndSettle()` after async calls complete.

**Q: Can I test real API calls?**  
A: Mock the API service using `mockito` or `mocktail` packages.

**Q: How do I test deep links?**  
A: Use `tester.binding.window.physicalSizeTestValue` to simulate navigation.

---

Generated: May 14, 2026
