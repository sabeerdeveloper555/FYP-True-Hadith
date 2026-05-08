# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

True Hadith is a Flutter app for AI-powered hadith verification. It supports text search, OCR, voice input, audio transcription, a chatbot, bookmarks, and history — with Arabic, English, and Urdu support.

## Common Commands

```bash
# Run the app
flutter run

# Run on a specific device
flutter run -d chrome          # Web
flutter run -d <device-id>     # Use `flutter devices` to list

# Build
flutter build apk              # Android APK
flutter build web              # Web

# Analyze & lint
flutter analyze

# Run tests
flutter test
flutter test test/widget_test.dart   # Single test file

# Clean and reinstall
flutter clean && flutter pub get
```

## Architecture

### Backend Integration
The app talks to a **Flask REST API** backed by **PostgreSQL** and **FAISS** (vector search). The base URL is set in `lib/services/api_service.dart`:
- Local device: `http://192.168.100.12:5000/api`
- Android emulator: use `http://10.0.2.2:5000/api`
- iOS simulator: use `http://127.0.0.1:5000/api`

### Auth Flow
`AuthWrapper` in `main.dart` is the top-level routing logic:
1. Shows `SplashScreen` while Firebase initializes
2. Checks `OnboardingService` — shows `OnboardingScreen` on first launch
3. Listens to `FirebaseAuth.authStateChanges` — routes to `LoginScreen` or `HomeScreen`
4. Handles deep links (password reset) via `app_links`

`AuthService` (`lib/services/auth_service.dart`) is a static utility wrapping Firebase Auth. On sign-up/sign-in, it also registers/fetches the user in the PostgreSQL backend via `ApiService`. This dual-registration pattern is important — Firebase UID is the primary auth token, but the app's backend assigns its own integer `userId`.

### State Management
No Provider/Riverpod. The app uses:
- `StatefulWidget` + `setState` for local screen state
- `StreamBuilder` on `FirebaseAuth.authStateChanges` in `AuthWrapper`
- `ThemeNotifier` (`lib/utils/theme_notifier.dart`) — singleton `ChangeNotifier` with `ListenableBuilder` in `main.dart` to toggle light/dark theme

### Navigation
Named routes defined in `MaterialApp.routes` in `main.dart`. Routes pass data via `RouteSettings.arguments` as maps. Key route-argument shapes:
- `/results`: `{userId, query, results: List<HadithSummary>}`
- `/result_detail`: `{userId, hadith: HadithDetail}`
- `/history_detail`: `{entry: HistoryEntry}`
- `/bookmark_detail`: `{entry: BookmarkEntry}`

### Service Layer (`lib/services/`)
Each service is a class with static methods or an instance. Screen widgets call services directly — there is no repository abstraction layer.

| Service | Responsibility |
|---|---|
| `ApiService` | All HTTP calls to Flask backend |
| `AuthService` | Firebase Auth + backend user sync |
| `StorageService` | Firebase Storage for profile photos |
| `OcrService` | Tesseract OCR on image files |
| `TranscriptionService` | Audio-to-text transcription |
| `AudioTrimmingService` | Trimming audio clips |
| `TranslationService` | Google Cloud Translation API |
| `LanguageDetector` | Detect Arabic/Urdu/English input |
| `OnboardingService` | SharedPreferences flag for first launch |

### Theming
- `AppColors` (`lib/core/theme/app_colors.dart`) — all color constants
- `AppTextStyles` (`lib/core/theme/app_text_styles.dart`) — all text styles using Google Fonts
- `AppTheme` / `AppThemeDark` — light and dark `ThemeData`
- Always use `AppColors` and `AppTextStyles` instead of hardcoded values

### Models (`lib/models/`)
- `UserModel` — app user from backend (has integer `userId`, separate from Firebase UID)
- `HadithSummary` — lightweight hadith for list views
- `HadithDetail` — full hadith with Arabic/English/Urdu text
- `BookmarkEntry` / `HistoryEntry` — wraps summary with metadata

### Google Translation API Key
Located in `lib/core/config.dart`. Used by `TranslationService` for on-device translation features.

## Platform Notes

- **Android:** `android/app/build.gradle.kts` uses Java 17 / Kotlin JVM 17. Firebase Google Services plugin is applied. Currently uses debug signing for release builds (needs proper keystore for production).
- **Web:** Standard Flutter web bootstrap. Title is `true_hadith`.
- **Tesseract OCR** (`tesseract_ocr` package) requires native library setup per platform — check package docs if OCR fails on a new platform.
