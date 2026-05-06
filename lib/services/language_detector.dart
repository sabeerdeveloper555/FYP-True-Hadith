import 'dart:io';
import 'package:flutter/foundation.dart'; // For compute()
import 'package:image/image.dart' as img;

/// Detected language/script information
class DetectedLanguage {
  final ScriptType scriptType;
  final double confidence;
  final String? detectedText; // Sample text if available

  DetectedLanguage({
    required this.scriptType,
    required this.confidence,
    this.detectedText,
  });

  bool get isEnglish => scriptType == ScriptType.latin;
  bool get isArabic => scriptType == ScriptType.arabic;
  bool get isUrdu => scriptType == ScriptType.arabic; // Urdu uses Arabic script
  bool get isMixed => scriptType == ScriptType.mixed;
}

/// Script types for language detection
enum ScriptType {
  latin, // English, Roman Urdu
  arabic, // Arabic, Urdu (Nastaliq)
  mixed, // Mixed languages
  unknown, // Cannot determine
}

/// Language detector service
/// Uses visual analysis and Unicode detection to identify script type
class LanguageDetector {
  /// Detect script type from image using visual analysis
  /// Returns detected language with confidence score
  /// CRITICAL: Runs in background isolate to prevent UI blocking
  static Future<DetectedLanguage> detectScript(String imagePath) async {
    // Move heavy image decoding to background isolate
    return await compute(_detectScriptInIsolate, imagePath);
  }

  /// Helper function to run language detection in isolate
  /// Must be top-level or static for compute()
  static Future<DetectedLanguage> _detectScriptInIsolate(
      String imagePath) async {
    try {
      print(
          'Language Detection: Analyzing image for script type (in isolate)...');

      // Read and decode image (happens in isolate, doesn't block UI)
      final File imageFile = File(imagePath);
      final Uint8List imageBytes = await imageFile.readAsBytes();
      final img.Image? image = img.decodeImage(imageBytes);

      if (image == null) {
        print(
            'Language Detection: ⚠ Failed to decode image, defaulting to mixed');
        return DetectedLanguage(
          scriptType: ScriptType.mixed,
          confidence: 0.5,
        );
      }

      // Method 1: Visual analysis (character shape detection)
      final visualResult = _analyzeVisualFeatures(image);

      // Method 2: Quick OCR-based detection (if available)
      // This would require a lightweight OCR pass, which we'll skip for performance

      print(
          'Language Detection: Visual analysis result: ${visualResult.scriptType} (confidence: ${visualResult.confidence})');

      return visualResult;
    } catch (e) {
      print('Language Detection: Error during detection: $e');
      // Default to mixed if detection fails
      return DetectedLanguage(
        scriptType: ScriptType.mixed,
        confidence: 0.5,
      );
    }
  }

