import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart'; // For compute()
import 'package:path_provider/path_provider.dart';
import 'package:tesseract_ocr/tesseract_ocr.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'api_service.dart';
import '../screens/crop_image_page.dart'; // For SelectedLanguage enum

/// Result class for OCR operations
class OCRResult {
  final String? text;
  final String? errorMessage;
  final bool tesseractAttempted;
  final bool easyOCRAttempted;
  final String? backendUrl;

  OCRResult({
    this.text,
    this.errorMessage,
    this.tesseractAttempted = false,
    this.easyOCRAttempted = false,
    this.backendUrl,
  });

  bool get isSuccess => text != null && text!.isNotEmpty;
}

/// Service for extracting text from images using Tesseract OCR and EasyOCR
/// Tries Tesseract first (local, fast), then falls back to EasyOCR (backend API, more accurate)
class OCRService {
  static String? _tessdataPath;
  static bool _assetsCopied = false;

  // Result cache: Maps image hash to OCR result (for repeated scans)
  static final Map<String, OCRResult> _resultCache = {};
  static const int _maxCacheSize =
      50; // Limit cache size to prevent memory issues

  /// Preprocess image for Arabic/Urdu text (optimized for cursive Arabic script)
  /// MANDATORY: grayscale ONLY + light contrast enhancement
  /// ❌ NO threshold (breaks cursive scripts and causes Latin-like gibberish)
  /// ❌ NO aggressive sharpening
  static Future<String?> _preprocessImageArabicUrdu(String imagePath) async {
    try {
      print('OCR Debug: Starting Arabic/Urdu-specific preprocessing...');

      final File originalFile = File(imagePath);
      final Uint8List imageBytes = await originalFile.readAsBytes();
      img.Image? image = img.decodeImage(imageBytes);

      if (image == null) {
        print('OCR Debug: ⚠ Failed to decode image, using original');
        return imagePath;
      }

      print('OCR Debug: Original dimensions: ${image.width}x${image.height}');

      // Step 1: Convert to grayscale ONLY
      print('OCR Debug: Converting to grayscale...');
      image = img.grayscale(image);

      // Step 2: Resize if needed (ensure minimum 300 DPI)
      const int minWidth = 1200;
      const int minHeight = 1600;

      if (image.width < minWidth || image.height < minHeight) {
        print('OCR Debug: Resizing for better OCR...');
        final double scaleX = minWidth / image.width;
        final double scaleY = minHeight / image.height;
        final double scale = scaleX > scaleY ? scaleX : scaleY;

        final int newWidth = (image.width * scale).round();
        final int newHeight = (image.height * scale).round();
        image = img.copyResize(image,
            width: newWidth,
            height: newHeight,
            interpolation: img.Interpolation.cubic);
        print('OCR Debug: Resized to ${image.width}x${image.height}');
      }

      // Step 3: Light contrast enhancement ONLY
      // ❌ NO threshold - it breaks cursive scripts
      // ❌ NO aggressive sharpening
      print('OCR Debug: Applying light contrast enhancement (1.1x)...');
      image = img.adjustColor(image, contrast: 1.1);

      // Save preprocessed image
      final Directory tempDir = await getTemporaryDirectory();
      final String preprocessedPath =
          '${tempDir.path}/preprocessed_arabic_${DateTime.now().millisecondsSinceEpoch}.png';
      final File preprocessedFile = File(preprocessedPath);

      final Uint8List preprocessedBytes =
          Uint8List.fromList(img.encodePng(image));
      await preprocessedFile.writeAsBytes(preprocessedBytes);

      print(
          'OCR Debug: ✓ Arabic/Urdu preprocessing complete (grayscale + light contrast only)');
      print(
          'OCR Debug: Preprocessed image: $preprocessedPath (${preprocessedBytes.length} bytes)');

      return preprocessedPath;
    } catch (e, stackTrace) {
      print('OCR Debug: ⚠ Arabic/Urdu preprocessing failed: $e');
      print('OCR Debug: Stack trace: $stackTrace');
      return imagePath;
    }
  }

  /// Preprocess image for English text (optimized for Latin script)
  /// Applies: grayscale, noise reduction, high contrast, adaptive thresholding, deskewing
  /// CRITICAL: Runs in isolate to prevent UI blocking
  static Future<String?> _preprocessImageEnglish(String imagePath) async {
    // Move heavy preprocessing to isolate
    return await compute(_preprocessImageEnglishInIsolate, imagePath);
  }

  /// Helper function to preprocess English image in isolate
  static Future<String?> _preprocessImageEnglishInIsolate(
      String imagePath) async {
    try {
      print('OCR Debug: Starting image preprocessing...');

      // Read original image
      final File originalFile = File(imagePath);
      final Uint8List imageBytes = await originalFile.readAsBytes();
      img.Image? image = img.decodeImage(imageBytes);

      if (image == null) {
        print('OCR Debug: ⚠ Failed to decode image, using original');
        return imagePath;
      }

      final int originalWidth = image.width;
      final int originalHeight = image.height;
      print(
          'OCR Debug: Original image dimensions: ${originalWidth}x$originalHeight');

      // Step 1: Convert to grayscale
      print('OCR Debug: Converting to grayscale...');
      image = img.grayscale(image);

      // Step 2: Resize if needed (but don't resize too aggressively - causes timeouts)
      // Maximum resize: 2x original size (prevents massive images that cause timeouts)
      const int maxWidth = 2000; // Maximum width to prevent timeouts
      const int maxHeight = 2000; // Maximum height to prevent timeouts
      const int minWidth = 800; // Minimum width for decent OCR
      const int minHeight = 600; // Minimum height for decent OCR

      bool needsResize = false;
      double scale = 1.0;

      if (image.width < minWidth || image.height < minHeight) {
        // Too small - scale up, but cap at 2x
        final double scaleX = minWidth / image.width;
        final double scaleY = minHeight / image.height;
        scale =
            (scaleX > scaleY ? scaleX : scaleY).clamp(1.0, 2.0); // Cap at 2x
        needsResize = true;
      } else if (image.width > maxWidth || image.height > maxHeight) {
        // Too large - scale down
        final double scaleX = maxWidth / image.width;
        final double scaleY = maxHeight / image.height;
        scale = scaleX < scaleY ? scaleX : scaleY;
        needsResize = true;
      }

      if (needsResize) {
        print(
            'OCR Debug: Resizing image (scale: ${scale.toStringAsFixed(2)}x)...');
        final int newWidth = (image.width * scale).round();
        final int newHeight = (image.height * scale).round();
        image = img.copyResize(image,
            width: newWidth,
            height: newHeight,
            interpolation: img.Interpolation.cubic);
        print('OCR Debug: Resized to ${image.width}x${image.height}');
      } else {
        print(
            'OCR Debug: Image size OK (${image.width}x${image.height}), no resizing needed');
      }

      // Step 3: Apply Gaussian blur for noise reduction (light blur)
      print('OCR Debug: Applying noise reduction...');
      image = img.gaussianBlur(image, radius: 1);

      // Step 4: Enhance contrast
      print('OCR Debug: Enhancing contrast...');
      image = img.adjustColor(image, contrast: 1.2);

      // Step 5: Apply thresholding (binarization) for better text recognition
      print('OCR Debug: Applying thresholding (binarization)...');
      // Use a simple threshold - convert to pure black and white
      // Since image is already grayscale, we can work with a single channel
      final int threshold = 128; // Midpoint threshold
      for (int y = 0; y < image.height; y++) {
        for (int x = 0; x < image.width; x++) {
          final img.Pixel pixel = image.getPixel(x, y);
          // Get red channel value (for grayscale, all channels are same)
          final num rValue = pixel.r;
          final int r = rValue.round();
          // For grayscale, R=G=B, so we can use any channel
          final int newValue = r > threshold ? 255 : 0;
          // Set pixel using the image package API
          pixel
            ..r = newValue
            ..g = newValue
            ..b = newValue;
        }
      }

      // Save preprocessed image to temp location
      final Directory tempDir = await getTemporaryDirectory();
      final String preprocessedPath =
          '${tempDir.path}/preprocessed_ocr_${DateTime.now().millisecondsSinceEpoch}.png';
      final File preprocessedFile = File(preprocessedPath);

      final Uint8List preprocessedBytes =
          Uint8List.fromList(img.encodePng(image));
      await preprocessedFile.writeAsBytes(preprocessedBytes);

      print('OCR Debug: ✓ Image preprocessing complete');
      print('OCR Debug: Preprocessed image saved to: $preprocessedPath');
      print(
          'OCR Debug: Preprocessed image size: ${preprocessedBytes.length} bytes');
      print('OCR Debug: Final dimensions: ${image.width}x${image.height}');

      return preprocessedPath;
    } catch (e, stackTrace) {
      print('OCR Debug: ⚠ Image preprocessing failed: $e');
      print('OCR Debug: Stack trace: $stackTrace');
      print('OCR Debug: Using original image without preprocessing');
      return imagePath; // Return original if preprocessing fails
    }
  }

