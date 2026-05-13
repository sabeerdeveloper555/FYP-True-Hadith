import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
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
import 'screens/splash_screen.dart';
import 'services/auth_service.dart';
import 'services/onboarding_service.dart';
import 'models/user_model.dart';
import 'models/hadith_models.dart';
import 'utils/theme_notifier.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_theme_dark.dart';
import 'screens/reset_password_screen.dart';
import 'screens/translations_page.dart';
import 'services/translation_service.dart';

Future<void> main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

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
      if (opts.apiKey.contains('CHANGE_ME') ||
          opts.appId.contains('CHANGE_ME')) {
        FlutterNativeSplash.remove();
        runApp(const ErrorApp(
          message:
              'Firebase is not configured. Update lib/firebase_options.dart or run `flutterfire configure`.',
        ));
        return;
      }

      await Firebase.initializeApp(options: opts);
      debugPrint('✓ Firebase initialized');
    } else {
      debugPrint('✓ Firebase already initialized');
    }

    // Register FCM background handler before runApp so FCM can deliver
    // notifications even when the app is terminated.
    // Remove native splash and show Flutter immediately.
    // TranslationService init runs in the background — the SplashScreen
    // animation (~4 s) gives it ample time to finish.
    FlutterNativeSplash.remove();
    runApp(const MyApp());
    TranslationService.instance.init().catchError(
      (Object e) => debugPrint('Translation init error: $e'),
    );
  } catch (e, st) {
    debugPrint('Firebase initialization failed: $e\n$st');
    FlutterNativeSplash.remove();
    runApp(ErrorApp(message: 'Failed to initialize Firebase: $e'));
  }
}

// ── MyApp ────────────────────────────────────────────────────────────────────

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

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
          navigatorKey: MyApp.navigatorKey,

          // ── Theme mode driven by ThemeNotifier ──────────────────────────
          themeMode: ThemeNotifier.instance.themeMode,

          // ── Centralized themes ──────────────────────────────────────────
          theme: AppTheme.light,
          darkTheme: AppThemeDark.dark,

          // ── Initial screen & named routes ───────────────────────────────
          home: const SplashScreen(nextScreen: AuthWrapper()),
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
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();

    // Check onboarding status first
    _checkOnboardingStatus();

    // Listen to Firebase auth state
    _authSubscription = AuthService.authStateChanges.listen((user) {
      if (user != null) {
        _loadUserData();
      } else {
        if (mounted) {
          setState(() {
            _userData = null;
            _isLoading = false;
          });
        }
      }
    });

    _initDeepLinks();
  }

  Future<void> _initDeepLinks() async {
    final appLinks = AppLinks();

    // Handle deep link that launched the app from a cold start.
    final initialLink = await appLinks.getInitialLink();
    if (initialLink != null) {
      _handleDeepLink(initialLink);
    }

    // Handle deep links while the app is already running.
    _linkSubscription = appLinks.uriLinkStream.listen(_handleDeepLink);
  }

  void _handleDeepLink(Uri uri) {
    debugPrint('🔗 Deep link received: $uri');

    String? oobCode;

    if (uri.scheme == 'truehadith' && uri.host == 'reset-password') {
      // Custom scheme: truehadith://reset-password?oobCode=...
      oobCode = uri.queryParameters['oobCode'];
    } else if (uri.scheme == 'https' &&
        uri.path.contains('/__/auth/action') &&
        uri.queryParameters['mode'] == 'resetPassword') {
      // Firebase HTTPS action link intercepted via App Links
      oobCode = uri.queryParameters['oobCode'];
    }

    if (oobCode != null && oobCode.isNotEmpty) {
      debugPrint('✅ Password reset action code detected: $oobCode');
      final code = oobCode;
      MyApp.navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => ResetPasswordScreen(actionCode: code),
        ),
      );
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _linkSubscription?.cancel();
    super.dispose();
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
