import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/hadith_models.dart';
import '../core/theme/app_colors.dart';
import '../services/api_service.dart';

class HistoryDetailPage extends StatelessWidget {
  final HistoryEntry entry;

  const HistoryDetailPage({
    super.key,
    required this.entry,
  });

  Future<void> _deleteHistory(BuildContext context) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete History'),
        content:
            const Text('Are you sure you want to delete this history entry?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ApiService.deleteHistory(historyId: entry.historyId);
      if (context.mounted) {
        Navigator.pop(context, true); // Return true to indicate deletion
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('History deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final day = DateFormat('EEE').format(entry.createdAt);
    final date = DateFormat('d MMM yy').format(entry.createdAt);
    final time = DateFormat('h:mm a').format(entry.createdAt);

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
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            color: AppColors.error,
            onPressed: () => _deleteHistory(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 16),
              Text(
                '$day   $date   $time',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: ThemeColors.textSecondary(isDark),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    entry.queryText,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      height: 1.6,
                      color: ThemeColors.textPrimary(isDark),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