  /// Initialize Tesseract by copying language files from assets to device storage
  static Future<String?> _initializeTesseract() async {
    if (_tessdataPath != null && _assetsCopied) {
      print(
          'OCR Debug: Tesseract already initialized, using existing path: $_tessdataPath');
      // Verify files still exist
      final dir = Directory(_tessdataPath!);
      if (await dir.exists()) {
        final files = await dir.list().toList();
        print('OCR Debug: Verified ${files.length} language files in tessdata');
      }
      return _tessdataPath;
    }

    try {
      print('OCR Debug: ========================================');
      print('OCR Debug: Initializing Tesseract language files...');

      // Get device documents directory
      final Directory appDocDir = await getApplicationDocumentsDirectory();
      final String tessdataDir = '${appDocDir.path}/tessdata';
      final Directory tessdataDirectory = Directory(tessdataDir);

      print('OCR Debug: Target tessdata directory: $tessdataDir');

      // Create tessdata directory if it doesn't exist
      if (!await tessdataDirectory.exists()) {
        await tessdataDirectory.create(recursive: true);
        print('OCR Debug: ✓ Created tessdata directory');
      } else {
        print('OCR Debug: ✓ Tessdata directory already exists');

        // CRITICAL FIX: Remove Arabic/Urdu language files if they exist
        // These cause confusion - Tesseract should ONLY use English
        final unwantedFiles = ['ara.traineddata', 'urd.traineddata'];
        for (String fileName in unwantedFiles) {
          final String unwantedPath = '$tessdataDir/$fileName';
          final File unwantedFile = File(unwantedPath);
          if (await unwantedFile.exists()) {
            try {
              await unwantedFile.delete();
              print(
                  'OCR Debug: ✓ Removed $fileName (causes Tesseract confusion)');
            } catch (e) {
              print('OCR Debug: ⚠ Failed to remove $fileName: $e');
            }
          }
        }
      }

      // CRITICAL FIX: Copy config file first (required by tesseract_ocr package)
      // The package expects tessdata_config.json to exist in assets
      // We also copy it to tessdata directory as a fallback
      final String configFileName = 'tessdata_config.json';
      // FIX: Asset is at root of assets, not in tessdata subfolder
      final String configAssetPath = 'assets/$configFileName';
      final String configTargetPath = '$tessdataDir/$configFileName';
      final File configTargetFile = File(configTargetPath);

      if (!await configTargetFile.exists()) {
        print(
            'OCR Debug: Copying $configFileName from assets path: $configAssetPath...');
        bool copied = false;
        try {
          // Try to copy from assets first
          final ByteData configData = await rootBundle.load(configAssetPath);
          final Uint8List configBytes = configData.buffer.asUint8List();
          await configTargetFile.writeAsBytes(configBytes);
          print(
              'OCR Debug: ✓ Copied $configFileName from assets (${configBytes.length} bytes)');
          copied = true;
        } catch (e) {
          print(
              'OCR Debug: ⚠ Could not load $configFileName from $configAssetPath: $e');
          print(
              'OCR Debug: Trying fallback asset path: assets/tessdata/$configFileName...');
          try {
            final ByteData fallbackData =
                await rootBundle.load('assets/tessdata/$configFileName');
            final Uint8List fallbackBytes = fallbackData.buffer.asUint8List();
            await configTargetFile.writeAsBytes(fallbackBytes);
            print(
                'OCR Debug: ✓ Copied $configFileName from fallback assets path (${fallbackBytes.length} bytes)');
            copied = true;
          } catch (e2) {
            print('OCR Debug: ⚠ Fallback asset path also failed: $e2');
            print(
                'OCR Debug: Creating $configFileName programmatically as fallback...');
            // Fallback: Create config file programmatically
            try {
              final configContent = '{\n  "languages": ["eng"]\n}\n';
              await configTargetFile.writeAsString(configContent);
              print(
                  'OCR Debug: ✓ Created $configFileName programmatically (${configContent.length} bytes)');
              copied = true;
            } catch (createError) {
              print(
                  'OCR Debug: ❌ Failed to create $configFileName: $createError');
            }
          }
        }
        if (!copied) {
          print(
              'OCR Debug: ⚠ Config file not available - Tesseract package may fail to initialize');
        }
      } else {
        print('OCR Debug: ✓ $configFileName already exists');
      }

      // CRITICAL FIX: Only copy English language file
      // We ONLY use Tesseract for English (confidence >= 0.8)
      // Arabic/Urdu goes to EasyOCR - having ara/urd files causes Tesseract confusion
      // List of language files to copy
      final List<String> languageFiles = [
        'eng.traineddata', // English only - Arabic/Urdu handled by EasyOCR
        // 'ara.traineddata',  // REMOVED: Causes confusion, use EasyOCR instead
        // 'urd.traineddata',  // REMOVED: Causes confusion, use EasyOCR instead
      ];

      int copiedCount = 0;
      int existingCount = 0;
      int failedCount = 0;
      final List<String> availableFiles = [];

      // Copy each language file from assets to device storage
      for (String fileName in languageFiles) {
        final String assetPath = 'assets/tessdata/$fileName';
        final String targetPath = '$tessdataDir/$fileName';
        final File targetFile = File(targetPath);

        // Check if file already exists
        if (await targetFile.exists()) {
          final int fileSize = await targetFile.length();
          print('OCR Debug: ✓ $fileName already exists ($fileSize bytes)');
          existingCount++;
          availableFiles.add(fileName);
        } else {
          // Copy from assets
          print('OCR Debug: Copying $fileName from assets...');
          try {
            final ByteData data = await rootBundle.load(assetPath);
            final Uint8List bytes = data.buffer.asUint8List();
            await targetFile.writeAsBytes(bytes);
            print('OCR Debug: ✓ Copied $fileName (${bytes.length} bytes)');
            copiedCount++;
            availableFiles.add(fileName);
          } catch (e) {
            print('OCR Debug: ❌ Failed to copy $fileName: $e');
            failedCount++;
          }
        }
      }

      // Verify all files are accessible
      print('OCR Debug: Verifying language files...');
      for (String fileName in languageFiles) {
        final String targetPath = '$tessdataDir/$fileName';
        final File targetFile = File(targetPath);
        if (await targetFile.exists()) {
          final int fileSize = await targetFile.length();
          if (fileSize > 0) {
            print('OCR Debug: ✓ Verified $fileName ($fileSize bytes)');
          } else {
            print('OCR Debug: ⚠ $fileName exists but is empty (0 bytes)');
          }
        } else {
          print('OCR Debug: ❌ $fileName not found in tessdata directory');
        }
      }

      _tessdataPath = tessdataDir;
      _assetsCopied = true;

      print('OCR Debug: ========================================');
      print('OCR Debug: Tesseract initialization summary:');
      print('OCR Debug:   - Copied: $copiedCount files');
      print('OCR Debug:   - Existing: $existingCount files');
      print('OCR Debug:   - Failed: $failedCount files');
      print('OCR Debug:   - Available: ${availableFiles.length} files');
      print('OCR Debug:   - Tessdata path: $_tessdataPath');
      print('OCR Debug: ========================================');

      if (availableFiles.isEmpty) {
        print('OCR Debug: ⚠ WARNING: No language files available!');
        return null;
      }

      return _tessdataPath;
    } catch (e, stackTrace) {
      print('OCR Debug: ❌ Failed to initialize Tesseract: $e');
      print('OCR Debug: Stack trace: $stackTrace');
      return null;
    }
  }

