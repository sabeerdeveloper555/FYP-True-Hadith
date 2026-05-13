# True Hadith — Flutter App

AI-powered hadith verification app supporting text search, OCR, voice input, audio transcription, a chatbot, bookmarks, and history — with Arabic, English, and Urdu support.

---

## Issues Found

The following five issues were identified in the codebase before fixes were applied.

---

### Issue 1 — Google Translate API Key Hardcoded in Source Code

**File:** `lib/core/config.dart`

The Google Translate API key was stored as a plain string constant directly in source code. Anyone who decompiles the APK binary can extract this key and use it freely — all charges would apply to the project owner's billing account.

```dart
// BEFORE (unsafe)
static const String googleTranslateApiKey = 'AIzaSyCM...';
```

---

### Issue 2 — Hardcoded Local IP Address for Backend URL

**File:** `lib/services/api_service.dart`

The backend base URL was set to a hardcoded local network IP (`192.168.100.12`). This only works on the developer's own machine on the same WiFi network. Any other device — including a demo machine, a professor's device, or a real user — will fail to connect to the backend entirely.

```dart
// BEFORE (broken outside developer's network)
static const String baseUrl = 'http://192.168.100.12:5000/api';
```

---

### Issue 3 — Missing `mounted` Check Before `setState` After Async Calls

**File:** `lib/screens/result_detail_page.dart`

The `_loadHadithDetail()` method calls `setState` after an async API call with no check that the widget is still in the tree. If the user navigates away before the response arrives, the widget is disposed and calling `setState` on it throws a runtime exception causing a crash.

```dart
// BEFORE (crashes if user navigates away during load)
final result = await ApiService.getHadithDetailWithBookmark(...);
setState(() {
  _detail = result['detail'] as HadithDetail;
  _isLoading = false;
});
```

---

### Issue 4 — Silent `catch (_)` Swallows Errors Without Any Feedback

**File:** `lib/screens/chatbot_screen.dart`

Two catch blocks used `catch (_)` which discards the error completely — no logging, no user notification. When conversation loading or message loading fails, the user sees a blank screen with no explanation, and the developer has no information to diagnose the problem.

```dart
// BEFORE (errors silently ignored)
} catch (_) {
  if (mounted) setState(() => _isLoadingConversations = false);
}
```

---

### Issue 5 — Audio Temp File Deleted Before Request Is Sent

**File:** `lib/services/transcription_service.dart`

After trimming an audio clip, the temporary file was deleted *before* calling `request.send()`. Since `MultipartFile.fromPath` reads the file lazily at send time, deleting it first could cause the upload to fail. Additionally, if the request threw an exception, the cleanup would not run. The deletion should happen in a `finally` block after the request completes.

```dart
// BEFORE (file deleted before request is sent)
request.files.add(await http.MultipartFile.fromPath('audio', finalAudioPath));
if (finalAudioPath != audioPath) {
  await audioFile.delete(); // ← happens before request.send()
}
final streamedResponse = await request.send();
```

---

## Fixes Applied

The following fixes were applied to resolve all five issues above.

---

### Fix 1 — API Key Moved to Build-Time Environment Variable

**File:** `lib/core/config.dart`

The key is now read from a `--dart-define` build flag instead of being hardcoded. It is no longer present in source code. Pass it at build or run time:

```bash
flutter run --dart-define=GOOGLE_TRANSLATE_API_KEY=your_key_here
flutter build apk --dart-define=GOOGLE_TRANSLATE_API_KEY=your_key_here
```

---

### Fix 2 — Backend URL Configurable via Build Flag

**File:** `lib/services/api_service.dart`

The base URL is now read from `--dart-define` at build time, with the local IP kept as a development fallback. Different environments (local, staging, production) can be targeted without changing source code:

```bash
flutter run --dart-define=BACKEND_URL=http://192.168.100.12:5000/api
flutter build apk --dart-define=BACKEND_URL=https://your-production-server/api
```

---

### Fix 3 — `mounted` Guard Added Before All `setState` Calls

**File:** `lib/screens/result_detail_page.dart`

Added `if (!mounted) return;` immediately after every `await` in `_loadHadithDetail()`, before any `setState` call. This ensures that if the widget is disposed while an API call is in flight, no state update is attempted and no crash occurs.

