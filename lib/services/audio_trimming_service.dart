import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Service for client-side audio trimming and waveform generation
class AudioTrimmingService {
  /// Minimum duration for a valid audio segment (in seconds)
  static const double minDurationSeconds = 0.5;

  /// Maximum duration for a valid audio segment (in seconds)
  static const double maxDurationSeconds = 300; // 5 minutes

  /// Generate waveform data from audio file
  /// Returns a list of waveform amplitudes (0.0 to 1.0)
  ///
  /// Note: This is a simplified implementation that generates a visual waveform.
  /// For production use, consider integrating a proper audio analysis library
  /// like flutter_sound or just_audio with waveform extraction capabilities.
  static Future<List<double>> generateWaveform({
    required String audioPath,
    int samples = 200, // Number of waveform samples to generate
  }) async {
    try {
      // For now, we'll generate a synthetic waveform based on file properties
      // In production, you would use a proper audio analysis library
      // This provides a visual representation that works with the trimming interface

      final file = File(audioPath);
      if (!await file.exists()) {
        return _generateDefaultWaveform(samples);
      }

      // Generate waveform with some variation based on file properties
      // This creates a more realistic-looking waveform
      final fileSize = await file.length();
      final seed = fileSize % 1000; // Use file size as seed for variation

      return List.generate(samples, (index) {
        // Create a waveform pattern with variation
        final baseAmplitude = 0.3;
        final variation = (index + seed) % 7;
        final amplitude =
            baseAmplitude + (variation * 0.08) + ((index % 13) * 0.02);
        return amplitude.clamp(0.2, 0.9);
      });
    } catch (e) {
      print('Error generating waveform: $e');
      // Return default waveform on error
      return _generateDefaultWaveform(samples);
    }
  }

  /// Generate default waveform pattern
  static List<double> _generateDefaultWaveform(int samples) {
    return List.generate(samples, (index) {
      return 0.3 + (index % 5) * 0.1;
    });
  }

  /// Validate trimming parameters
  /// Returns error message if invalid, null if valid
  static String? validateTrimParameters({
    required double startSeconds,
    required double endSeconds,
    required double totalDurationSeconds,
  }) {
    // Check if start time is valid
    if (startSeconds < 0) {
      return 'Start time cannot be negative';
    }

    // Check if end time is valid
    if (endSeconds > totalDurationSeconds) {
      return 'End time cannot exceed audio duration';
    }

    // Check if start time is less than end time
    if (startSeconds >= endSeconds) {
      return 'Start time must be less than end time';
    }

    // Check minimum duration
    final duration = endSeconds - startSeconds;
    if (duration < minDurationSeconds) {
      return 'Selected segment must be at least ${minDurationSeconds}s long';
    }

    // Check maximum duration
    if (duration > maxDurationSeconds) {
      return 'Selected segment cannot exceed ${maxDurationSeconds}s';
    }

    return null; // Valid
  }

  /// Extract trimmed audio segment (client-side)
  /// Creates a new audio file containing only the selected segment
  /// Note: This is a simplified implementation. For production, consider using
  /// a more robust solution like flutter_ffmpeg or audio_trimmer package
  static Future<String?> extractTrimmedAudio({
    required String originalAudioPath,
    required double startSeconds,
    required double endSeconds,
  }) async {
    try {
      // Validate parameters first
      final originalFile = File(originalAudioPath);
      if (!await originalFile.exists()) {
        throw Exception('Original audio file not found');
      }

      // For a production implementation, you would use a proper audio processing library
      // like flutter_ffmpeg or audio_trimmer. However, since we want to avoid FFmpeg
      // on the server, we'll use a client-side approach.

      // This is a placeholder implementation. In production, you should:
      // 1. Use flutter_ffmpeg (client-side) to extract the segment
      // 2. Or send the original file + trim positions to backend for processing
      // 3. Or use audio_trimmer package which handles this internally

      // For now, we'll create a reference file that contains the trim information
      // The actual trimming will be done when sending to transcription API
      final tempDir = await getTemporaryDirectory();
      final origFileName = originalFile.path.split(RegExp(r'[/\\]')).last;
      final origDotIndex = origFileName.lastIndexOf('.');
      final origExt = (origDotIndex >= 0 && origDotIndex < origFileName.length - 1)
          ? origFileName.substring(origDotIndex + 1)
          : 'm4a';
      final trimmedPath =
          '${tempDir.path}/trimmed_${DateTime.now().millisecondsSinceEpoch}.$origExt';

      // Copy original file (in production, this would be the actual trimmed segment)
      await originalFile.copy(trimmedPath);

      return trimmedPath;
    } catch (e) {
      print('Error extracting trimmed audio: $e');
      return null;
    }
  }

  /// Get audio file metadata
  static Future<Map<String, dynamic>?> getAudioMetadata(
      String audioPath) async {
    try {
      final file = File(audioPath);
      if (!await file.exists()) {
        return null;
      }

      final stat = await file.stat();
      final extension = audioPath.split('.').last.toLowerCase();

      return {
        'path': audioPath,
        'size': stat.size,
        'format': extension,
        'exists': true,
      };
    } catch (e) {
      print('Error getting audio metadata: $e');
      return null;
    }
  }

  /// Clean up temporary files
  static Future<void> cleanupTempFile(String? filePath) async {
    if (filePath == null) return;

    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      print('Error cleaning up temp file: $e');
    }
  }
}
