import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../services/api_service.dart';

/// Service for audio transcription
class TranscriptionService {
  /// Transcribe audio file using backend API.
  ///
  /// Uses multipart/form-data (like a browser file upload) which is the most
  /// reliable method on Android — avoids base64 bloat and chunked-encoding
  /// issues that cause silent request hangs.
  static Future<String> transcribeAudio({
    required String audioPath,
    double? startSeconds,
    double? endSeconds,
    String? language,
  }) async {
    try {
      String baseUrl = ApiService.baseUrl;
      if (baseUrl.endsWith('/api')) {
        baseUrl = baseUrl.substring(0, baseUrl.length - 4);
      }

      // ── Step 0: Verify backend is reachable ──
      final isAvailable = await checkServiceAvailability();
      if (!isAvailable) {
        throw Exception(
          'Backend server is not reachable at $baseUrl. '
          'Make sure the Flask server is running and your phone is on the same network.',
        );
      }

      // ── Step 1: Trim audio client-side when needed ──
      String finalAudioPath = audioPath;
      if (startSeconds != null && endSeconds != null && startSeconds > 0) {
        try {
          print('✂️ Trimming audio: ${startSeconds}s to ${endSeconds}s');
          final trimmedPath = await _trimAudioClientSide(
            audioPath: audioPath,
            startSeconds: startSeconds,
            endSeconds: endSeconds,
          );
          if (trimmedPath != null) {
            finalAudioPath = trimmedPath;
            print('✅ Audio trimmed successfully');
          } else {
            print('⚠️ Trimming failed, using full audio');
          }
        } catch (e) {
          print('⚠️ Error trimming audio: $e, using full audio');
        }
      }

      final audioFile = File(finalAudioPath);
      if (!await audioFile.exists()) {
        throw Exception('Audio file not found: $finalAudioPath');
      }

      final fileName = finalAudioPath.split(RegExp(r'[/\\]')).last;
      final dotIndex = fileName.lastIndexOf('.');
      final extension = (dotIndex >= 0 && dotIndex < fileName.length - 1)
          ? fileName.substring(dotIndex + 1).toLowerCase()
          : 'm4a';

      final fileSize = await audioFile.length();

      if (fileSize > 25 * 1024 * 1024) {
        throw Exception(
          'Audio file is too large (${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB). '
          'Please trim it to under 25 MB before transcribing.',
        );
      }

      if (fileSize < 1000) {
        throw Exception(
          'Audio file is too small ($fileSize bytes) — it may be empty or corrupted.',
        );
      }

      final uri = Uri.parse('$baseUrl/api/transcribe');

      print('🎤 Preparing multipart upload...');
      print('   - File: $finalAudioPath');
      print('   - Size: $fileSize bytes (${(fileSize / 1024).toStringAsFixed(1)} KB)');
      print('   - Format: $extension');
      print('   - Language: ${language ?? "auto-detect"}');
      print('   - Endpoint: $uri');

      // ── Step 2: Build multipart request ──
      // Multipart is MORE reliable than base64 JSON on Android because:
      // 1. No 33% size bloat from base64 encoding
      // 2. http.MultipartRequest uses proper Content-Length (no chunked encoding)
      // 3. Standard browser-style file upload that every server handles well

      final request = http.MultipartRequest('POST', uri);

      // Add audio file
      request.files.add(await http.MultipartFile.fromPath(
        'audio',
        finalAudioPath,
        filename: 'audio.$extension',
      ));

      // Add language field if specified
      if (language != null) {
        request.fields['language'] = language;
      }

      print('📤 Sending multipart request...');

      // ── Step 3: Send with timeout ──
      http.Response response;
      try {
        final streamedResponse = await request.send().timeout(
          const Duration(seconds: 150),
          onTimeout: () {
            throw TimeoutException('Upload timed out after 150 seconds');
          },
        );

        print('📥 Upload complete, reading response (HTTP ${streamedResponse.statusCode})...');

        response = await http.Response.fromStream(streamedResponse).timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            throw TimeoutException('Response read timed out');
          },
        );
      } on SocketException catch (e) {
        print('❌ SocketException: $e');
        throw Exception(
          'Cannot connect to the backend server. '
          'Check that Flask is running and your phone is on the same Wi-Fi.',
        );
      } on TimeoutException catch (e) {
        print('❌ Timeout: $e');
        throw Exception(
          'Transcription request timed out. '
          'Check your network connection and try again.',
        );
      }

