import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/theme/app_colors.dart';
import '../widgets/custom_button.dart';

class VoiceInputPage extends StatefulWidget {
  const VoiceInputPage({super.key});

  @override
  State<VoiceInputPage> createState() => _VoiceInputPageState();
}

class _VoiceInputPageState extends State<VoiceInputPage>
    with SingleTickerProviderStateMixin {
  final SpeechToText _speech = SpeechToText();

  bool _isListening = false;
  bool _speechAvailable = false;
  bool _isInitializing = false;
  String _recognizedText = '';
  String _statusMessage = 'Tap mic to start';
  String? _errorMessage;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Supported locales in order of preference
  static const _preferredLocales = ['ur-PK', 'ar-SA', 'en-US'];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.18).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.stop();

    _initSpeech();
  }

  Future<void> _initSpeech() async {
    setState(() => _isInitializing = true);

    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      setState(() {
        _errorMessage = 'Microphone permission denied.';
        _statusMessage = 'Permission required';
        _isInitializing = false;
      });
      return;
    }

    final available = await _speech.initialize(
      onError: (error) {
        setState(() {
          _isListening = false;
          _pulseController.stop();
          _statusMessage = 'Tap mic to start';
          _errorMessage = 'Error: ${error.errorMsg}';
        });
      },
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          setState(() {
            _isListening = false;
            _pulseController.stop();
            _statusMessage = 'Tap mic to start';
          });
        }
      },
    );

    setState(() {
      _speechAvailable = available;
      _isInitializing = false;
      if (!available) {
        _errorMessage = 'Speech recognition not available on this device.';
        _statusMessage = 'Not available';
      }
    });
  }

  Future<void> _toggleListening() async {
    if (_isInitializing) return;

    if (_isListening) {
      await _speech.stop();
      setState(() {
        _isListening = false;
        _pulseController.stop();
        _statusMessage = 'Tap mic to start';
      });
      return;
    }

    if (!_speechAvailable) {
      await _initSpeech();
      if (!_speechAvailable) return;
    }

    setState(() {
      _errorMessage = null;
      _recognizedText = '';
      _isListening = true;
      _statusMessage = 'Listening…';
      _pulseController.repeat(reverse: true);
    });

    // Pick the best available locale
    final locales = await _speech.locales();
    final localeIds = locales.map((l) => l.localeId).toList();
    String? selectedLocale;
    for (final pref in _preferredLocales) {
      if (localeIds.contains(pref)) {
        selectedLocale = pref;
        break;
      }
    }

    await _speech.listen(
      onResult: _onSpeechResult,
      localeId: selectedLocale,
      listenMode: ListenMode.dictation,
      pauseFor: const Duration(seconds: 3),
      listenFor: const Duration(seconds: 60),
      partialResults: true,
      cancelOnError: false,
    );
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    setState(() {
      _recognizedText = result.recognizedWords;
      if (result.finalResult) {
        _isListening = false;
        _pulseController.stop();
        _statusMessage = 'Tap mic to start';
      }
    });
  }

  void _clearText() {
    setState(() => _recognizedText = '');
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: ThemeColors.background(isDark),
      appBar: AppBar(
        backgroundColor: ThemeColors.background(isDark),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          color: ThemeColors.textPrimary(isDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Voice Search',
          style: TextStyle(
            color: ThemeColors.textPrimary(isDark),
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 24),
              Text(
                'Tap the mic and speak your query.\nArabic, Urdu, Roman Urdu and English are supported.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: ThemeColors.textSecondary(isDark),
                ),
              ),
              const SizedBox(height: 40),
              _buildMicButton(),
              const SizedBox(height: 20),
              Text(
                _statusMessage,
                style: TextStyle(
                  fontSize: 14,
                  color: _isListening
                      ? AppColors.primary
                      : ThemeColors.textSecondary(isDark),
                  fontWeight:
                      _isListening ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.red,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Expanded(
                child: Stack(
                  children: [
                    SingleChildScrollView(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: ThemeColors.card(isDark),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _isListening
                                ? AppColors.primary.withOpacity(0.5)
                                : ThemeColors.border(isDark),
                          ),
                        ),
                        child: Text(
                          _recognizedText.isEmpty
                              ? 'Recognized text will appear here.'
                              : _recognizedText,
                          style: TextStyle(
                            fontSize: 16,
                            color: _recognizedText.isEmpty
                                ? ThemeColors.textSecondary(isDark)
                                : ThemeColors.textPrimary(isDark),
                          ),
                        ),
                      ),
                    ),
                    if (_recognizedText.isNotEmpty)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: _clearText,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: ThemeColors.card(isDark),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.close,
                              size: 16,
                              color: ThemeColors.textSecondary(isDark),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              CustomButton(
                text: 'Use this text',
                onPressed: _recognizedText.trim().isEmpty
                    ? null
                    : () => Navigator.pop(context, _recognizedText.trim()),
                width: double.infinity,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMicButton() {
    if (_isInitializing) {
      return SizedBox(
        width: 90,
        height: 90,
        child: Center(
          child: CircularProgressIndicator(
            color: AppColors.primary,
            strokeWidth: 3,
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: _toggleListening,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _isListening ? _pulseAnimation.value : 1.0,
            child: child,
          );
        },
        child: Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _isListening
                ? AppColors.primary
                : AppColors.primary.withOpacity(0.1),
            boxShadow: _isListening
                ? [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.4),
                      blurRadius: 20,
                      spreadRadius: 4,
                    )
                  ]
                : null,
          ),
          child: Icon(
            _isListening ? Icons.mic : Icons.mic_none,
            size: 40,
            color: _isListening ? Colors.white : AppColors.primary,
          ),
        ),
      ),
    );
  }
}