---

### Fix 4 — Errors Now Logged and Shown to User

**File:** `lib/screens/chatbot_screen.dart`

Replaced `catch (_)` with `catch (e)` in both `_loadConversations` and `_loadConversation`. Errors are now printed for developer diagnosis and surfaced to the user via a `SnackBar` so they are not left with a silent blank screen.

---

### Fix 5 — Temp File Cleanup Moved to `finally` Block

**File:** `lib/services/transcription_service.dart`

The trimmed audio file is now read into bytes before building the multipart request, so the file handle is released immediately. Cleanup of the temp file runs inside a `finally` block that executes whether the request succeeds or fails, preventing orphaned temporary files from accumulating on the device.

---

---

## Bug Fixes — Round 2

The following eight bugs were identified and fixed in a subsequent analysis pass.

---

### Bug 1 — Race Condition: Chatbot Loading Message Removed by Wrong Index

**File:** `lib/screens/chatbot_screen.dart`  
**Severity:** Critical

The index of the loading bubble was captured before it was added to `_messages`. If the user sent another message before the first response arrived, indices shifted and `removeAt(loadingMessageIndex)` removed the wrong message — or threw a `RangeError` crash.

```dart
// BEFORE (index can shift before removeAt runs)
final loadingMessageIndex = _messages.length;
setState(() { _messages.add(loadingMsg); });
...
_messages.removeAt(loadingMessageIndex); // Wrong item if list changed
```

**Fix:** Store a reference to the loading message object and use `_messages.remove(loadingMsg)`, which finds the exact object by identity regardless of index changes.

```dart
// AFTER (object reference, always removes the right bubble)
final loadingMsg = ChatMessage(text: 'Thinking...', isLoading: true, ...);
setState(() { _messages.add(loadingMsg); });
...
_messages.remove(loadingMsg); // Correct — identity-based removal
```

---

### Bug 2 — Memory Leak: Auth Stream Subscription Never Cancelled

**File:** `lib/main.dart`  
**Severity:** Critical

`AuthService.authStateChanges.listen(...)` was called but the returned `StreamSubscription` was never stored or cancelled. The listener remained alive after `_AuthWrapperState` was disposed, holding a reference to the widget and leaking memory. Calling `setState` from a disposed widget also triggers a Flutter framework error.

```dart
// BEFORE (subscription discarded — never cancelled)
_authStateStream.listen((user) {
  setState(() { ... }); // Can fire after dispose
});
```

**Fix:** Store the subscription and cancel it in `dispose()`. Also added a `mounted` guard inside the listener.

```dart
// AFTER
_authSubscription = AuthService.authStateChanges.listen((user) {
  if (mounted) setState(() { ... });
});

@override
void dispose() {
  _authSubscription?.cancel();
  _linkSubscription?.cancel();
  super.dispose();
}
```

---

### Bug 3 — Crash: `.toString()` Called on Nullable Map Values

**File:** `lib/services/api_service.dart` (lines 255, 346–347, 398–399)  
**Severity:** High

In three places, `item['field'].toString()` was called directly on values from a decoded JSON map. If the backend omits a field or sends `null`, this throws a `NoSuchMethodError` and crashes the app.

```dart
// BEFORE (crashes if key is absent or null)
hadithNumber: item['hadith_number'].toString(),
chapterNumber: item['chapter_number'].toString(),
```

**Fix:** Use null-safe access with a fallback empty string.

```dart
// AFTER
hadithNumber: item['hadith_number']?.toString() ?? '',
chapterNumber: item['chapter_number']?.toString() ?? '',
```

---

### Bug 4 — Contradictory Error Handling in Storage Service

**File:** `lib/services/storage_service.dart`  
**Severity:** High

The catch block in `deleteProfilePhoto` had a comment saying *"don't throw (file might not exist)"* but immediately called `rethrow`, causing callers to always receive the exception. This made a best-effort cleanup operation behave like a fatal failure.

```dart
// BEFORE (comment contradicts the code)
} catch (e) {
  // If deletion fails, log but don't throw (file might not exist)
  print('Warning: ...');
  rethrow; // ← throws anyway
}
```

