import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/hadith_models.dart';
import '../core/theme/app_colors.dart';
import '../utils/theme_notifier.dart';
import '../services/api_service.dart';

class HistoryPage extends StatefulWidget {
  final int userId;

  const HistoryPage({
    super.key,
    required this.userId,
  });

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<HistoryEntry> _history = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final history = await ApiService.getHistory(userId: widget.userId);
      if (mounted) {
        setState(() {
          _history = history;
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

  Future<void> _deleteHistory(int historyId) async {
    try {
      await ApiService.deleteHistory(historyId: historyId);
      if (mounted) {
        // Reload history after deletion
        await _loadHistory();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('History deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeNotifier.instance.isDark;
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
          'My History',
          style: TextStyle(
            color: ThemeColors.textPrimary(isDark),
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _buildErrorState()
                : _history.isEmpty
                    ? _buildEmptyState()
                    : _buildList(context),
      ),
    );
  }

  Widget _buildEmptyState() {
    final isDark = ThemeNotifier.instance.isDark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.manage_search_rounded,
              size: 64,
              color: ThemeColors.textLight(isDark),
            ),
            const SizedBox(height: 16),
            Text(
              'No History Found',
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
    final isDark = ThemeNotifier.instance.isDark;
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
              'Error loading history',
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
              onPressed: _loadHistory,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context) {
    final isDark = ThemeNotifier.instance.isDark;
    return RefreshIndicator(
      onRefresh: _loadHistory,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _history.length,
        itemBuilder: (context, index) {
          final item = _history[index];
          return _HistoryCard(
            entry: item,
            onTap: () {
              Navigator.pushNamed(
                context,
                '/history_detail',
                arguments: item,
              ).then((_) {
                // Reload history when returning from detail page
                _loadHistory();
              });
            },
            onDelete: () async {
              await _deleteHistory(item.historyId);
            },
          );
        },
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final HistoryEntry entry;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _HistoryCard({
    required this.entry,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeNotifier.instance.isDark;
    final date = DateFormat('EEE\nd MMM yy').format(entry.createdAt);
    final time = DateFormat('h:mm a').format(entry.createdAt);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              SizedBox(
                width: 80,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      date,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: ThemeColors.textPrimary(isDark),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      time,
                      style: TextStyle(
                        fontSize: 12,
                        color: ThemeColors.textSecondary(isDark),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  entry.queryText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    color: ThemeColors.textPrimary(isDark),
                  ),
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert,
                  color: ThemeColors.textSecondary(isDark),
                ),
                onSelected: (value) {
                  if (value == 'delete') {
                    onDelete();
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