  /// Extract text from an image file using Tesseract OCR
  /// Returns the extracted text or null if extraction fails
  static Future<String?> extractTextFromImage(
    String imagePath, {
    SelectedLanguage? selectedLanguage,
  }) async {
    final result = await extractTextFromImageWithDetails(imagePath,
        selectedLanguage: selectedLanguage);
    return result.text;
  }

  /// Extract text from an image file with detailed error information
  /// Returns OCRResult with text and error details
  /// STEP 3: Simple routing based on user selection (NO detection, NO fallbacks)
  static Future<OCRResult> extractTextFromImageWithDetails(
    String imagePath, {
    SelectedLanguage? selectedLanguage,
  }) async {
    // CRITICAL: Wrap entire function in try-catch to prevent crashes
    try {
      final file = File(imagePath);
      if (!await file.exists()) {
        throw Exception('Image file not found: $imagePath');
      }

      // CRITICAL: Check file size BEFORE reading to prevent memory issues
      final fileSize = await file.length();
      print('OCR Debug: ========================================');
      print('OCR Debug: OCR Request Started');
      print('OCR Debug: ========================================');
      print('OCR Debug: Image file path: $imagePath');
      print('OCR Debug: Image file exists: ${await file.exists()}');
      print('OCR Debug: Image file size: $fileSize bytes');

      if (fileSize == 0) {
        throw Exception('Image file is empty (0 bytes)');
      }

      // CRITICAL: Limit image size to prevent memory crashes (max 20MB)
      const maxFileSize = 20 * 1024 * 1024; // 20MB
      if (fileSize > maxFileSize) {
        throw Exception(
            'Image file too large (${(fileSize / 1024 / 1024).toStringAsFixed(1)}MB). Maximum size is 20MB. Please use a smaller image.');
      }

      // OPTIMIZATION: Check cache first (for repeated scans)
      // Read image bytes only after size check
      // CRITICAL: For large files, read in isolate to prevent UI blocking
      final Uint8List imageBytes;
      if (fileSize > 5 * 1024 * 1024) {
        // Large file (>5MB) - read in isolate to prevent UI blocking
        print(
            'OCR Debug: Large file detected (${(fileSize / 1024 / 1024).toStringAsFixed(1)}MB), reading in isolate...');
        imageBytes = await compute(_readFileInIsolate, imagePath);
      } else {
        // Small file - read normally (already async)
        imageBytes = await file.readAsBytes();
      }
      final imageHash = sha256.convert(imageBytes).toString();
      print('OCR Debug: Image hash: $imageHash');

      if (_resultCache.containsKey(imageHash)) {
        print('OCR Debug: ✓ Using cached result (instant response)');
        return _resultCache[imageHash]!;
      }

      // CRITICAL: Move image decoding to background isolate to prevent UI blocking
      // Try to read image properties for diagnostics (with memory safety)
      try {
        final decodedImage =
            await compute(_decodeImageForDiagnostics, imageBytes);
        if (decodedImage != null) {
          print('OCR Debug: Image properties:');
          print(
              'OCR Debug:   - Dimensions: ${decodedImage['width']}x${decodedImage['height']}');
          print('OCR Debug:   - Format: ${decodedImage['format']}');
          print('OCR Debug:   - Has alpha: ${decodedImage['hasAlpha']}');
          // Calculate approximate DPI (assuming typical phone camera)
          final double estimatedDpi =
              (decodedImage['width'] / 4.0).roundToDouble(); // Rough estimate
          print(
              'OCR Debug:   - Estimated DPI: ~$estimatedDpi (for OCR, 300+ DPI is optimal)');

          // CRITICAL: Check image dimensions to prevent memory issues
          const maxDimension = 8000; // Max width or height
          if (decodedImage['width'] > maxDimension ||
              decodedImage['height'] > maxDimension) {
            throw Exception(
                'Image dimensions too large (${decodedImage['width']}x${decodedImage['height']}). Maximum dimension is $maxDimension pixels. Please resize the image.');
          }
        }
      } catch (e) {
        // If it's our custom exception, rethrow it
        if (e.toString().contains('dimensions too large') ||
            e.toString().contains('too large')) {
          rethrow;
        }
        print('OCR Debug: ⚠ Could not decode image for diagnostics: $e');
      }

      // Get base URL for error reporting
      String baseUrl = ApiService.baseUrl;
      if (baseUrl.endsWith('/api')) {
        baseUrl = baseUrl.substring(0, baseUrl.length - 4);
      }

      // STEP 3: SIMPLE ROUTING (NO detection, NO fallbacks)
      print('OCR Debug: ========================================');
      print('OCR Debug: SIMPLE OCR ROUTING - Starting...');
      print('OCR Debug: User selected language: $selectedLanguage');
      print('OCR Debug: ========================================');

      String? extractedText;
      bool tesseractAttempted = false;
      bool easyOCRAttempted = false;
      String? errorMessage;

      // Simple routing: if English → Tesseract ONLY (no fallback), else → EasyOCR(['ur', 'ar'])
      if (selectedLanguage == SelectedLanguage.english) {
        // ENGLISH: Tesseract ONLY (no EasyOCR fallback)
        print(
            'OCR Debug: English selected → Using Tesseract ONLY (no fallback)');
        try {
          print('OCR Debug: Calling _extractWithTesseract()...');
          extractedText = await _extractWithTesseract(imagePath, 'eng').timeout(
            const Duration(seconds: 35),
            onTimeout: () {
              print(
                  'OCR Debug: ⚠ Tesseract processing timeout after 35 seconds');
              return null;
            },
          );
          tesseractAttempted = true;
          print(
              'OCR Debug: _extractWithTesseract() returned: ${extractedText != null ? "text (${extractedText.length} chars)" : "null"}');

          final tesseractText = extractedText?.trim() ?? '';
          print(
              'OCR Debug: Tesseract text after trim: length=${tesseractText.length}, isEmpty=${tesseractText.isEmpty}');

          if (tesseractText.isEmpty) {
            errorMessage =
                'Tesseract OCR failed to extract text. Please check image quality and ensure Tesseract is properly installed.';
            print('OCR Debug: ❌ Tesseract returned empty text');
            print(
                'OCR Debug: Check console logs above for detailed diagnostics');
          } else {
            extractedText = tesseractText;
            errorMessage = null;
            print(
                'OCR Debug: ✓ Tesseract extracted English text successfully (${tesseractText.length} characters)');
          }
        } catch (e, stackTrace) {
          print('OCR Debug: ❌ Tesseract exception caught: $e');
          print('OCR Debug: Exception type: ${e.runtimeType}');
          print('OCR Debug: Stack trace: $stackTrace');
          tesseractAttempted = true;
          errorMessage =
              'Tesseract OCR failed: ${e.toString()}. Please check image quality and ensure Tesseract is properly installed.';
          extractedText = null;
        }
      } else {
        // ARABIC/URDU: Use ONLY the selected language (no mixing!)
        List<String> languages;
        if (selectedLanguage == SelectedLanguage.urdu) {
          languages = ['ur']; // Urdu ONLY - no Arabic mixing
          print('OCR Debug: Urdu selected → Using EasyOCR([\'ur\']) ONLY');
        } else if (selectedLanguage == SelectedLanguage.arabic) {
          languages = ['ar']; // Arabic ONLY - no Urdu mixing
          print('OCR Debug: Arabic selected → Using EasyOCR([\'ar\']) ONLY');
        } else {
          // Fallback (shouldn't happen, but default to Urdu)
          languages = ['ur'];
          print(
              'OCR Debug: Unknown language, defaulting to Urdu → Using EasyOCR([\'ur\'])');
        }
        print(
            'OCR Debug: Using EasyOCR with languages: $languages (NO mixing)');

        try {
          final easyOCRResult = await _extractWithEasyOCRWithDetails(imagePath,
                  languages: languages)
              .timeout(
            const Duration(seconds: 60),
            onTimeout: () {
              return {'text': null, 'error': 'EasyOCR timeout'};
            },
          );
          easyOCRAttempted = true;
          final resultText = easyOCRResult['text']?.trim() ?? '';

          if (resultText.isNotEmpty) {
            extractedText = resultText;
            errorMessage = null;
            print(
                'OCR Debug: ✓ EasyOCR Arabic/Urdu extracted text successfully');
          } else {
            errorMessage = easyOCRResult['error'] ??
                'EasyOCR failed to extract text. Please check image quality.';
            print('OCR Debug: ❌ EasyOCR returned empty text');
          }
        } catch (e, stackTrace) {
          print('OCR Debug: ❌ EasyOCR crashed or timed out: $e');
          print('OCR Debug: Stack trace: $stackTrace');
          errorMessage =
              'OCR processing failed. Please try again or check backend connection.';
          easyOCRAttempted = true;
          extractedText = null;
        }
      }

      // Clean up the text (remove extra newlines and trim)
      if (extractedText != null) {
        extractedText = extractedText.trim();
      }

      // Debug: Print extracted text details
      print(
          'OCR Debug: Final extracted text length: ${extractedText?.length ?? 0}');
      if (extractedText != null && extractedText.isNotEmpty) {
        final preview = extractedText.length > 100
            ? extractedText.substring(0, 100)
            : extractedText;
        print('OCR Debug: Extracted text preview: $preview');
        print('✅ OCR SUCCESS: Text extracted successfully');
      } else {
        print('❌ OCR FAILED: No text extracted from image');
      }

      // Build error message if no text was extracted
      if (extractedText == null || extractedText.isEmpty) {
        if (errorMessage == null) {
          errorMessage = 'No text detected in image. ';
          if (!easyOCRAttempted) {
            errorMessage += 'Tesseract OCR found no text. ';
          }
          errorMessage +=
              'Possible causes: Image has no readable text, poor image quality, or backend connection issues.';
        }
      }

      final result = OCRResult(
        text: extractedText?.isEmpty == true ? null : extractedText,
        errorMessage: errorMessage,
        tesseractAttempted: tesseractAttempted,
        easyOCRAttempted: easyOCRAttempted,
        backendUrl: baseUrl,
      );

      // OPTIMIZATION: Cache successful results
      if (result.isSuccess &&
          extractedText != null &&
          extractedText.isNotEmpty) {
        // Limit cache size
        if (_resultCache.length >= _maxCacheSize) {
          // Remove oldest entry (simple FIFO)
          final firstKey = _resultCache.keys.first;
          _resultCache.remove(firstKey);
        }
        _resultCache[imageHash] = result;
        print('OCR Debug: ✓ Result cached for future use');
      }

      return result;
    } catch (e, stackTrace) {
      // CRITICAL: Catch ALL exceptions to prevent app crashes
      print(
          'OCR Debug: ❌ CRITICAL ERROR in extractTextFromImageWithDetails: ${e.toString()}');
      print('OCR Debug: Error type: ${e.runtimeType}');
      print('OCR Debug: Stack trace: $stackTrace');

      // Return safe error result instead of throwing (prevents crashes)
      return OCRResult(
        text: null,
        errorMessage:
            'OCR processing failed: ${e.toString()}\n\nPlease try:\n• Use a smaller image (< 20MB)\n• Ensure image is clear and readable\n• Check your internet connection',
        tesseractAttempted: false,
        easyOCRAttempted: false,
      );
    } finally {
      // CRITICAL: Force garbage collection hint to free memory
      // This helps prevent memory-related crashes
      print('OCR Debug: Processing completed, memory cleanup suggested');
    }
  }

