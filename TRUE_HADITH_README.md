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
