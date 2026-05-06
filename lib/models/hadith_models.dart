/// Lightweight models used on the Flutter side.
/// Backend (Flask + PostgreSQL) is responsible for actually
/// running FAISS, CSV mapping and SQL queries.
library;

class HadithSummary {
  final int hadithId;
  final String bookName;
  final String hadithNumber;
  final String chapterNumber;
  final String grade;

  HadithSummary({
    required this.hadithId,
    required this.bookName,
    required this.hadithNumber,
    required this.chapterNumber,
    required this.grade,
  });
}

class HadithDetail {
  final int hadithId;
  final String bookName;
  final String hadithNumber;
  final String chapterNumber;
  final String chapterName;
  final String grade;
  final String narrator;
  final String arabicText;
  final String englishText;
  final String urduText;
  final DateTime? bookmarkedAt;

  HadithDetail({
    required this.hadithId,
    required this.bookName,
    required this.hadithNumber,
    required this.chapterNumber,
    required this.chapterName,
    required this.grade,
    required this.narrator,
    required this.arabicText,
    required this.englishText,
    required this.urduText,
    this.bookmarkedAt,
  });
}

class BookmarkEntry {
  final int bookmarkId;
  final int hadithId;
  final HadithSummary summary;
  final DateTime createdAt;

  BookmarkEntry({
    required this.bookmarkId,
    required this.hadithId,
    required this.summary,
    required this.createdAt,
  });
}

class HistoryEntry {
  final int historyId;
  final String queryText;
  final DateTime createdAt;

  HistoryEntry({
    required this.historyId,
    required this.queryText,
    required this.createdAt,
  });
}