  /// Extract text using Tesseract OCR (local processing)
  static Future<String?> _extractWithTesseract(
      String imagePath, String language) async {
    String? preprocessedPath;
    try {
      print('OCR Debug: ========================================');
      print('OCR Debug: ========================================');
      print('OCR Debug: _extractWithTesseract() ENTRY POINT');
      print('OCR Debug: ========================================');
      print('OCR Debug: ========================================');
      print('OCR Debug: Starting Tesseract OCR...');
      print('OCR Debug: Language: $language');
      print('OCR Debug: Original image path: $imagePath');
      print('OCR Debug: Current time: ${DateTime.now().toIso8601String()}');

      // Validate original image
      final File originalFile = File(imagePath);
      if (!await originalFile.exists()) {
        print('OCR Debug: ❌ Original image file does not exist');
        return null;
      }

      final int originalSize = await originalFile.length();
      print('OCR Debug: Original image size: $originalSize bytes');

      // STEP 1: PREPROCESSING (MANDATORY for good Tesseract results)
      print('OCR Debug: Preprocessing image for English Tesseract...');
      preprocessedPath = await _preprocessImageEnglish(imagePath);
      if (preprocessedPath == null) {
        print('OCR Debug: ⚠ Preprocessing failed, using original image');
        preprocessedPath = imagePath;
      } else {
        print('OCR Debug: ✓ Image preprocessed for English OCR');
      }

      // STEP 2: WINDOWS FALLBACK (Critical for win32 systems)
      // Check if running on Windows and tesseract command is available
      if (Platform.isWindows) {
        print('OCR Debug: Windows detected, trying Tesseract system binary...');
        try {
          // Note: tesseract binary expects input_file output_base [options...]
          // We use 'stdout' to get text directly to the console
          final result = await Process.run(
            'tesseract',
            [preprocessedPath, 'stdout', '-l', 'eng', '--psm', '6'],
          ).timeout(const Duration(seconds: 20));

          if (result.exitCode == 0) {
            final text = result.stdout as String;
            if (text.trim().isNotEmpty) {
              print('OCR Debug: ✓ Windows system binary Tesseract successful');
              // Clean up preprocessed file if we created one
              if (preprocessedPath != imagePath) {
                try {
                  await File(preprocessedPath).delete();
                } catch (e) {}
              }
              return text;
            } else {
              print(
                  'OCR Debug: ⚠ Windows Tesseract binary returned empty text');
            }
          } else {
            print(
                'OCR Debug: ❌ Windows Tesseract binary failed (exit code: ${result.exitCode})');
            print('OCR Debug: Error output: ${result.stderr}');
          }
        } catch (e) {
          print('OCR Debug: ⚠ Windows Tesseract binary check failed: $e');
          print(
              'OCR Debug: Falling back to mobile plugin (which may fail on Windows)');
        }
      }

      // STEP 3: MOBILE PLUGIN (Android/iOS)
      // Initialize Tesseract (copy language files from assets if needed)
      // CRITICAL: Add timeout to prevent app freezing during initialization
      print('OCR Debug: Initializing Tesseract language files for plugin...');
      String? tessdataPath;
      try {
        tessdataPath = await _initializeTesseract().timeout(
          const Duration(seconds: 15),
          onTimeout: () {
            print(
                'OCR Debug: ⚠ Tesseract initialization timeout after 15 seconds');
            return null;
          },
        );
      } catch (e) {
        print('OCR Debug: ⚠ Tesseract initialization error: $e');
        tessdataPath = null;
      }

      if (tessdataPath == null) {
        print(
            'OCR Debug: ⚠ Tesseract initialization failed, language files may not be available');
      } else {
        print('OCR Debug: ✓ Using tessdata path: $tessdataPath');
      }

      // CRITICAL FIX: Pre-verify asset can be loaded before calling package
      // The tesseract_ocr package tries to load tessdata_config.json from assets at ROOT
      // Package expects: assets/tessdata_config.json (NOT assets/tessdata/tessdata_config.json)
      print('OCR Debug: Pre-verifying tessdata_config.json asset at ROOT...');
      bool assetAvailable = false;
      try {
        // CRITICAL: Package expects file at ROOT of assets, not in subfolder
        final ByteData assetTest =
            await rootBundle.load('assets/tessdata_config.json');
        print(
            'OCR Debug: ✓ Asset tessdata_config.json is accessible at ROOT (${assetTest.lengthInBytes} bytes)');
        assetAvailable = true;
      } catch (rootError) {
        print(
            'OCR Debug: ⚠ Asset tessdata_config.json NOT found at ROOT: $rootError');
        // Try subfolder as fallback (for our code, not package)
        try {
          final ByteData assetTest2 =
              await rootBundle.load('assets/tessdata/tessdata_config.json');
          print(
              'OCR Debug: ⚠ Asset found in subfolder (${assetTest2.lengthInBytes} bytes) but package needs it at ROOT');
          print(
              'OCR Debug: ⚠ WARNING: Package will likely fail - it expects assets/tessdata_config.json');
          assetAvailable =
              false; // Still false because package needs it at root
        } catch (subfolderError) {
          print(
              'OCR Debug: ❌ Asset not found in subfolder either: $subfolderError');
          print('OCR Debug: This will cause Tesseract package to fail');
          assetAvailable = false;
        }
      }

      // Extract text using Tesseract with timeout protection (30 seconds max)
      print('OCR Debug: Running Tesseract OCR on original image...');
      print('OCR Debug: Image path: $preprocessedPath');
      print('OCR Debug: Language: eng (English)');
      print(
          'OCR Debug: Tesseract should use: -l eng --psm 6 (configured by package)');
      // Note: tesseract_ocr 0.4.1 only accepts imagePath parameter
      // The package should automatically find tessdata in the default location
      // CRITICAL: Add timeout to prevent app freezing
      String extractedText;
      try {
        // Verify file exists before calling Tesseract
        final File imageFile = File(preprocessedPath);
        if (!await imageFile.exists()) {
          print('OCR Debug: ❌ Image file does not exist: $preprocessedPath');
          return null;
        }

        final int fileSize = await imageFile.length();
        print('OCR Debug: Image file size: $fileSize bytes');
        if (fileSize == 0) {
          print('OCR Debug: ❌ Image file is empty (0 bytes)');
          return null;
        }

        print('OCR Debug: ========================================');
        print('OCR Debug: About to call TesseractOcr.extractText()');
        print('OCR Debug: Image path: $preprocessedPath');
        print('OCR Debug: File exists: ${await imageFile.exists()}');
        print('OCR Debug: File size: $fileSize bytes');
        print('OCR Debug: Asset available: $assetAvailable');

        // CRITICAL: Test both asset paths right before calling package
        print('OCR Debug: Final asset verification before Tesseract call...');
        try {
          final rootTest = await rootBundle.load('assets/tessdata_config.json');
          print(
              'OCR Debug: ✓ ROOT asset verified: ${rootTest.lengthInBytes} bytes');
        } catch (e) {
          print('OCR Debug: ❌ ROOT asset FAILED: $e');
        }
        try {
          final subTest =
              await rootBundle.load('assets/tessdata/tessdata_config.json');
          print(
              'OCR Debug: ✓ Subfolder asset verified: ${subTest.lengthInBytes} bytes');
        } catch (e) {
          print('OCR Debug: ⚠ Subfolder asset: $e (not critical for package)');
        }
        print('OCR Debug: ========================================');

        final DateTime tesseractStart = DateTime.now();
        print(
            'OCR Debug: [${tesseractStart.toIso8601String()}] Starting TesseractOcr.extractText()...');

        try {
          extractedText =
              await TesseractOcr.extractText(preprocessedPath).timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              final elapsed =
                  DateTime.now().difference(tesseractStart).inSeconds;
              print(
                  'OCR Debug: [${DateTime.now().toIso8601String()}] ⚠ TIMEOUT after $elapsed seconds');
              return ''; // Return empty string on timeout
            },
          );

          final elapsed = DateTime.now().difference(tesseractStart).inSeconds;
          print(
              'OCR Debug: [${DateTime.now().toIso8601String()}] ✓ Tesseract call completed in $elapsed seconds');
        } catch (tesseractError, tesseractStackTrace) {
          final elapsed = DateTime.now().difference(tesseractStart).inSeconds;
          print(
              'OCR Debug: [${DateTime.now().toIso8601String()}] ❌ EXCEPTION after $elapsed seconds');
          print('OCR Debug: Exception: $tesseractError');
          print('OCR Debug: Exception type: ${tesseractError.runtimeType}');
          print('OCR Debug: Stack trace: $tesseractStackTrace');

          // Check if this is the asset loading error
          final errorString = tesseractError.toString();
          if (errorString.contains('tessdata_config.json') ||
              errorString.contains('Unable to load asset') ||
              errorString.contains('asset does not exist')) {
            print('OCR Debug: ========================================');
            print('OCR Debug: ⚠ TESSERACT CONFIG FILE ERROR DETECTED');
            print(
                'OCR Debug: The tesseract_ocr package cannot find tessdata_config.json');
            print('OCR Debug: This usually means:');
            print(
                'OCR Debug:   1. Asset not properly bundled (run: flutter clean && flutter pub get)');
            print('OCR Debug:   2. File not in assets/tessdata/ folder');
            print('OCR Debug:   3. pubspec.yaml missing asset declaration');
            print('OCR Debug: ========================================');
            // Don't rethrow - return empty text so caller can handle gracefully
            extractedText = '';
          } else {
            extractedText = '';
            rethrow; // Re-throw other errors to be caught by outer catch
          }
        }

        print('OCR Debug: ========================================');
        print('OCR Debug: Tesseract result analysis:');
        print('OCR Debug:   - Raw text length: ${extractedText.length}');
        print('OCR Debug:   - Trimmed length: ${extractedText.trim().length}');
        print('OCR Debug:   - Is empty: ${extractedText.isEmpty}');
        print(
            'OCR Debug:   - Trimmed is empty: ${extractedText.trim().isEmpty}');

        if (extractedText.isNotEmpty) {
          final preview = extractedText.length > 100
              ? extractedText.substring(0, 100)
              : extractedText;
          print('OCR Debug:   - First 100 chars: $preview');
        } else {
          print('OCR Debug:   - ⚠ Text is EMPTY');
        }
        print('OCR Debug: ========================================');
      } catch (e, stackTrace) {
        print('OCR Debug: ❌ Tesseract OCR error: $e');
        print('OCR Debug: Error type: ${e.runtimeType}');
        print('OCR Debug: Stack trace: $stackTrace');
        extractedText = ''; // Return empty string on error
      }

