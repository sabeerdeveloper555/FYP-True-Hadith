import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';
import '../models/hadith_models.dart';

class ApiService {
  // Update this with your Flask backend URL
  static const String baseUrl = 'http://192.168.100.12:5000/api';
  // Change to your backend URL

  // For Android emulator, use: http://10.0.2.2:5000/api
  // For iOS simulator, use: http://localhost:5000/api
  // For physical device, use your computer's IP: http://192.168.x.x:5000/api

  static Future<UserModel> registerUser({
    required String firebaseUid,
    required String username,
    required String email,
    String? profilePhotoUrl,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'firebase_uid': firebaseUid,
          'username': username,
          'email': email,
          if (profilePhotoUrl != null) 'profile_photo_url': profilePhotoUrl,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return UserModel.fromJson(data);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Registration failed');
      }
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Network error: ${e.toString()}');
    }
  }

  static Future<UserModel> loginUser({
    required String firebaseUid,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'firebase_uid': firebaseUid,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return UserModel.fromJson(data);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Login failed');
      }
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Network error: ${e.toString()}');
    }
  }

  static Future<UserModel> updateProfilePhoto({
    required int userId,
    required String profilePhotoUrl,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/user/update-profile-photo'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'user_id': userId,
          'profile_photo_url': profilePhotoUrl,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return UserModel.fromJson(data);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Update failed');
      }
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Network error: ${e.toString()}');
    }
  }

  static Future<UserModel> deleteProfilePhoto({
    required int userId,
  }) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/user/delete-profile-photo'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'user_id': userId,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return UserModel.fromJson(data);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Delete failed');
      }
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Network error: ${e.toString()}');
    }
  }

  static Future<List<HistoryEntry>> getHistory({
    required int userId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/history?user_id=$userId'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      // Check if response is HTML (404 or error page)
      if (response.body.trim().toLowerCase().startsWith('<!doctype') ||
          response.body.trim().toLowerCase().startsWith('<html')) {
        throw Exception(
            'Backend endpoint not found. Please add /api/history endpoint to your backend.');
      }

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          final List<dynamic> historyList = data['history'] ?? [];
          return historyList
              .map((item) => HistoryEntry(
                    historyId: item['history_id'] as int,
                    queryText: item['query_text'] as String,
                    createdAt: DateTime.parse(item['created_at'] as String),
                  ))
              .toList();
        } catch (e) {
          throw Exception('Failed to parse history data: ${e.toString()}');
        }
      } else {
        try {
          final error = jsonDecode(response.body);
          throw Exception(error['message'] ?? 'Failed to fetch history');
        } catch (e) {
          throw Exception(
              'Server error (${response.statusCode}): ${response.body.substring(0, response.body.length > 100 ? 100 : response.body.length)}');
        }
      }
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Network error: ${e.toString()}');
    }
  }

  static Future<void> deleteHistory({
    required int historyId,
  }) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/history/$historyId'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      // Check if response is HTML (404 or error page)
      if (response.body.trim().toLowerCase().startsWith('<!doctype') ||
          response.body.trim().toLowerCase().startsWith('<html')) {
        throw Exception(
            'Backend endpoint not found. Please add DELETE /api/history/{id} endpoint to your backend.');
      }

      if (response.statusCode != 200 && response.statusCode != 204) {
        try {
          final error = jsonDecode(response.body);
          throw Exception(error['message'] ?? 'Failed to delete history');
        } catch (e) {
          throw Exception('Server error (${response.statusCode})');
        }
      }
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Network error: ${e.toString()}');
    }
  }

  static Future<List<BookmarkEntry>> getBookmarks({
    required int userId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/bookmarks?user_id=$userId'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      // Check if response is HTML (404 or error page)
      if (response.body.trim().toLowerCase().startsWith('<!doctype') ||
          response.body.trim().toLowerCase().startsWith('<html')) {
        throw Exception(
            'Backend endpoint not found. Please add /api/bookmarks endpoint to your backend.');
      }

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          final List<dynamic> bookmarkList = data['bookmarks'] ?? [];
          return bookmarkList.map((item) {
            final summaryData = item['summary'] ?? item;
            return BookmarkEntry(
              bookmarkId: item['bookmark_id'] as int,
              hadithId: item['hadith_id'] as int,
              summary: HadithSummary(
                hadithId: summaryData['hadith_id'] as int,
                bookName: summaryData['book_name'] as String,
                hadithNumber: summaryData['hadith_number'] as String,
                chapterNumber: summaryData['chapter_number'].toString(),
                grade: summaryData['grade'] as String? ?? 'Unknown',
              ),
              createdAt: DateTime.parse(item['created_at'] as String),
            );
          }).toList();
        } catch (e) {
          throw Exception('Failed to parse bookmarks data: ${e.toString()}');
        }
      } else {
        try {
          final error = jsonDecode(response.body);
          throw Exception(error['message'] ?? 'Failed to fetch bookmarks');
        } catch (e) {
          throw Exception(
              'Server error (${response.statusCode}): ${response.body.substring(0, response.body.length > 100 ? 100 : response.body.length)}');
        }
      }
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Network error: ${e.toString()}');
    }
  }

  static Future<void> deleteBookmark({
    required int bookmarkId,
  }) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/bookmarks/$bookmarkId'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      // Check if response is HTML (404 or error page)
      if (response.body.trim().toLowerCase().startsWith('<!doctype') ||
          response.body.trim().toLowerCase().startsWith('<html')) {
        throw Exception(
            'Backend endpoint not found. Please add DELETE /api/bookmarks/{id} endpoint to your backend.');
      }

      if (response.statusCode != 200 && response.statusCode != 204) {
        try {
          final error = jsonDecode(response.body);
          throw Exception(error['message'] ?? 'Failed to delete bookmark');
        } catch (e) {
          throw Exception('Server error (${response.statusCode})');
        }
      }
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Network error: ${e.toString()}');
    }
  }

  static Future<List<HadithSummary>> searchHadiths({
    required int userId,
    required String query,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/search'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'user_id': userId,
          'query': query,
        }),
      );

      // Check if response is HTML (404 or error page)
      if (response.body.trim().toLowerCase().startsWith('<!doctype') ||
          response.body.trim().toLowerCase().startsWith('<html')) {
        throw Exception(
            'Backend endpoint not found. Please add POST /api/search endpoint to your backend.');
      }

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          final List<dynamic> resultsList = data['results'] ?? [];
          return resultsList
              .map((item) => HadithSummary(
                    hadithId: item['hadith_id'] as int,
                    bookName: item['book_name'] as String,
                    hadithNumber: item['hadith_number'].toString(),
                    chapterNumber: item['chapter_number'].toString(),
                    grade: item['grade'] as String? ?? 'No grade mention',
                  ))
              .toList();
        } catch (e) {
          throw Exception('Failed to parse search results: ${e.toString()}');
        }
      } else {
        try {
          final error = jsonDecode(response.body);
          throw Exception(error['message'] ?? 'Search failed');
        } catch (e) {
          throw Exception(
              'Server error (${response.statusCode}): ${response.body.substring(0, response.body.length > 100 ? 100 : response.body.length)}');
        }
      }
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Network error: ${e.toString()}');
    }
  }

  static Future<Map<String, dynamic>> getHadithDetailWithBookmark({
    required int hadithId,
    required int userId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/hadith/$hadithId?user_id=$userId'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      // Check if response is HTML (404 or error page)
      if (response.body.trim().toLowerCase().startsWith('<!doctype') ||
          response.body.trim().toLowerCase().startsWith('<html')) {
        throw Exception(
            'Backend endpoint not found. Please add GET /api/hadith/{id} endpoint to your backend.');
      }

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          return {
            'detail': HadithDetail(
              hadithId: data['hadith_id'] as int,
              bookName: data['book_name'] as String,
              hadithNumber: data['hadith_number'].toString(),
              chapterNumber: data['chapter_number'].toString(),
              chapterName: data['chapter_name'] as String,
              grade: data['grade'] as String,
              narrator: data['narrator'] as String,
              arabicText: data['arabic_text'] as String,
              englishText: data['english_text'] as String,
              urduText: data['urdu_text'] as String,
              bookmarkedAt: data['bookmarked'] == true &&
                      data['bookmark_id'] != null
                  ? DateTime
                      .now() // We don't have the actual bookmark date from the API
                  : null,
            ),
            'bookmarked': data['bookmarked'] as bool? ?? false,
            'bookmarkId': data['bookmark_id'] as int?,
          };
        } catch (e) {
          throw Exception(
              'Failed to parse hadith detail data: ${e.toString()}');
        }
      } else if (response.statusCode == 404) {
        throw Exception('Hadith not found');
      } else {
        try {
          final error = jsonDecode(response.body);
          throw Exception(error['message'] ?? 'Failed to fetch hadith detail');
        } catch (e) {
          throw Exception(
              'Server error (${response.statusCode}): ${response.body.substring(0, response.body.length > 100 ? 100 : response.body.length)}');
        }
      }
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Network error: ${e.toString()}');
    }
  }

  static Future<int> createBookmark({
    required int userId,
    required int hadithId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/bookmarks'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'user_id': userId,
          'hadith_id': hadithId,
        }),
      );

      // Check if response is HTML (404 or error page)
      if (response.body.trim().toLowerCase().startsWith('<!doctype') ||
          response.body.trim().toLowerCase().startsWith('<html')) {
        throw Exception(
            'Backend endpoint not found. Please add POST /api/bookmarks endpoint to your backend.');
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          final data = jsonDecode(response.body);
          return data['bookmark_id'] as int;
        } catch (e) {
          throw Exception('Failed to parse bookmark response: ${e.toString()}');
        }
      } else {
        try {
          final error = jsonDecode(response.body);
          throw Exception(error['message'] ?? 'Failed to create bookmark');
        } catch (e) {
          throw Exception(
              'Server error (${response.statusCode}): ${response.body.substring(0, response.body.length > 100 ? 100 : response.body.length)}');
        }
      }
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Network error: ${e.toString()}');
    }
  }

  /// Get the latest conversation with all messages for a user
  static Future<Map<String, dynamic>> getLatestConversation({
    required int userId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/conversations/latest?user_id=$userId'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'conversation_id': data['conversation_id'] as int?,
          'created_at': data['created_at'] != null
              ? DateTime.parse(data['created_at'] as String)
              : null,
          'updated_at': data['updated_at'] != null
              ? DateTime.parse(data['updated_at'] as String)
              : null,
          'messages': (data['messages'] as List?) ?? [],
        };
      } else {
        try {
          final error = jsonDecode(response.body);
          throw Exception(error['message'] ?? 'Failed to fetch conversation');
        } catch (e) {
          throw Exception(
              'Server error (${response.statusCode}): ${response.body.substring(0, response.body.length > 100 ? 100 : response.body.length)}');
        }
      }
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Network error: ${e.toString()}');
    }
  }

  /// Get all conversations list for a user (for sidebar history)
  static Future<List<Map<String, dynamic>>> getConversations({
    required int userId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/conversations?user_id=$userId'),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['conversations'] ?? []);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to fetch conversations');
      }
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Network error: ${e.toString()}');
    }
  }

  /// Get all messages for a specific conversation
  static Future<Map<String, dynamic>> getConversationMessages({
    required int conversationId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/conversations/$conversationId/messages'),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'conversation_id': data['conversation_id'] as int,
          'messages': (data['messages'] as List?) ?? [],
        };
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to fetch conversation messages');
      }
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Network error: ${e.toString()}');
    }
  }

  /// Get ALL messages from ALL conversations for a user (like WhatsApp)
  static Future<Map<String, dynamic>> getAllUserMessages({
    required int userId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/conversations/user/$userId/all_messages'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Get the latest conversation_id from the messages
        final messages = (data['messages'] as List?) ?? [];
        int? latestConversationId;
        if (messages.isNotEmpty) {
          // Get the most recent conversation_id
          for (var msg in messages.reversed) {
            if (msg['conversation_id'] != null) {
              latestConversationId = msg['conversation_id'] as int;
              break;
            }
          }
        }

        return {
          'conversation_id': latestConversationId,
          'total_messages': data['total_messages'] as int? ?? 0,
          'messages': messages,
        };
      } else {
        try {
          final error = jsonDecode(response.body);
          throw Exception(error['message'] ?? 'Failed to fetch all messages');
        } catch (e) {
          throw Exception(
              'Server error (${response.statusCode}): ${response.body.substring(0, response.body.length > 100 ? 100 : response.body.length)}');
        }
      }
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Network error: ${e.toString()}');
    }
  }

  /// Register or refresh the FCM device token for push notifications.
  /// Best-effort: failures are logged but not surfaced to the user.
  static Future<void> registerFcmToken({
    required int userId,
    required String token,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/user/fcm-token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': userId, 'fcm_token': token}),
      );
      if (response.statusCode != 200) {
        debugPrint('FCM token registration failed (${response.statusCode})');
      }
    } catch (e) {
      debugPrint('FCM token registration error: $e');
    }
  }

  /// Send a chat message to the AI assistant
  static Future<Map<String, dynamic>> sendChatMessage({
    required int userId,
    int? conversationId,
    required String question,
  }) async {
    try {
      // Create client with increased timeout for chat (60 seconds)
      final client = http.Client();
      try {
        final response = await client
            .post(
          Uri.parse('$baseUrl/chat'),
          headers: {
            'Content-Type': 'application/json',
            'Connection': 'keep-alive',
          },
          body: jsonEncode({
            'user_id': userId,
            'conversation_id': conversationId,
            'question': question,
          }),
        )
            .timeout(
          const Duration(seconds: 60),
          onTimeout: () {
            client.close();
            throw Exception('Request timeout: Chat response took too long');
          },
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          return {
            'conversation_id': data['conversation_id'] as int,
            'reply': data['reply'] as String,
          };
        } else {
          try {
            final error = jsonDecode(response.body);
            throw Exception(error['message'] ?? 'Chat failed');
          } catch (e) {
            throw Exception(
                'Server error (${response.statusCode}): ${response.body.substring(0, response.body.length > 100 ? 100 : response.body.length)}');
          }
        }
      } finally {
        client.close();
      }
    } catch (e) {
      // Handle connection abort and timeout errors
      if (e.toString().contains('Connection') ||
          e.toString().contains('connection abort') ||
          e.toString().contains('timeout')) {
        throw Exception(
            'Connection error: The request took too long or was interrupted. Please try again.');
      }
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Network error: ${e.toString()}');
    }
  }

}
