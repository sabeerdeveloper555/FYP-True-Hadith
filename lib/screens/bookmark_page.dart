import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/hadith_models.dart';
import '../core/theme/app_colors.dart';
import '../services/api_service.dart';

class BookmarkPage extends StatefulWidget {
  final int userId;

  const BookmarkPage({
    super.key,
    required this.userId,
  });

  @override
  State<BookmarkPage> createState() => _BookmarkPageState();
}

class _BookmarkPageState extends State<BookmarkPage> {
  List<BookmarkEntry> _bookmarks = [];
  bool _isLoading = true;
  String? _error;
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

  List<BookmarkEntry> get _filteredBookmarks {
    if (_selectedTag == 'All') return _bookmarks;
    final keywords = _tagKeywords[_selectedTag] ?? [];
    if (keywords.isEmpty) return _bookmarks;
    return _bookmarks
        .where((b) => keywords.any((kw) => b.summary.bookName.toLowerCase().contains(kw)))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _loadBookmarks();
  }

  Future<void> _loadBookmarks() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final bookmarks = await ApiService.getBookmarks(userId: widget.userId);
      if (mounted) {
        setState(() {
          _bookmarks = bookmarks;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
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
          icon: const Icon(Icons.arrow_back),
          color: ThemeColors.textPrimary(isDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'My Favourites',
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
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? _buildErrorState()
                      : _filteredBookmarks.isEmpty
                          ? _buildEmptyState()
                          : _buildList(context),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary
                        : ThemeColors.card(isDark),
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : ThemeColors.border(isDark),
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
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected
                          ? Colors.white
                          : ThemeColors.textSecondary(isDark),
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
              Icons.bookmark_remove_outlined,
              size: 64,
              color: ThemeColors.textLight(isDark),
            ),
            const SizedBox(height: 16),
            Text(
              'No bookmarks',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: ThemeColors.textPrimary(isDark),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: AppColors.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading bookmarks',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: ThemeColors.textPrimary(isDark),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: ThemeColors.textSecondary(isDark),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadBookmarks,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = _filteredBookmarks;
    return RefreshIndicator(
      onRefresh: _loadBookmarks,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final item = filtered[index];
          return _BookmarkCard(
            entry: item,
            onTap: () {
              Navigator.pushNamed(
                context,
                '/bookmark_detail',
                arguments: {
                  'userId': widget.userId,
                  'entry': item,
                },
              ).then((_) {
                // Reload bookmarks when returning from detail page
                _loadBookmarks();
              });
            },
          );
        },
      ),
    );
  }
}

class _BookmarkCard extends StatelessWidget {
  final BookmarkEntry entry;
  final VoidCallback onTap;

  const _BookmarkCard({
    required this.entry,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final summary = entry.summary;
    final createdText = DateFormat('d MMM, h:mm a').format(entry.createdAt);

    final displayGrade = summary.grade
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
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${summary.bookName} : ${summary.hadithNumber}',
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
                    'Chapter #${summary.chapterNumber}',
                    style: TextStyle(
                      fontSize: 14,
                      color: ThemeColors.textSecondary(isDark),
                    ),
                  ),
                  Text(
                    displayGrade,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.getHadithColor(summary.grade),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                createdText,
                style: TextStyle(
                  fontSize: 12,
                  color: ThemeColors.textLight(isDark),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