      print(
          'OCR Debug: Tesseract extracted text length: ${extractedText.length}');

      if (extractedText.trim().isEmpty) {
        print('OCR Debug: ⚠ Tesseract returned empty text');
        print('OCR Debug: Possible reasons:');
        print('   1. Language files not found or not loaded');
        print('   2. Image quality too poor');
        print('   3. Text not clearly visible in image');
        print('   4. Wrong language for the text in image');
        print('   5. Tesseract not properly installed on system');
        if (tessdataPath != null) {
          print('   Tessdata path: $tessdataPath');
          // Check if files exist
          final dir = Directory(tessdataPath);
          if (await dir.exists()) {
            final files = await dir.list().toList();
            print(
                '   Files in tessdata: ${files.map((f) => f.path.split(Platform.pathSeparator).last).join(", ")}');
            // Check specifically for eng.traineddata
            final engFile = File('$tessdataPath/eng.traineddata');
            if (await engFile.exists()) {
              final engSize = await engFile.length();
              print('   ✓ eng.traineddata exists ($engSize bytes)');
            } else {
              print('   ❌ eng.traineddata NOT FOUND!');
            }
          } else {
            print('   ❌ Tessdata directory does not exist!');
          }
        } else {
          print('   ❌ Tessdata path is null - initialization failed!');
        }

        // CRITICAL: Try using original image without preprocessing as fallback
        if (preprocessedPath != imagePath) {
          print(
              'OCR Debug: Trying original image without preprocessing as fallback...');
          try {
            final fallbackText =
                await TesseractOcr.extractText(imagePath).timeout(
              const Duration(seconds: 30),
              onTimeout: () {
                print('OCR Debug: ⚠ Tesseract fallback timeout');
                return '';
              },
            );
            if (fallbackText.trim().isNotEmpty) {
              print('OCR Debug: ✓ Fallback succeeded with original image');
              return fallbackText;
            }
          } catch (e) {
            print('OCR Debug: ⚠ Fallback also failed: $e');
          }
        }

        return null;
      }

