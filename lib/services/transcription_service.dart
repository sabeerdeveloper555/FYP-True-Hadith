import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../services/api_service.dart';

/// Service for audio transcription
class TranscriptionService {
  /// Transcribe audio file using backend API (multipart/form-data upload).
  ///
  /// [audioPath] - Path to the audio file (original or trimmed)
  /// [startSeconds] - Start time of the segment to transcribe (trims before upload)
  /// [endSeconds] - End time of the segment to transcribe (trims before upload)
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
      print('🎤 Sending audio for transcription (multipart)...');
      print('   - File size: $fileSize bytes');
      print('   - Format: $extension');
      print('   - Language: ${language ?? "auto-detect"}');

      // Build multipart request — no base64 encoding, streams the file directly
      final uri = Uri.parse('$baseUrl/api/transcribe');
      final request = http.MultipartRequest('POST', uri);

      // Read file bytes before building the request so the temp file can be
      // safely deleted in the finally block regardless of request outcome.
      final audioBytes = await audioFile.readAsBytes();
      request.files.add(http.MultipartFile.fromBytes(
        'audio',
        audioBytes,
        filename: 'audio.$extension',
      ));
      if (language != null) {
        request.fields['language'] = language;
      }

      http.StreamedResponse? streamedResponse;
      try {
        streamedResponse = await request.send().timeout(
          const Duration(seconds: 110),
          onTimeout: () {
            throw Exception('Transcription timed out. Please check your backend connection and try again.');
          },
        );
      } finally {
        // Clean up trimmed temp file after the request is sent (success or failure).
        if (finalAudioPath != audioPath) {
          try {
            await audioFile.delete();
          } catch (e) {
            print('Warning: Could not delete trimmed temp file: $e');
          }
        }
      }

      final responseBody = await streamedResponse.stream.bytesToString();
      print('📝 Transcription response status: ${streamedResponse.statusCode}');

      if (streamedResponse.statusCode == 200) {
        final data = jsonDecode(responseBody);
        final transcript = data['transcript'] as String? ?? '';
        if (transcript.isEmpty) {
          throw Exception('Empty transcript received from server');
        }
        print('✅ Transcription successful: ${transcript.length} characters');
        return transcript.trim();
      } else {
        final error = jsonDecode(responseBody);
        throw Exception(error['message'] ?? 'Transcription failed');
      }
    } catch (e) {
      print('❌ Transcription error: $e');
      // Strip "Exception: " prefix so the UI message isn't doubled up.
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
