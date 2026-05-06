import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

enum TranslationLanguage {
  none,
  bengali,
  hindi,
  persian,
  indonesian,
  russian,
}

extension TranslationLanguageExt on TranslationLanguage {
  String get displayName {
    switch (this) {
      case TranslationLanguage.none:
        return 'None';
      case TranslationLanguage.bengali:
        return 'Bengali';
      case TranslationLanguage.hindi:
        return 'Hindi';
      case TranslationLanguage.persian:
        return 'Persian (Farsi)';
      case TranslationLanguage.indonesian:
        return 'Indonesian';
      case TranslationLanguage.russian:
        return 'Russian';
    }
  }

  String get code {
    switch (this) {
      case TranslationLanguage.none:
        return '';
      case TranslationLanguage.bengali:
        return 'bn';
      case TranslationLanguage.hindi:
        return 'hi';
      case TranslationLanguage.persian:
        return 'fa';
      case TranslationLanguage.indonesian:
        return 'id';
      case TranslationLanguage.russian:
        return 'ru';
    }
  }
}

class TranslationService extends ChangeNotifier {
  static final TranslationService _instance = TranslationService._internal();
  static TranslationService get instance => _instance;
  TranslationService._internal();

  static const _prefKey = 'translation_language';
  TranslationLanguage _selectedLanguage = TranslationLanguage.none;

  TranslationLanguage get selectedLanguage => _selectedLanguage;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey);
    if (saved != null) {
      _selectedLanguage = TranslationLanguage.values.firstWhere(
        (e) => e.name == saved,
        orElse: () => TranslationLanguage.none,
      );
    }
  }

  Future<void> setLanguage(TranslationLanguage lang) async {
    _selectedLanguage = lang;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, lang.name);
    notifyListeners();
  }

  // Uses MyMemory API (free, no API key required).
  Future<String> translate(String text) async {
    final code = _selectedLanguage.code;
    if (code.isEmpty || text.trim().isEmpty) return text;

    final uri = Uri.parse(
      'https://api.mymemory.translated.net/get'
      '?q=${Uri.encodeComponent(text)}&langpair=en|$code',
    );

    final response = await http
        .get(uri)
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('Translation failed: HTTP ${response.statusCode}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final status = body['responseStatus'];
    if (status != 200) {
      final details = body['responseDetails'] ?? 'Unknown error';
      throw Exception('Translation failed: $details');
    }

    final translated = body['responseData']?['translatedText'] as String?;
    if (translated == null || translated.isEmpty) {
      throw Exception('Translation failed: empty response');
    }
    return translated;
  }
}
