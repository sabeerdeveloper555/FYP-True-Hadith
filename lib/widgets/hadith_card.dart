import 'package:flutter/material.dart';
import '../models/hadith_models.dart';
import '../core/theme/app_colors.dart';
import '../services/api_service.dart';

class HadithCard extends StatefulWidget {
  final HadithDetail? detail;
  final HadithSummary summary;
  final VoidCallback onTap;
  final VoidCallback? onBookmarkToggle;
  final bool isBookmarked;
  final int? userId;

  const HadithCard({
    super.key,
    required this.summary,
    required this.onTap,
    this.detail,
    this.onBookmarkToggle,
    this.isBookmarked = false,
    this.userId,
  });

  @override
  State<HadithCard> createState() => _HadithCardState();
}

class _HadithCardState extends State<HadithCard> {
  bool _isExpanded = false;
  bool _isFetching = false;
  String? _englishText;

  Future<void> _toggleExpand() async {
    if (_isExpanded) {
      setState(() => _isExpanded = false);
      return;
    }

    setState(() => _isExpanded = true);

    if (_englishText == null && widget.userId != null) {
      setState(() => _isFetching = true);
      try {
        final result = await ApiService.getHadithDetailWithBookmark(
          hadithId: widget.summary.hadithId,
          userId: widget.userId!,
        );
        final detail = result['detail'] as HadithDetail;
        if (mounted) {
          setState(() {
            _englishText = detail.englishText;
            _isFetching = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _isFetching = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final showAccordion = widget.userId != null && widget.detail == null;

    final displayGrade = widget.summary.grade
        .replaceAll(RegExp(r'\(?\bDarussalam\b\)?', caseSensitive: false), '')
        .replaceFirst(RegExp(r'\s*\bby\b.*', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${widget.summary.bookName} : ${widget.summary.hadithNumber}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: ThemeColors.textPrimary(isDark),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Chapter #${widget.summary.chapterNumber}',
                    style: TextStyle(
                      fontSize: 14,
                      color: ThemeColors.textSecondary(isDark),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.summary.similarityScore != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${(widget.summary.similarityScore! * 100).toStringAsFixed(0)}% match',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        displayGrade,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.getHadithColor(widget.summary.grade),
                        ),
                      ),
                      if (showAccordion) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _toggleExpand,
                          behavior: HitTestBehavior.opaque,
                          child: AnimatedRotation(
                            turns: _isExpanded ? 0.5 : 0,
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 20,
                              color: ThemeColors.textSecondary(isDark),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              if (_isExpanded) ...[
                const SizedBox(height: 10),
                Divider(height: 1, color: ThemeColors.border(isDark)),
                const SizedBox(height: 10),
                if (_isFetching)
                  const Center(
                    child: SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 1.5),
                    ),
                  )
                else if (_englishText != null)
                  Text(
                    _englishText!,
                    style: TextStyle(
                      fontSize: 13,
                      color: ThemeColors.textSecondary(isDark),
                      height: 1.6,
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
