import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../widgets/custom_button.dart';

class VoiceInputPage extends StatefulWidget {
  const VoiceInputPage({super.key});

  @override
  State<VoiceInputPage> createState() => _VoiceInputPageState();
}

class _VoiceInputPageState extends State<VoiceInputPage> {
  bool _isListening = false;
  final String _recognizedText = '';

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
                'Tap the mic and speak your query.\nOnly Arabic, Urdu, Roman Urdu and English are allowed.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: ThemeColors.textSecondary(isDark),
                ),
              ),
              const SizedBox(height: 40),
              GestureDetector(
                onTap: _toggleListening,
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isListening
                        ? AppColors.primary
                        : AppColors.primary.withOpacity(0.1),
                  ),
                  child: Icon(
                    Icons.mic,
                    size: 40,
                    color: _isListening ? Colors.white : AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _isListening ? 'Listening…' : 'Tap mic to start',
                style: TextStyle(
                  fontSize: 14,
                  color: ThemeColors.textSecondary(isDark),
                ),
              ),
              const SizedBox(height: 32),
              Expanded(
                child: SingleChildScrollView(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: ThemeColors.card(isDark),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: ThemeColors.border(isDark)),
                    ),
                    child: Text(
                      _recognizedText.isEmpty
                          ? 'Recognized text will appear here.'
                          : _recognizedText,
                      style: TextStyle(
                        fontSize: 16,
                        color: ThemeColors.textPrimary(isDark),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              CustomButton(
                text: 'Use this text',
                onPressed: () {
                  Navigator.pop(context, _recognizedText.trim());
                },
                width: double.infinity,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleListening() {
    setState(() {
      _isListening = !_isListening;
      // TODO: integrate with speech-to-text and update _recognizedText.
    });
  }
}