**Fix:** Removed `rethrow` so the catch block matches its stated intent. Replaced `print` with `debugPrint`.

```dart
// AFTER
} catch (e) {
  // Log but don't throw — file may already be deleted or never existed.
  debugPrint('Warning: Failed to delete profile photo: ${e.toString()}');
}
```

---

### Bug 5 — Unhandled `TimeoutException` in Translation Service

**File:** `lib/services/translation_service.dart`  
**Severity:** High

`.timeout(const Duration(seconds: 15))` on the HTTP call throws a `TimeoutException` from `dart:async` when it expires. This exception was not caught, propagating up uncaught and crashing the UI with an unhandled exception.

```dart
// BEFORE (TimeoutException not caught)
final response = await http.post(uri, ...).timeout(const Duration(seconds: 15));
```

**Fix:** Added `dart:async` import and an explicit `on TimeoutException` handler.

```dart
// AFTER
try {
  final response = await http.post(uri, ...).timeout(const Duration(seconds: 15));
  ...
} on TimeoutException {
  throw Exception('Translation timed out. Please check your connection and try again.');
}
```

---

### Bug 6 — OCR Cache Evicts Wrong Entry (Non-Ordered Map)

**File:** `lib/services/ocr_service.dart`  
**Severity:** Medium

The result cache used a plain `Map<String, OCRResult>`. When the cache was full, the "oldest" entry was evicted using `.keys.first`. However, Dart's default `Map` does not guarantee insertion order, so `.keys.first` can return any key — not the oldest. This broke the intended FIFO eviction and could keep stale entries while evicting recent ones.

```dart
// BEFORE (plain Map — no ordering guarantee)
static final Map<String, OCRResult> _resultCache = {};
...
final firstKey = _resultCache.keys.first; // Not guaranteed to be oldest
_resultCache.remove(firstKey);
```

**Fix:** Changed to `LinkedHashMap`, which preserves insertion order and makes `.keys.first` reliably return the oldest entry.

```dart
// AFTER
import 'dart:collection';
...
static final Map<String, OCRResult> _resultCache = LinkedHashMap();
```

---

### Bug 7 — Empty `catch` Block Silently Swallows File-Delete Errors

**File:** `lib/services/ocr_service.dart`  
**Severity:** Medium

A bare `catch (e) {}` was used when deleting a preprocessed temp file. Any error during deletion was silently discarded with no log output, making it impossible to diagnose failures (e.g., permission errors, locked files on Windows).

```dart
// BEFORE (error silently swallowed)
try {
  await File(preprocessedPath).delete();
} catch (e) {}
```

**Fix:** Added a `debugPrint` so failures appear in the debug console.

```dart
// AFTER
try {
  await File(preprocessedPath).delete();
} catch (e) {
  debugPrint('OCR Debug: Failed to delete preprocessed file: $e');
}
```

---

### Bug 8 — Firebase Config Check Used Redundant Null-Aware Operators

**File:** `lib/main.dart`  
**Severity:** Low

The Firebase placeholder check used `(opts.apiKey ?? '')` and `(opts.appId ?? '')`, but both fields are non-nullable `String` properties. The `?? ''` branch is dead code and the Dart analyzer flags it as a warning.

```dart
// BEFORE (redundant null-aware, dead code warning)
if ((opts.apiKey ?? '').contains('CHANGE_ME') ||
    (opts.appId ?? '').contains('CHANGE_ME')) {
```

**Fix:** Removed the redundant null-aware operators.

```dart
// AFTER
if (opts.apiKey.contains('CHANGE_ME') ||
    opts.appId.contains('CHANGE_ME')) {
```

---

---

## Bug Fix — Round 3

### Bug — Audio Transcription Always Times Out

**Files:** `lib/services/transcription_service.dart`, `lib/screens/audio_trimming_page.dart`  
**Severity:** Critical  
**Error shown:** `Transcription failed: Exception: Transcription request timed out`

#### Root Cause

Three problems combined to produce this error:

1. **No backend availability check** — the app skipped straight to a multipart upload with no pre-flight check. If the backend server was unreachable (wrong IP, server not running, device on a different network), the user had no way to know — they just waited until the timeout fired.