      // Show preview of extracted text
      final preview = extractedText.length > 50
          ? extractedText.substring(0, 50)
          : extractedText;
      print('OCR Debug: Tesseract text preview: $preview...');

      return extractedText;
    } catch (e, stackTrace) {
      print('OCR Debug: ❌ Tesseract OCR error: ${e.toString()}');
      print('OCR Debug: Tesseract stack trace: $stackTrace');
      print(
          'OCR Debug: This might indicate missing language files or image processing issues');
      return null;
    } finally {
      // Clean up preprocessed image if it was created
      if (preprocessedPath != null && preprocessedPath != imagePath) {
        try {
          final File preprocessedFile = File(preprocessedPath);
          if (await preprocessedFile.exists()) {
            await preprocessedFile.delete();
            print('OCR Debug: Cleaned up preprocessed image');
          }
        } catch (e) {
          print('OCR Debug: ⚠ Failed to clean up preprocessed image: $e');
        }
      }
      print('OCR Debug: ========================================');
    }
  }

  /// Extract text using EasyOCR via backend API (more accurate for complex images)
  /// Returns a map with 'text' and 'error' keys
  /// [languages] - List of language codes: ['en'], ['ar'], ['ur'], or ['en', 'ar', 'ur']
  static Future<Map<String, String?>> _extractWithEasyOCRWithDetails(
    String imagePath, {
    List<String> languages = const ['en', 'ar', 'ur'],
  }) async {
    // Get base URL from ApiService (remove /api suffix if present)
    String baseUrl = ApiService.baseUrl;
    if (baseUrl.endsWith('/api')) {
      baseUrl = baseUrl.substring(0, baseUrl.length - 4);
    }

    try {
      print('🔍 OCR Debug: Starting EasyOCR via backend API...');
      print('🌐 OCR Debug: Backend URL: $baseUrl');
      print('🌐 OCR Debug: Full endpoint: $baseUrl/api/ocr/easyocr');

      // Read and optimize image before sending to backend
      // CRITICAL: Move to isolate to prevent UI blocking
      final file = File(imagePath);
      final Uint8List imageBytes = await file.readAsBytes();
      print('📷 OCR Debug: Original image bytes: ${imageBytes.length} bytes');

      // OPTIMIZATION: Compress/resize image before sending to reduce transfer time
      // CRITICAL: Run in isolate to prevent loader from freezing
      final optimizedBytes = await compute(
          _optimizeImageInIsolate, {'bytes': imageBytes, 'path': imagePath});
      final optimizedSize = optimizedBytes.length;
      final compressionRatio =
          ((imageBytes.length - optimizedSize) / imageBytes.length * 100)
              .toStringAsFixed(1);
      print(
          '📷 OCR Debug: Optimized image bytes: $optimizedSize bytes ($compressionRatio% reduction)');

      // Convert to base64 for API
      final base64Image = base64Encode(optimizedBytes);
      print(
          '📦 OCR Debug: Base64 image length: ${base64Image.length} characters');

      // Detect image format from file extension
      String imageFormat = 'jpg';
      final extension = imagePath.toLowerCase().split('.').last;
      if (extension == 'png') {
        imageFormat = 'png';
      } else if (extension == 'jpeg' || extension == 'jpg') {
        imageFormat = 'jpg';
      }

      // Call EasyOCR endpoint with timeout protection
      print('OCR Debug: Calling EasyOCR endpoint with 60s timeout...');
      http.Response response;
      try {
        response = await http
            .post(
          Uri.parse('$baseUrl/api/ocr/easyocr'),
          headers: {
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'image': base64Image,
            'image_format': imageFormat,
            'languages': languages, // Send language preference to backend
          }),
        )
            .timeout(
          const Duration(
              seconds: 60), // Reduced timeout to prevent app freezing
          onTimeout: () {
            print('OCR Debug: ⚠ EasyOCR API timeout after 60 seconds');
            // Return timeout response instead of throwing
            return http.Response(
              jsonEncode({
                'success': false,
                'text': null,
                'message':
                    'Request timeout - backend may be processing. Please try again.',
              }),
              408, // Request Timeout status code
            );
          },
        );
      } catch (e) {
        // Catch any other exceptions to prevent app crash
        print('OCR Debug: ⚠ Exception during HTTP request: $e');
        return {
          'text': null,
          'error':
              'Network error: ${e.toString().length > 100 ? e.toString().substring(0, 100) : e.toString()}',
        };
      }

      print('OCR Debug: EasyOCR response status: ${response.statusCode}');
      print('OCR Debug: EasyOCR response body: ${response.body}');

      // Handle timeout response (408)
      if (response.statusCode == 408) {
        print('OCR Debug: ⚠ Request timeout');
        return {
          'text': null,
          'error':
              'OCR request timed out. The backend may be processing. Please wait a moment and try again.',
        };
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final success = data['success'] as bool? ?? false;
        final extractedText = data['text'] as String?;
        final message = data['message'] as String?;

        print('OCR Debug: EasyOCR success: $success');
        print('OCR Debug: EasyOCR message: $message');
        print(
            'OCR Debug: EasyOCR extracted text length: ${extractedText?.length ?? 0}');

        if (success &&
            extractedText != null &&
            extractedText.trim().isNotEmpty) {
          print('OCR Debug: EasyOCR successfully extracted text');
          // Log first few characters to verify it's not gibberish
          final preview = extractedText.length > 50
              ? extractedText.substring(0, 50)
              : extractedText;
          print('OCR Debug: Extracted text preview: $preview');
          return {'text': extractedText, 'error': null};
        } else {
          final errorMsg = message ?? 'No text detected in image';
          print('OCR Debug: EasyOCR returned empty or failed: $errorMsg');
          return {'text': null, 'error': errorMsg};
        }
      } else {
        final errorBody = response.body;
        print(
            '❌ OCR Debug: EasyOCR API error: ${response.statusCode} - $errorBody');
        String errorMsg;
        if (response.statusCode == 503) {
          errorMsg =
              'EasyOCR not installed on backend. Install with: pip install easyocr';
        } else if (response.statusCode == 400) {
          errorMsg = 'Invalid image data sent to backend';
        } else if (response.statusCode == 500) {
          errorMsg = 'Backend server error (check backend logs)';
        } else if (response.statusCode == 404) {
          errorMsg =
              'Backend endpoint not found. Check if backend is running on $baseUrl';
        } else {
          errorMsg = 'Backend error: ${response.statusCode}';
        }
        return {'text': null, 'error': errorMsg};
      }
    } catch (e, stackTrace) {
      print('❌ OCR Debug: EasyOCR error: ${e.toString()}');
      print('OCR Debug: EasyOCR stack trace: $stackTrace');
      String errorMsg;
      if (e.toString().contains('timeout') ||
          e.toString().contains('TimeoutException')) {
        errorMsg =
            'OCR request timed out. Please try again. If this persists, check if backend is running on $baseUrl';
      } else if (e.toString().contains('Failed host lookup') ||
          e.toString().contains('SocketException')) {
        errorMsg =
            'Cannot connect to backend server at $baseUrl. Check if backend is running and network connectivity';
      } else if (e.toString().contains('FormatException') ||
          e.toString().contains('json')) {
        errorMsg = 'Invalid response from backend. Please check backend logs.';
      } else {
        errorMsg =
            'OCR processing error: ${e.toString().length > 100 ? e.toString().substring(0, 100) : e.toString()}';
      }
      // Return error instead of throwing to prevent app crash
      return {'text': null, 'error': errorMsg};
    }
  }

  /// Extract text using EasyOCR via backend API (backward compatibility)
  static Future<String?> _extractWithEasyOCR(String imagePath) async {
    final result = await _extractWithEasyOCRWithDetails(imagePath);
    return result['text'];
  }

  /// Optimize image for OCR by resizing and compressing
  /// Reduces transfer time and processing time on backend
  /// CRITICAL: Uses compute() to run in background isolate (prevents UI blocking)
  static Future<Uint8List> _optimizeImageForOCR(
      Uint8List imageBytes, String imagePath) async {
    // CRITICAL: Move heavy image processing to background isolate
    return await compute(
        _optimizeImageInIsolate, {'bytes': imageBytes, 'path': imagePath});
  }

  /// Helper function to run in isolate (must be top-level or static)
  static Uint8List _optimizeImageInIsolate(Map<String, dynamic> params) {
    final Uint8List imageBytes = params['bytes'];
    try {
      // Decode image
      final img.Image? image = img.decodeImage(imageBytes);
      if (image == null) {
        return imageBytes; // Return original if decode fails
      }

      // Target max dimensions for OCR (balance between quality and speed)
      const int maxWidth = 1920;
      const int maxHeight = 1080;

      // Check if resizing is needed
      bool needsResize = image.width > maxWidth || image.height > maxHeight;

      img.Image processedImage = image;

      if (needsResize) {
        // Calculate new dimensions maintaining aspect ratio
        double scale =
            (maxWidth / image.width).clamp(0.0, maxHeight / image.height);
        final int newWidth = (image.width * scale).round();
        final int newHeight = (image.height * scale).round();

        processedImage = img.copyResize(image,
            width: newWidth,
            height: newHeight,
            interpolation: img.Interpolation.cubic);
      }

      // Convert to JPEG with quality 85 (good balance between size and quality)
      // JPEG is smaller than PNG for photos
      final optimizedBytes =
          Uint8List.fromList(img.encodeJpg(processedImage, quality: 85));

      // Only use optimized if it's actually smaller
      if (optimizedBytes.length < imageBytes.length) {
        return optimizedBytes;
      } else {
        return imageBytes; // Return original if optimization didn't help
      }
    } catch (e) {
      print('OCR Debug: ⚠ Image optimization failed: $e, using original');
      return imageBytes; // Return original on error
    }
  }

  /// Check if text looks like gibberish (random ASCII characters)
  /// This happens when Tesseract/EasyOCR tries to read Arabic with English model
  /// Returns true if text appears to be gibberish
  static bool _isGibberishText(String text) {
    if (text.trim().isEmpty) {
      return false; // Empty is not gibberish
    }

    // CRITICAL: Check for very short outputs that are just numbers or random chars
    // Examples: "04", "4", "04\n'Ysis4ul\nJi" - these are gibberish
    final lines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.length <= 2 && text.trim().length < 20) {
      // Very short output with few lines - likely gibberish
      final cleanText =
          text.replaceAll(RegExp(r'[^\w]'), ''); // Remove non-word chars
      if (cleanText.length < 10) {
        // Check if it's mostly numbers or random chars
        final digitCount = RegExp(r'\d').allMatches(cleanText).length;
        final letterCount = RegExp(r'[a-zA-Z]').allMatches(cleanText).length;
        if (digitCount > 0 && letterCount < 5 && cleanText.length < 15) {
          print(
              'OCR Debug: ⚠ Detected gibberish: very short output with numbers and few letters');
          return true; // Likely gibberish like "04\n'Ysis4ul\nJi"
        }
      }
    }

    // Remove whitespace and newlines for analysis
    final cleanText = text.replaceAll(RegExp(r'\s+'), '');
    if (cleanText.length < 5) {
      return false; // Too short to judge
    }

    // Check 1: High ratio of random-looking character sequences
    // Gibberish often has patterns like: "dfsafsalfhasxfsaf" (repeated similar chars)
    int suspiciousPatterns = 0;
    for (int i = 0; i < cleanText.length - 3; i++) {
      final substr = cleanText.substring(i, i + 4).toLowerCase();
      // Check for patterns like "asdf", "fdsa", repeated chars
      if (substr[0] == substr[1] ||
          substr[1] == substr[2] ||
          substr[2] == substr[3]) {
        suspiciousPatterns++;
      }
      // Check for alternating patterns
      if ((substr[0] == substr[2] && substr[1] == substr[3]) &&
          substr[0] != substr[1]) {
        suspiciousPatterns++;
      }
    }

    final patternRatio = suspiciousPatterns / (cleanText.length - 3);

    // Check 2: Very high ratio of consonants (English gibberish has few vowels)
    final vowels = RegExp(r'[aeiouAEIOU]');
    final vowelCount = vowels.allMatches(cleanText).length;
    final vowelRatio = vowelCount / cleanText.length;

    // Check 3: Contains Arabic/Urdu Unicode characters (U+0600-U+06FF)
    // If it contains Arabic characters, it's NOT gibberish from Tesseract
    final arabicPattern = RegExp(r'[\u0600-\u06FF]');
    final hasArabicChars = arabicPattern.hasMatch(text);

    // If text contains Arabic characters, it's not gibberish
    if (hasArabicChars) {
      return false;
    }

    // Check 4: Very low vowel ratio (< 10%) suggests gibberish
    if (vowelRatio < 0.1 && cleanText.length > 10) {
      print(
          'OCR Debug: ⚠ Detected gibberish: very low vowel ratio (${(vowelRatio * 100).toStringAsFixed(1)}%)');
      return true;
    }

    // Gibberish indicators:
    // - Low vowel ratio (< 0.15) AND high suspicious patterns (> 0.3)
    // - OR very high suspicious patterns (> 0.5)
    final isGibberish =
        (vowelRatio < 0.15 && patternRatio > 0.3) || patternRatio > 0.5;

    if (isGibberish) {
      print(
          'OCR Debug: Gibberish detected - vowel ratio: $vowelRatio, pattern ratio: $patternRatio');
    }

    return isGibberish;
  }

  /// Check if text contains Arabic Unicode characters (U+0600-U+06FF)
  /// Used to detect misclassification when Arabic text is routed to English OCR
  static bool _containsArabicCharacters(String text) {
    final arabicPattern = RegExp(r'[\u0600-\u06FF]');
    return arabicPattern.hasMatch(text);
  }

  /// Combine results from Tesseract and EasyOCR for maximum text extraction
  /// Removes duplicates and merges unique text intelligently
  static String _combineOCRResults(String tesseractText, String easyOCRText) {
    if (tesseractText.isEmpty) return easyOCRText;
    if (easyOCRText.isEmpty) return tesseractText;

    // Split into words/lines for comparison
    final tesseractLines =
        tesseractText.split('\n').where((l) => l.trim().isNotEmpty).toList();
    final easyOCRLines =
        easyOCRText.split('\n').where((l) => l.trim().isNotEmpty).toList();

    // Use the longer result as base, add unique lines from the other
    final baseText =
        tesseractText.length > easyOCRText.length ? tesseractText : easyOCRText;
    final otherText =
        tesseractText.length > easyOCRText.length ? easyOCRText : tesseractText;

    // Simple combination: prefer longer result, add unique words from shorter
    final baseWords = baseText
        .split(RegExp(r'\s+'))
        .where((w) => w.trim().isNotEmpty)
        .toSet();
    final otherWords = otherText
        .split(RegExp(r'\s+'))
        .where((w) => w.trim().isNotEmpty)
        .toSet();

    // If results are very similar (>80% overlap), return the longer one
    final intersection = baseWords.intersection(otherWords).length;
    final union = baseWords.union(otherWords).length;
    final similarity = union > 0 ? intersection / union : 0.0;

    if (similarity > 0.8) {
      // Very similar - return longer result
      return baseText;
    } else {
      // Different results - combine unique words
      final uniqueWords = otherWords.difference(baseWords);
      if (uniqueWords.isEmpty) {
        return baseText;
      }
      // Append unique words/phrases
      return '$baseText\n${uniqueWords.join(' ')}';
    }
  }

  /// Helper function to decode image for diagnostics in isolate
  /// Must be top-level or static for compute()
  static Map<String, dynamic>? _decodeImageForDiagnostics(
      Uint8List imageBytes) {
    try {
      final img.Image? decodedImage = img.decodeImage(imageBytes);
      if (decodedImage != null) {
        return {
          'width': decodedImage.width,
          'height': decodedImage.height,
          'format': decodedImage.format.toString(),
          'hasAlpha': decodedImage.hasAlpha,
        };
      }
    } catch (e) {
      // Return null on error
    }
    return null;
  }

  /// Helper function to read file in isolate (for large files)
  /// Must be top-level or static for compute()
  static Future<Uint8List> _readFileInIsolate(String imagePath) async {
    final file = File(imagePath);
    return await file.readAsBytes();
  }
}
