import 'package:flutter/material.dart';
import '../models/hadith_models.dart';
import '../widgets/hadith_card.dart';
import '../core/theme/app_colors.dart';

class ResultPage extends StatefulWidget {
  final int userId;
  final String query;
  final List<HadithSummary> results;

  const ResultPage({
    super.key,
    required this.userId,
    required this.query,
    required this.results,
  });

  @override
  State<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  String _selectedTag = 'All';

  static const List<String> _filterTags = [
    'All',
    'Sahih Bukhari',
    'Sahih Muslim',
    'Jami-at-Tirmizi',
  ];

  static const Map<String, List<String>> _tagKeywords = {
    'Sahih Bukhari': ['bukhari'],
    'Sahih Muslim': ['muslim'],
    // DB stores "Jami' at-Tirmidhi" — match both spellings
    'Jami-at-Tirmizi': ['tirmidhi', 'tirmizi'],
  };

  List<HadithSummary> get _filteredResults {
    if (_selectedTag == 'All') return widget.results;
    final keywords = _tagKeywords[_selectedTag] ?? [];
    if (keywords.isEmpty) return widget.results;
    return widget.results
        .where((r) => keywords.any((kw) => r.bookName.toLowerCase().contains(kw)))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = _filteredResults;
    
    return Scaffold(
      backgroundColor: ThemeColors.background(isDark),
      appBar: AppBar(
        backgroundColor: ThemeColors.background(isDark),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          color: ThemeColors.textPrimary(isDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Results',
          style: TextStyle(
            color: ThemeColors.textPrimary(isDark),
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildFilterTags(),
            Expanded(
              child: filtered.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        return HadithCard(
                          summary: item,
                          userId: widget.userId,
                          onTap: () {
                            Navigator.pushNamed(
                              context,
                              '/result_detail',
                              arguments: {
                                'userId': widget.userId,
                                'hadithId': item.hadithId,
                              },
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterTags() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _filterTags.map((tag) {
            final isSelected = _selectedTag == tag;
            return Padding(
              padding: const EdgeInsets.only(right: 10),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedTag = tag;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : ThemeColors.card(isDark),
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : ThemeColors.border(isDark),
                      width: 1.5,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : [],
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected ? Colors.white : ThemeColors.textSecondary(isDark),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 64,
              color: ThemeColors.textLight(isDark),
            ),
            const SizedBox(height: 16),
            Text(
              'No results found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: ThemeColors.textPrimary(isDark),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try refining your query or checking the spelling.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: ThemeColors.textSecondary(isDark),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

