import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../services/api_service.dart';

/// Service for audio transcription
class TranscriptionService {
  /// Transcribe audio file using backend API.
  ///
  /// Sends audio as base64-encoded JSON (same pattern as other API endpoints)
  /// to avoid multipart/form-data issues on Android.
  ///
  /// [audioPath] - Path to the audio file (original or trimmed)
  /// [startSeconds] - Start time of the segment to transcribe
  /// [endSeconds] - End time of the segment to transcribe
  /// [language] - Language code: 'ur', 'en', 'ar', or null for auto-detect
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

      // Trim audio client-side when a non-zero start is requested
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
      // OpenAI Whisper rejects files over 25 MB
      if (fileSize > 25 * 1024 * 1024) {
        throw Exception(
          'Audio file is too large (${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB). '
          'Please trim it to under 25 MB before transcribing.',
        );
      }

      print('🎤 Sending audio for transcription (JSON/base64)...');
      print('   - File size: $fileSize bytes');
      print('   - Format: $extension');
      print('   - Language: ${language ?? "auto-detect"}');

      // Read bytes and base64-encode — same upload pattern as search/other endpoints.
      // This avoids multipart/form-data chunked-encoding issues on Android.
      final audioBytes = await audioFile.readAsBytes();
      final audioBase64 = base64Encode(audioBytes);

      // Clean up temp trimmed file now that bytes are in memory.
      if (finalAudioPath != audioPath) {
        try {
          await audioFile.delete();
        } catch (e) {
          print('Warning: Could not delete trimmed temp file: $e');
        }
      }

      final uri = Uri.parse('$baseUrl/api/transcribe');

      // http.post() sets Content-Length explicitly, avoiding chunked encoding.
      // The 180 s timeout covers both upload + Whisper processing (backend waits up to 150 s).
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'audio': audioBase64,
              'filename': 'audio.$extension',
              if (language != null) 'language': language,
            }),
          )
          .timeout(
            const Duration(seconds: 180),
            onTimeout: () {
              throw Exception(
                  'Transcription timed out. The audio may be too long or the server is overloaded. Try a shorter clip.');
            },
          );

      final responseBody = response.body.trim();
      print('📝 Transcription response status: ${response.statusCode}');

      if (responseBody.isEmpty) {
        throw Exception('Empty response from server. Is the backend running?');
      }

      final data = jsonDecode(responseBody) as Map<String, dynamic>;
      final success = data['success'] as bool? ?? false;

      if (success) {
        final transcript = data['transcript'] as String? ?? '';
        if (transcript.isEmpty) {
          throw Exception('Empty transcript received from server');
        }
        print('✅ Transcription successful: ${transcript.length} characters');
        return transcript.trim();
      } else {
        throw Exception(data['message'] as String? ?? 'Transcription failed');
      }
    } catch (e) {
      print('❌ Transcription error: $e');
      final msg = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      throw Exception(msg);
    }
  }

  /// Check if transcription service is available
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
      return false;
    }
  }

  /// Trim audio client-side using platform channels (native Android/iOS APIs)
  static Future<String?> _trimAudioClientSide({
    required String audioPath,
    required double startSeconds,
    required double endSeconds,
  }) async {
    try {
      print('✂️ Trimming audio using native platform APIs...');
      print('   - Input: $audioPath');
      print('   - Range: ${startSeconds}s to ${endSeconds}s');

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
        final outputFile = File(result);
        final fileSize = await outputFile.length();
        print('✅ Audio trimmed successfully');
        print('   - Output: $result');
        print('   - Size: $fileSize bytes');
        return result;
      } else {
        print('⚠️ Trimming returned null or file not found');
        return null;
      }
    } on PlatformException catch (e) {
      print('❌ Platform error trimming audio: ${e.message}');
      print('   Code: ${e.code}');
      return null;
    } catch (e) {
      print('❌ Error trimming audio: $e');
      return null;
    }
  }
}
