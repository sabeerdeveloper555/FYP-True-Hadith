import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:app_links/app_links.dart';

import 'firebase_options.dart'; // Firebase configuration
import 'screens/onboarding_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/history_page.dart';
import 'screens/bookmark_page.dart';
import 'screens/history_detail_page.dart';
import 'screens/bookmark_detail_page.dart';
import 'screens/result_page.dart';
import 'screens/result_detail_page.dart';
import 'screens/crop_image_page.dart';
import 'screens/audio_trimming_page.dart';
import 'screens/voice_input_page.dart';
import 'screens/reset_password_screen.dart';
import 'services/auth_service.dart';
import 'services/onboarding_service.dart';
import 'models/user_model.dart';
import 'models/hadith_models.dart';
import 'utils/theme_notifier.dart';
import 'utils/url_handler.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_theme_dark.dart';
import 'screens/translations_page.dart';
import 'services/translation_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Catch uncaught Flutter errors
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('Flutter error: ${details.exceptionAsString()}');
  };

  // Firebase initialization with duplicate check
  try {
    if (Firebase.apps.isEmpty) {
      final opts = DefaultFirebaseOptions.currentPlatform;

      // Quick check for placeholder Firebase config
      if ((opts.apiKey ?? '').contains('CHANGE_ME') ||
          (opts.appId ?? '').contains('CHANGE_ME')) {
        runApp(const ErrorApp(
          message:
              'Firebase is not configured. Update lib/firebase_options.dart or run `flutterfire configure`.',
        ));
        return;
      }

      await Firebase.initializeApp(options: opts);
      await TranslationService.instance.init();
      debugPrint('✓ Firebase initialized');
    } else {
      debugPrint('✓ Firebase already initialized');
    }

    runApp(const MyApp());
  } catch (e, st) {
    debugPrint('Firebase initialization failed: $e\n$st');
    runApp(ErrorApp(message: 'Failed to initialize Firebase: $e'));
  }
}

// ── MyApp ────────────────────────────────────────────────────────────────────

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // ListenableBuilder rebuilds MaterialApp whenever the theme toggle is tapped,
    // so Flutter's own widgets (dialogs, snackbars, system UI) also switch.
    return ListenableBuilder(
      listenable: ThemeNotifier.instance,
      builder: (context, _) {
        return MaterialApp(
          title: 'True Hadith',
          debugShowCheckedModeBanner: false,

          // ── Theme mode driven by ThemeNotifier ──────────────────────────
          themeMode: ThemeNotifier.instance.themeMode,

          // ── Centralized themes ──────────────────────────────────────────
          theme: AppTheme.light,
          darkTheme: AppThemeDark.dark,

          // ── Initial screen & named routes ───────────────────────────────
          home: const AuthWrapper(),
          routes: {
            '/history': (context) {
              final args = ModalRoute.of(context)?.settings.arguments;
              if (args is int) {
                return HistoryPage(userId: args);
              }
              return const Scaffold(
                body: Center(child: Text('Error: Invalid user ID')),
              );
            },
            '/bookmarks': (context) {
              final args = ModalRoute.of(context)?.settings.arguments;
              if (args is int) {
                return BookmarkPage(userId: args);
              }
              return const Scaffold(
                body: Center(child: Text('Error: Invalid user ID')),
              );
            },
            '/history_detail': (context) {
              final args = ModalRoute.of(context)?.settings.arguments;
              if (args is HistoryEntry) {
                return HistoryDetailPage(entry: args);
              }
              return const Scaffold(
                body: Center(child: Text('Error: Invalid history entry')),
              );
            },
            '/bookmark_detail': (context) {
              final args = ModalRoute.of(context)?.settings.arguments;
              if (args is Map<String, dynamic> &&
                  args['userId'] is int &&
                  args['entry'] is BookmarkEntry) {
                return BookmarkDetailPage(
                  userId: args['userId'] as int,
                  entry: args['entry'] as BookmarkEntry,
                );
              }
              return const Scaffold(
                body: Center(child: Text('Error: Invalid bookmark entry')),
              );
            },
            '/results': (context) {
              final args = ModalRoute.of(context)?.settings.arguments;
              if (args is Map<String, dynamic>) {
                return ResultPage(
                  userId: args['userId'] as int,
                  query: args['query'] as String,
                  results: (args['results'] as List<HadithSummary>? ??
                      <HadithSummary>[]),
                );
              }
              return const Scaffold(
                body: Center(child: Text('Error: Invalid route arguments')),
              );
            },
            '/result_detail': (context) {
              final args = ModalRoute.of(context)?.settings.arguments;
              if (args is Map<String, dynamic>) {
                return ResultDetailPage(
                  userId: args['userId'] as int,
                  hadithId: args['hadithId'] as int,
                );
              }
              return const Scaffold(
                body: Center(child: Text('Error: Invalid route arguments')),
              );
            },
            '/translations': (context) => const TranslationsPage(),
            '/crop_image': (context) => const CropImagePage(),
            '/audio_trimming': (context) => const AudioTrimmingPage(),
            '/voice_input': (context) => const VoiceInputPage(),
            '/reset-password': (context) {
              final args = ModalRoute.of(context)?.settings.arguments;
              if (args is Map<String, dynamic>) {
                return ResetPasswordScreen(
                  actionCode: args['actionCode'] as String?,
                  email: args['email'] as String?,
                );
              }
              return const ResetPasswordScreen();
            },
          },
        );
      },
    );
  }
}

