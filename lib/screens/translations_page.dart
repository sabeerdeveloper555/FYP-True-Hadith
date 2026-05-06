import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../services/translation_service.dart';

class TranslationsPage extends StatefulWidget {
  const TranslationsPage({super.key});

  @override
  State<TranslationsPage> createState() => _TranslationsPageState();
}

class _TranslationsPageState extends State<TranslationsPage> {
  TranslationLanguage _selected = TranslationService.instance.selectedLanguage;

  static const List<TranslationLanguage> _languages = [
    TranslationLanguage.none,
    TranslationLanguage.bengali,
    TranslationLanguage.hindi,
    TranslationLanguage.persian,
    TranslationLanguage.indonesian,
    TranslationLanguage.russian,
  ];

  Future<void> _select(TranslationLanguage lang) async {
    setState(() => _selected = lang);
    await TranslationService.instance.setLanguage(lang);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          color: colorScheme.onSurface,
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Translations Languages',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Text(
                'Arabic, English and Urdu are selected by default.',
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: _languages.length,
                separatorBuilder: (_, __) => Divider(
                  color: colorScheme.outline.withOpacity(0.3),
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                ),
                itemBuilder: (context, index) {
                  final lang = _languages[index];
                  final isSelected = _selected == lang;
                  return InkWell(
                    onTap: () => _select(lang),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      child: Row(
                        children: [
                          Checkbox(
                            value: isSelected,
                            onChanged: (_) => _select(lang),
                            activeColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            lang.displayName,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: isSelected
                                  ? AppColors.primary
                                  : colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
