import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../services/api_service.dart';

/// Service for audio transcription
class TranscriptionService {
  /// Transcribe audio file using backend API
  ///
  /// [audioPath] - Path to the audio file (original or trimmed)
  /// [startSeconds] - Start time of the segment to transcribe (optional, for trimmed audio)
  /// [endSeconds] - End time of the segment to transcribe (optional, for trimmed audio)
  /// [language] - Language code to restrict transcription: 'ur' for Urdu, 'en' for English, 'ar' for Arabic, or null for auto-detect
  ///
  /// Returns the transcribed text
  static Future<String> transcribeAudio({
    required String audioPath,
    double? startSeconds,
    double? endSeconds,
    String? language,
  }) async {
    try {
      // Get base URL from ApiService
      String baseUrl = ApiService.baseUrl;
      if (baseUrl.endsWith('/api')) {
        baseUrl = baseUrl.substring(0, baseUrl.length - 4);
      }

      // Trim audio client-side if start/end positions are provided and differ from full audio
      String finalAudioPath = audioPath;
      if (startSeconds != null && endSeconds != null && startSeconds > 0) {
        try {
          print(
              '✂️ Trimming audio client-side: ${startSeconds}s to ${endSeconds}s');
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
      } else {
        print('📝 Using full audio (no trimming requested)');
      }

      // Read audio file (trimmed or original)
      final audioFile = File(finalAudioPath);
      if (!await audioFile.exists()) {
        throw Exception('Audio file not found: $finalAudioPath');
      }

      final audioBytes = await audioFile.readAsBytes();
      final audioBase64 = base64Encode(audioBytes);

      // Clean up trimmed file if it was created
      if (finalAudioPath != audioPath) {
        try {
          await audioFile.delete();
        } catch (e) {
          print('Warning: Could not delete trimmed temp file: $e');
        }
      }

      // Get file extension safely (handle filenames without extensions)
      final fileName = finalAudioPath.split(RegExp(r'[/\\]')).last;
      final dotIndex = fileName.lastIndexOf('.');
      final extension = (dotIndex >= 0 && dotIndex < fileName.length - 1)
          ? fileName.substring(dotIndex + 1).toLowerCase()
          : 'm4a';

      // Prepare request body (don't send trim positions since audio is already trimmed)
      final requestBody = {
        'audio': audioBase64,
        'audio_format': extension,
        if (language != null) 'language': language,
      };

      print('🎤 Sending audio for transcription...');
      print('   - Audio size: ${audioBytes.length} bytes');
      print('   - Format: $extension');
      print('   - Language parameter: ${language ?? "null (auto-detect)"}');
      if (language != null) {
        print('   - ⚠️ Language RESTRICTED to: $language');
      } else {
        print(
            '   - ✅ Language: AUTO-DETECT (Whisper will detect automatically)');
      }
      if (startSeconds != null && endSeconds != null) {
        print(
            '   - ⚠️ Trim positions: ${startSeconds}s to ${endSeconds}s (but full audio sent - trimming not implemented)');
      }

      // Send request to backend
      final response = await http
          .post(
        Uri.parse('$baseUrl/api/transcribe'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      )
          .timeout(
        const Duration(seconds: 120), // 2 minutes timeout for transcription
        onTimeout: () {
          throw Exception('Transcription request timed out');
        },
      );

      print('📝 Transcription response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final transcript = data['transcript'] as String? ?? '';

        if (transcript.isEmpty) {
          throw Exception('Empty transcript received from server');
        }

        print('✅ Transcription successful: ${transcript.length} characters');
        return transcript.trim();
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Transcription failed');
      }
    } catch (e) {
      print('❌ Transcription error: $e');
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Transcription failed: ${e.toString()}');
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
          .get(
            Uri.parse('$baseUrl/api/health'),
          )
          .timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Trim audio client-side using platform channels (native Android/iOS APIs)
  /// Uses MediaExtractor/MediaMuxer on Android and AVFoundation on iOS
  static Future<String?> _trimAudioClientSide({
    required String audioPath,
    required double startSeconds,
    required double endSeconds,
  }) async {
    try {
      print('✂️ Trimming audio using native platform APIs...');
      print('   - Input: $audioPath');
      print('   - Range: ${startSeconds}s to ${endSeconds}s');

      // Get temporary directory for output
      final tempDir = await getTemporaryDirectory();
      final inputFile = File(audioPath);
      final inputFileName = inputFile.path.split(RegExp(r'[/\\]')).last;
      final inputDotIndex = inputFileName.lastIndexOf('.');
      final extension = (inputDotIndex >= 0 && inputDotIndex < inputFileName.length - 1)
          ? inputFileName.substring(inputDotIndex + 1)
          : 'm4a';
      final outputPath =
          '${tempDir.path}/trimmed_${DateTime.now().millisecondsSinceEpoch}.$extension';

      // Call platform channel to trim audio
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