// ── ErrorApp ─────────────────────────────────────────────────────────────────

class ErrorApp extends StatelessWidget {
  final String message;
  const ErrorApp({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'True Hadith - Error',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(title: const Text('Startup Error')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 72, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () async {
                    await main();
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── AuthWrapper ───────────────────────────────────────────────────────────────

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  UserModel? _userData;
  bool _isLoading = true;
  bool _showOnboarding = false;
  late final Stream<User?> _authStateStream;
  final AppLinks _appLinks = AppLinks();

  @override
  void initState() {
    super.initState();

    // Check onboarding status first
    _checkOnboardingStatus();

    // Listen to Firebase auth state
    _authStateStream = AuthService.authStateChanges;

    _authStateStream.listen((user) {
      if (user != null) {
        _loadUserData();
      } else {
        setState(() {
          _userData = null;
          _isLoading = false;
        });
      }
    });

    // Listen for deep links (password reset)
    _initDeepLinkListener();
  }

  void _initDeepLinkListener() {
    // Handle initial link (if app was opened from a link)
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) {
        _handleDeepLink(uri.toString());
      }
    });

    // Listen for incoming links while app is running
    _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri.toString());
    }, onError: (err) {
      debugPrint('Deep link error: $err');
    });
  }

  void _handleDeepLink(String link) {
    debugPrint('🔗 Deep link received: $link');

    // Check if it's a password reset link
    if (UrlHandler.isPasswordResetUrl(link)) {
      final actionCode = UrlHandler.extractActionCodeFromUrl(link);
      final email = UrlHandler.extractEmailFromUrl(link);

      if (actionCode != null) {
        debugPrint('✅ Password reset action code detected: $actionCode');

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => ResetPasswordScreen(
                  actionCode: actionCode,
                  email: email,
                ),
              ),
            );
          }
        });
      } else {
        debugPrint('⚠️ No action code found in deep link');
      }
    }
  }

  Future<void> _checkOnboardingStatus() async {
    final onboardingCompleted = await OnboardingService.isOnboardingCompleted();

    if (!onboardingCompleted) {
      setState(() {
        _showOnboarding = true;
        _isLoading = false;
      });
    } else {
      await _checkAuthState();
    }
  }

  Future<void> _checkAuthState() async {
    if (AuthService.isSignedIn()) {
      await _loadUserData();
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onOnboardingCompleted() {
    setState(() {
      _showOnboarding = false;
      _isLoading = true;
    });
    _checkAuthState();
  }

  Future<void> _loadUserData() async {
    try {
      final userData = await AuthService.getCurrentUserData();
      if (mounted) {
        setState(() {
          _userData = userData;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _userData = null;
          _isLoading = false;
        });
      }
    }
  }

  void _onUserDataUpdated(UserModel updatedUser) {
    if (mounted) {
      setState(() {
        _userData = updatedUser;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show onboarding if not completed
    if (_showOnboarding) {
      return OnboardingScreen(onComplete: _onOnboardingCompleted);
    }

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_userData != null) {
      return HomeScreen(
        key: ValueKey(_userData!.userId),
        userId: _userData!.userId,
        username: _userData!.username,
        createdAt: _userData!.createdAt,
        profilePhotoUrl: _userData!.profilePhotoUrl,
        onProfilePhotoUpdated: _onUserDataUpdated,
      );
    }

    return const LoginScreen();
  }
}