      // Clean up temp trimmed file
      if (finalAudioPath != audioPath) {
        try {
          await File(finalAudioPath).delete();
        } catch (_) {}
      }

      final responseBody = response.body.trim();
      print('📝 Response: HTTP ${response.statusCode} (${responseBody.length} chars)');

      if (responseBody.isEmpty) {
        throw Exception(
          'Empty response from server (HTTP ${response.statusCode}). '
          'Check Flask console logs.',
        );
      }

      // ── Step 4: Parse response ──
      Map<String, dynamic> data;
      try {
        data = jsonDecode(responseBody) as Map<String, dynamic>;
      } catch (e) {
        print('❌ Failed to parse: ${responseBody.substring(0, responseBody.length > 200 ? 200 : responseBody.length)}');
        throw Exception('Invalid response from server (HTTP ${response.statusCode}).');
      }

      final success = data['success'] as bool? ?? false;

      if (success) {
        final transcript = data['transcript'] as String? ?? '';
        if (transcript.isEmpty) {
          throw Exception(
            'Whisper returned an empty transcript. '
            'The audio may be silent or too noisy.',
          );
        }
        print('✅ Transcription successful: ${transcript.length} characters');
        return transcript.trim();
      } else {
        final serverMsg = data['message'] as String? ?? 'Unknown error';
        final errorCode = data['error'] as String? ?? '';
        if (errorCode == 'API_KEY_ERROR' || errorCode == 'API_KEY_MISSING') {
          throw Exception('OpenAI API key issue on the server.');
        } else if (errorCode == 'QUOTA_ERROR') {
          throw Exception('OpenAI API quota exceeded.');
        } else {
          throw Exception('Transcription failed: $serverMsg');
        }
      }
    } catch (e) {
      print('❌ Transcription error: $e');
      final msg = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      throw Exception(msg);
    }
  }

  /// Check if backend is reachable
  static Future<bool> checkServiceAvailability() async {
    try {
      String baseUrl = ApiService.baseUrl;
      if (baseUrl.endsWith('/api')) {
        baseUrl = baseUrl.substring(0, baseUrl.length - 4);
      }

      final response = await http
          .get(Uri.parse('$baseUrl/api/health'))
          .timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      print('⚠️ Health check failed: $e');
      return false;
    }
  }

  /// Trim audio client-side using platform channels
  static Future<String?> _trimAudioClientSide({
    required String audioPath,
    required double startSeconds,
    required double endSeconds,
  }) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final inputFile = File(audioPath);
      final inputFileName = inputFile.path.split(RegExp(r'[/\\]')).last;
      final inputDotIndex = inputFileName.lastIndexOf('.');
      final extension =
          (inputDotIndex >= 0 && inputDotIndex < inputFileName.length - 1)
              ? inputFileName.substring(inputDotIndex + 1)
              : 'm4a';
      final outputPath =
          '${tempDir.path}/trimmed_${DateTime.now().millisecondsSinceEpoch}.$extension';

      const platform = MethodChannel('com.example.true_hadith/audio_trim');

      final result = await platform.invokeMethod<String>('trimAudio', {
        'audioPath': audioPath,
        'startSeconds': startSeconds,
        'endSeconds': endSeconds,
        'outputPath': outputPath,
      });

      if (result != null && await File(result).exists()) {
        return result;
      }
      return null;
    } on PlatformException catch (e) {
      print('❌ Platform error trimming: ${e.message}');
      return null;
    } catch (e) {
      print('❌ Error trimming: $e');
      return null;
    }
  }
}