2. **Timeout was 300 seconds (5 minutes)** — far too long for a short audio clip. A 3-second audio file should not require waiting 5 minutes before showing an error.

3. **Error message showed `"Exception:"` twice** — the `onTimeout` callback threw `Exception('Transcription request timed out')`. The outer catch block rethrew it as-is, and the UI wrapped it again with `'Transcription failed: ${e.toString()}'`, producing: `"Transcription failed: Exception: Transcription request timed out"`.

#### Fix 1 — Backend Health Check Before Starting the Request

**File:** `lib/screens/audio_trimming_page.dart`

Added a call to `TranscriptionService.checkServiceAvailability()` before showing the loading dialog. If the server does not respond to the health endpoint within 5 seconds, the user immediately sees a clear error instead of waiting for a long timeout.

```dart
// BEFORE (no check — user waits 300 s then sees a cryptic timeout)
setState(() => _isTranscribing = true);
showDialog(...); // loading spinner
final transcript = await TranscriptionService.transcribeAudio(...);
```

```dart
// AFTER (fast fail with actionable message)
setState(() => _isTranscribing = true);
final isAvailable = await TranscriptionService.checkServiceAvailability();
if (!isAvailable) {
  setState(() => _isTranscribing = false);
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(
      'Cannot reach the backend server. Make sure the server is running '
      'and your device is on the same network.',
    ),
    backgroundColor: Colors.red,
    duration: Duration(seconds: 6),
  ));
  return;
}
showDialog(...); // only shown when server is reachable
```

#### Fix 2 — Timeout Reduced from 300 s to 60 s

**File:** `lib/services/transcription_service.dart`

300 seconds (5 minutes) is unreasonable for audio clips of a few seconds. Reduced to 60 seconds — still generous for slow servers — so failures surface quickly.

```dart
// BEFORE
streamedResponse = await request.send().timeout(
  const Duration(seconds: 300),
  onTimeout: () { throw Exception('Transcription request timed out'); },
);

// AFTER
streamedResponse = await request.send().timeout(
  const Duration(seconds: 60),
  onTimeout: () {
    throw Exception(
      'Transcription request timed out after 60 seconds. '
      'Please check your backend connection and try again.',
    );
  },
);
```

#### Fix 3 — Duplicate `"Exception:"` Prefix Removed from Error Messages

**Files:** `lib/services/transcription_service.dart`, `lib/screens/audio_trimming_page.dart`

The catch block in the service and the SnackBar in the UI both prepended text to the exception message, resulting in double-prefixed strings like `"Transcription failed: Exception: ..."`. Fixed by stripping the `Exception:` prefix before displaying.

```dart
// BEFORE — catch block in transcription_service.dart
} catch (e) {
  if (e is Exception) rethrow;
  throw Exception('Transcription failed: ${e.toString()}');
}

// AFTER
} catch (e) {
  final msg = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
  throw Exception(msg);
}
```

```dart
// BEFORE — SnackBar in audio_trimming_page.dart
Text('Transcription failed: ${e.toString()}')

// AFTER
final msg = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
Text('Transcription failed: $msg')
```

#### Most Likely Runtime Cause

The physical Android device and the backend server (`192.168.100.12:5000`) must be on the **same Wi-Fi network** and the Flask server must be actively running. The new health check will surface this immediately with a readable message instead of a silent 5-minute wait.

---

## Running the App

```bash
# Install dependencies
flutter pub get

# Run with required environment variables
flutter run \
  --dart-define=BACKEND_URL=http://192.168.100.12:5000/api \
  --dart-define=GOOGLE_TRANSLATE_API_KEY=your_key_here

# Build APK
flutter build apk \
  --dart-define=BACKEND_URL=https://your-production-server/api \
  --dart-define=GOOGLE_TRANSLATE_API_KEY=your_key_here
```

## Architecture Notes

- **Backend:** Flask REST API + PostgreSQL + FAISS vector search
- **Auth:** Firebase Authentication + backend integer user ID (dual registration)
- **State:** `StatefulWidget` + `setState`; `ThemeNotifier` for theme toggling
- **Services:** All HTTP calls via `ApiService`; no repository abstraction layer
- **Theme:** Use `AppColors` and `AppTextStyles` — never hardcode color or font values