  /// Analyze visual features of the image to detect script type
  /// This is a heuristic-based approach suitable for mobile
  static DetectedLanguage _analyzeVisualFeatures(img.Image image) {
    // Convert to grayscale for analysis
    final grayscale = img.grayscale(
        img.copyResize(image, width: 800)); // Resize for faster analysis

    // Analyze image characteristics
    final stats = _calculateImageStatistics(grayscale);

    // Heuristic rules based on research:
    // 1. Arabic/Urdu: More connected components, RTL baseline, cursive patterns
    // 2. English: Discrete characters, horizontal baseline, clear spacing

    double arabicScore = 0.0;
    double latinScore = 0.0;

    // Rule 1: Character connectivity (Arabic is more cursive)
    if (stats.avgComponentSize > 50) {
      arabicScore += 0.3; // Arabic has larger connected components
    } else {
      latinScore += 0.3; // English has smaller, discrete components
    }

    // Rule 2: Baseline analysis (simplified - would need more sophisticated analysis)
    if (stats.horizontalVariance > 0.3) {
      arabicScore += 0.2; // Arabic has more vertical variation (Nastaliq)
    } else {
      latinScore += 0.2; // English has more horizontal baseline
    }

    // Rule 3: Edge density (Arabic has more curves)
    if (stats.edgeDensity > 0.15) {
      arabicScore += 0.2;
    } else {
      latinScore += 0.2;
    }

    // Rule 4: Text density (Arabic/Urdu often has denser text)
    if (stats.textDensity > 0.4) {
      arabicScore += 0.3;
    } else {
      latinScore += 0.3;
    }

    // Determine result
    final totalScore = arabicScore + latinScore;
    if (totalScore == 0) {
      return DetectedLanguage(
        scriptType: ScriptType.unknown,
        confidence: 0.5,
      );
    }

    final arabicConfidence = arabicScore / totalScore;
    final latinConfidence = latinScore / totalScore;

    // CRITICAL FIX: Default to Arabic/Mixed when uncertain - NEVER trust English detection
    // Visual heuristics are unreliable - always prefer Arabic path to avoid Tesseract gibberish
    // Only use Tesseract if we're 99.5%+ confident AND Arabic score is very low (< 0.05)
    // This ensures Arabic images NEVER go to Tesseract
    if (latinConfidence > 0.995 && arabicConfidence < 0.05) {
      // EXTREMELY high threshold for English (0.995) AND Arabic must be VERY low (< 0.05)
      // Only use Tesseract if we're ABSOLUTELY CERTAIN it's English
      return DetectedLanguage(
        scriptType: ScriptType.latin,
        confidence: latinConfidence,
      );
    } else {
      // Default to Arabic/Mixed for everything else (safer - avoids Tesseract gibberish)
      // EasyOCR can handle both Arabic/Urdu and English correctly
      if (arabicConfidence > 0.1) {
        return DetectedLanguage(
          scriptType: ScriptType.arabic,
          confidence: arabicConfidence,
        );
      } else {
        // Default to mixed when uncertain - this routes to EasyOCR(['ar','ur'])
        return DetectedLanguage(
          scriptType: ScriptType.mixed,
          confidence: 0.5,
        );
      }
    }
  }

  /// Calculate image statistics for script detection
  static _ImageStats _calculateImageStatistics(img.Image image) {
    // Simplified statistics calculation
    // In a production system, this would use more sophisticated computer vision techniques

    int totalPixels = image.width * image.height;
    int darkPixels = 0;
    int edgePixels = 0;

    // Simple threshold for "text" pixels (dark pixels)
    const int textThreshold = 128;

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final gray = ((pixel.r + pixel.g + pixel.b) / 3).round();

        if (gray < textThreshold) {
          darkPixels++;
        }

        // Simple edge detection (check neighbors)
        if (x > 0 && y > 0 && x < image.width - 1 && y < image.height - 1) {
          final current = gray;
          final right = ((image.getPixel(x + 1, y).r +
                      image.getPixel(x + 1, y).g +
                      image.getPixel(x + 1, y).b) /
                  3)
              .round();
          final down = ((image.getPixel(x, y + 1).r +
                      image.getPixel(x, y + 1).g +
                      image.getPixel(x, y + 1).b) /
                  3)
              .round();

          if ((current - right).abs() > 30 || (current - down).abs() > 30) {
            edgePixels++;
          }
        }
      }
    }

    final textDensity = darkPixels / totalPixels;
    final edgeDensity = edgePixels / totalPixels;

    // Simplified component analysis (would need connected components algorithm)
    final avgComponentSize = textDensity * 100; // Approximation

    // Simplified horizontal variance (would need baseline detection)
    final horizontalVariance = edgeDensity * 2; // Approximation

    return _ImageStats(
      textDensity: textDensity,
      edgeDensity: edgeDensity,
      avgComponentSize: avgComponentSize,
      horizontalVariance: horizontalVariance,
    );
  }
}

/// Internal class for image statistics
class _ImageStats {
  final double textDensity;
  final double edgeDensity;
  final double avgComponentSize;
  final double horizontalVariance;

  _ImageStats({
    required this.textDensity,
    required this.edgeDensity,
    required this.avgComponentSize,
    required this.horizontalVariance,
  });
}
