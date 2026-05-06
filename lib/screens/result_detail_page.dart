import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import 'package:intl/intl.dart';

import '../models/hadith_models.dart';
import '../core/theme/app_colors.dart';
import '../services/api_service.dart';
import '../services/translation_service.dart';

class ResultDetailPage extends StatefulWidget {
  final int userId;
  final int hadithId;

  const ResultDetailPage({
    super.key,
    required this.userId,
    required this.hadithId,
  });

  @override
  State<ResultDetailPage> createState() => _ResultDetailPageState();
}

class _ResultDetailPageState extends State<ResultDetailPage> {
  HadithDetail? _detail;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isBookmarked = false;
  int? _bookmarkId;

  // Translation state
  String? _translatedText;
  bool _isTranslating = false;
  bool _showTranslation = false;

  @override
  void initState() {
    super.initState();
    _loadHadithDetail();
  }

  Future<void> _loadHadithDetail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await ApiService.getHadithDetailWithBookmark(
        hadithId: widget.hadithId,
        userId: widget.userId,
      );

      setState(() {
        _detail = result['detail'] as HadithDetail;
        _isBookmarked = result['bookmarked'] as bool;
        _bookmarkId = result['bookmarkId'] as int?;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
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
        actions: [
          if (!_isLoading && _detail != null) ...[
            IconButton(
              icon: const Icon(Icons.copy_rounded),
              color: colorScheme.onSurfaceVariant,
              tooltip: 'Copy',
              onPressed: _copyToClipboard,
            ),
            IconButton(
              icon: const Icon(Icons.share_rounded),
              color: colorScheme.onSurfaceVariant,
              tooltip: 'Share',
              onPressed: _shareHadith,
            ),
            IconButton(
              icon: Icon(
                _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                color: _isBookmarked
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
              onPressed: _toggleBookmark,
            ),
          ],
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
            : _errorMessage != null
                ? _buildErrorState()
                : _detail != null
                    ? _buildDetailContent()
                    : Center(
                        child: Text(
                          'No data available',
                          style: TextStyle(color: colorScheme.onSurface),
                        ),
                      ),
      ),
    );
  }

  Widget _buildErrorState() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load hadith',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadHadithDetail,
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailContent() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final d = _detail!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${d.bookName} : ${d.hadithNumber}',
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Chapter #${d.chapterNumber} • ${d.chapterName}',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.getHadithColor(d.grade).withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: AppColors.getHadithColor(d.grade).withOpacity(0.3),
              ),
            ),
            child: Text(
              d.grade,
              style: textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.getHadithColor(d.grade),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Narrator: ${d.narrator}',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('Arabic'),
          const SizedBox(height: 8),
          Text(
            d.arabicText,
            textAlign: TextAlign.right,
            style: textTheme.titleMedium?.copyWith(
              height: 1.8,
              fontFamily: 'Amiri',
              fontSize: 17,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('English'),
          const SizedBox(height: 8),
          Text(
            _showTranslation && _translatedText != null
                ? _translatedText!
                : d.englishText,
            style: textTheme.bodyLarge?.copyWith(
              height: 1.6,
              color: colorScheme.onSurface.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 6),
          _buildTranslationToggle(d.englishText, colorScheme),
          const SizedBox(height: 24),
          _buildSectionTitle('Urdu'),
          const SizedBox(height: 8),
          Text(
            d.urduText,
            textAlign: TextAlign.right,
            style: textTheme.bodyLarge?.copyWith(
              height: 1.8,
              color: colorScheme.onSurface.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 32),
          if (d.bookmarkedAt != null)
            Text(
              'Bookmarked on ${DateFormat('d MMMM, h:mm a').format(d.bookmarkedAt!)}',
              style: textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant.withOpacity(0.5),
              ),
            ),
        ],
      ),
    );
  }

  String _getShareableText() {
    final d = _detail!;
    return '${d.bookName} : ${d.hadithNumber}\n'
        'Chapter #${d.chapterNumber} • ${d.chapterName}\n'
        'Grade: ${d.grade}\n'
        'Narrator: ${d.narrator}\n\n'
        'Arabic:\n${d.arabicText}\n\n'
        'English:\n${d.englishText}\n\n'
        'Urdu:\n${d.urduText}';
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: _getShareableText()));
    if (mounted) {
      final colorScheme = Theme.of(context).colorScheme;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Hadith copied to clipboard'),
          backgroundColor: colorScheme.primary,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _shareHadith() {
    Share.share(_getShareableText());
  }

  Widget _buildTranslationToggle(String originalText, ColorScheme colorScheme) {
    final lang = TranslationService.instance.selectedLanguage;
    if (lang == TranslationLanguage.none) return const SizedBox.shrink();

    if (_isTranslating) {
      return Row(
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Translating...',
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      );
    }

    if (_showTranslation && _translatedText != null) {
      return GestureDetector(
        onTap: () => setState(() => _showTranslation = false),
        child: Text(
          'Show original English',
          style: TextStyle(
            fontSize: 12,
            color: colorScheme.primary,
            decoration: TextDecoration.underline,
            decorationColor: colorScheme.primary,
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () async {
        if (_translatedText != null) {
          setState(() => _showTranslation = true);
          return;
        }
        setState(() => _isTranslating = true);
        try {
          final result = await TranslationService.instance.translate(originalText);
          setState(() {
            _translatedText = result;
            _showTranslation = true;
            _isTranslating = false;
          });
        } catch (e) {
          setState(() => _isTranslating = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Translation failed: ${e.toString()}'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 6),
              ),
            );
          }
        }
      },
      child: Text(
        'Translate in ${lang.displayName}',
        style: TextStyle(
          fontSize: 12,
          color: colorScheme.primary,
          decoration: TextDecoration.underline,
          decorationColor: colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: colorScheme.secondary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
            color: colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Future<void> _toggleBookmark() async {
    final wasBookmarked = _isBookmarked;

    // Optimistically update UI
    setState(() {
      _isBookmarked = !_isBookmarked;
    });

    try {
      if (wasBookmarked) {
        // Delete bookmark
        if (_bookmarkId != null) {
          await ApiService.deleteBookmark(bookmarkId: _bookmarkId!);

          // Update the detail to reflect bookmark removal
          final updatedDetail = HadithDetail(
            hadithId: _detail!.hadithId,
            bookName: _detail!.bookName,
            hadithNumber: _detail!.hadithNumber,
            chapterNumber: _detail!.chapterNumber,
            chapterName: _detail!.chapterName,
            grade: _detail!.grade,
            narrator: _detail!.narrator,
            arabicText: _detail!.arabicText,
            englishText: _detail!.englishText,
            urduText: _detail!.urduText,
            bookmarkedAt: null,
          );

          setState(() {
            _bookmarkId = null;
            _detail = updatedDetail;
          });
        } else {
          // If we don't have bookmarkId, reload to get it
          await _loadHadithDetail();
          // Try to delete again if still bookmarked
          if (_isBookmarked && _bookmarkId != null) {
            await ApiService.deleteBookmark(bookmarkId: _bookmarkId!);

            final updatedDetail = HadithDetail(
              hadithId: _detail!.hadithId,
              bookName: _detail!.bookName,
              hadithNumber: _detail!.hadithNumber,
              chapterNumber: _detail!.chapterNumber,
              chapterName: _detail!.chapterName,
              grade: _detail!.grade,
              narrator: _detail!.narrator,
              arabicText: _detail!.arabicText,
              englishText: _detail!.englishText,
              urduText: _detail!.urduText,
              bookmarkedAt: null,
            );

            setState(() {
              _isBookmarked = false;
              _bookmarkId = null;
              _detail = updatedDetail;
            });
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bookmark removed'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        // Create bookmark
        final bookmarkId = await ApiService.createBookmark(
          userId: widget.userId,
          hadithId: widget.hadithId,
        );

        // Update the detail to reflect bookmark status
        final updatedDetail = HadithDetail(
          hadithId: _detail!.hadithId,
          bookName: _detail!.bookName,
          hadithNumber: _detail!.hadithNumber,
          chapterNumber: _detail!.chapterNumber,
          chapterName: _detail!.chapterName,
          grade: _detail!.grade,
          narrator: _detail!.narrator,
          arabicText: _detail!.arabicText,
          englishText: _detail!.englishText,
          urduText: _detail!.urduText,
          bookmarkedAt: DateTime.now(),
        );

        setState(() {
          _bookmarkId = bookmarkId;
          _isBookmarked = true;
          _detail = updatedDetail;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bookmarked successfully'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      // Revert optimistic update on error
      setState(() {
        _isBookmarked = wasBookmarked;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Failed to ${wasBookmarked ? 'remove' : 'add'} bookmark: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
}
