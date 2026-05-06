import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;

import '../core/theme/app_colors.dart';
import '../utils/theme_notifier.dart';
import '../widgets/custom_button.dart';

enum SelectedLanguage { none, english, urdu, arabic }

/// Crash-free image cropping screen using pure Dart (crop_your_image)
///
/// Features:
/// - Free-form cropping only (no aspect ratio restrictions)
/// - Optional cropping (user can skip and use original image)
/// - Large image display for better visibility
/// - Preview after crop/skip with Extract Text button
/// - 100% Dart/Flutter - no native crashes possible
class CropImagePage extends StatefulWidget {
  const CropImagePage({super.key});

  @override
  State<CropImagePage> createState() => _CropImagePageState();
}

class _CropImagePageState extends State<CropImagePage> {
  String? _imagePath;
  Uint8List? _imageBytes;
  final CropController _cropController = CropController();

  // Safety flags to prevent multiple operations
  bool _isProcessing = false;
  bool _isImageLoaded = false;

  // State after crop/skip
  String? _finalImagePath; // Path to the final image (cropped or original)
  Uint8List? _finalImageBytes; // Bytes of final image for preview
  bool _isCropped = false; // Whether user cropped or skipped

  // Language selection (MANDATORY)
  SelectedLanguage _selectedLanguage = SelectedLanguage.none;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Get image path from route arguments
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic> && args['imagePath'] != null) {
      _imagePath = args['imagePath'] as String;
      _loadImage();
    }
  }

  /// Load image file into memory safely
  Future<void> _loadImage() async {
    if (_imagePath == null || _isImageLoaded) return;

    try {
      final file = File(_imagePath!);
      if (!await file.exists()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Image file not found'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Read image bytes
      final bytes = await file.readAsBytes();

      // Limit image size to prevent memory issues (max 10MB)
      if (bytes.length > 10 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Image too large. Please use an image smaller than 10MB.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      if (mounted) {
        setState(() {
          _imageBytes = bytes;
          _isImageLoaded = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading image: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Crop the image and save to file
  void _cropAndSave() {
    // Safety check: prevent multiple simultaneous operations
    if (_isProcessing || _imageBytes == null) {
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    // Trigger crop - result will be handled in onCropped callback
    _cropController.crop();
  }

  /// Handle cropped image result from the callback
  void _handleCroppedImage(CropResult result) {
    _processCroppedResult(result);
  }

  /// Process the cropped result and save to file with padding
  Future<void> _processCroppedResult(CropResult result) async {
    try {
      // Check if result is CropSuccess or CropFailure
      if (result is CropFailure) {
        throw Exception('Crop failed: ${result.cause}');
      }

      if (result is! CropSuccess) {
        throw Exception('Unexpected crop result type: ${result.runtimeType}');
      }

      // Extract cropped image bytes from CropSuccess
      final croppedBytes = result.croppedImage;

      if (croppedBytes.isEmpty) {
        throw Exception('Failed to crop image - empty result');
      }

      // STEP 2: Add padding (max(32px, 8% of width/height))
      final img.Image? decodedImage = img.decodeImage(croppedBytes);
      if (decodedImage == null) {
        throw Exception('Failed to decode cropped image');
      }

      final int originalWidth = decodedImage.width;
      final int originalHeight = decodedImage.height;

      // Calculate padding: max(32px, 8% of width/height)
      final int paddingX = (originalWidth * 0.08).round();
      final int paddingY = (originalHeight * 0.08).round();
      final int padding = paddingX > paddingY
          ? (paddingX > 32 ? paddingX : 32)
          : (paddingY > 32 ? paddingY : 32);

      // Create new image with padding (white background)
      final int newWidth = originalWidth + (padding * 2);
      final int newHeight = originalHeight + (padding * 2);
      final img.Image paddedImage =
          img.Image(width: newWidth, height: newHeight);

      // Fill with white background
      img.fill(paddedImage, color: img.ColorRgb8(255, 255, 255));

      // Copy original image to center
      img.compositeImage(paddedImage, decodedImage,
          dstX: padding, dstY: padding);

      // Save as PNG (no compression)
      final Uint8List paddedBytes =
          Uint8List.fromList(img.encodePng(paddedImage));

      // Save to temporary file as PNG
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final croppedFile = File('${tempDir.path}/cropped_$timestamp.png');

      await croppedFile.writeAsBytes(paddedBytes);

      // Update state to show preview - stay on page
      if (mounted) {
        setState(() {
          _finalImagePath = croppedFile.path;
          _finalImageBytes = paddedBytes;
          _isCropped = true;
          _isProcessing = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Image cropped and padded (${padding}px) successfully!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error cropping image: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  /// Skip cropping and use original image
  void _skipCrop() {
    if (_isProcessing) return; // Prevent skip during processing

    // Set final image to original - stay on page
    setState(() {
      _finalImagePath = _imagePath;
      _finalImageBytes = _imageBytes;
      _isCropped = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Using original image'),
        backgroundColor: Colors.blue,
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// Extract text from image and return to home screen
  void _extractText() {
    if (_finalImagePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please crop or skip first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // STEP 1: Language selection is MANDATORY
    if (_selectedLanguage == SelectedLanguage.none) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a language first'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // Return the final image path and selected language to home screen
    Navigator.pop(context, {
      'imagePath': _finalImagePath,
      'language': _selectedLanguage,
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeNotifier.instance.isDark;
    // If image is already cropped/skipped, show preview mode
    final bool showPreview = _finalImagePath != null;

    return Scaffold(
      backgroundColor: ThemeColors.background(isDark),
      appBar: AppBar(
        backgroundColor: ThemeColors.background(isDark),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          color: ThemeColors.textPrimary(isDark),
          onPressed: _isProcessing
              ? null
              : () {
                  // If preview is shown, reset to crop mode, else go back
                  if (showPreview) {
                    setState(() {
                      _finalImagePath = null;
                      _finalImageBytes = null;
                      _isCropped = false;
                    });
                  } else {
                    Navigator.pop(context);
                  }
                },
        ),
        title: Text(
          showPreview ? 'Preview Image' : 'Crop Image (Optional)',
          style: TextStyle(
            color: ThemeColors.textPrimary(isDark),
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Instructions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Column(
                children: [
                  Text(
                    showPreview
                        ? 'Review your image. Select language and click "Extract Text" to run OCR.'
                        : 'Adjust the crop area or skip to use the original image.',
                    style: TextStyle(
                      fontSize: 13,
                      color: ThemeColors.textSecondary(isDark),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (showPreview) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Make sure image quality is good',
                      style: TextStyle(
                        fontSize: 12,
                        color: ThemeColors.textSecondary(isDark),
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  if (!showPreview) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Tip: Padding will be added automatically after cropping.',
                      style: TextStyle(
                        fontSize: 11,
                        color: ThemeColors.textSecondary(isDark),
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),

            // STEP 1: Language Selector (MANDATORY)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select Language *',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: ThemeColors.textPrimary(isDark),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildLanguageButton(
                          'English',
                          SelectedLanguage.english,
                          Icons.language,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildLanguageButton(
                          'Urdu',
                          SelectedLanguage.urdu,
                          Icons.translate,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildLanguageButton(
                          'Arabic',
                          SelectedLanguage.arabic,
                          Icons.text_fields,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Large image display area - takes most of the screen
            Expanded(
              child: showPreview ? _buildPreviewMode() : _buildCropMode(),
            ),

            // Action buttons at bottom
            Padding(
              padding: const EdgeInsets.all(20),
              child: showPreview ? _buildPreviewButtons() : _buildCropButtons(),
            ),
          ],
        ),
      ),
    );
  }

  /// Build crop mode UI (interactive cropping)
  Widget _buildCropMode() {
    final isDark = ThemeNotifier.instance.isDark;
    return _isImageLoaded && _imageBytes != null
        ? Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: ThemeColors.card(isDark),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ThemeColors.border(isDark)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Crop(
                  image: _imageBytes!,
                  controller: _cropController,
                  aspectRatio: null, // Free form cropping only
                  radius: 0, // Square corners
                  baseColor: AppColors.primary,
                  maskColor: ThemeColors.background(isDark).withValues(
                    alpha: 0.8,
                  ),
                  onCropped: _handleCroppedImage,
                ),
              ),
            ),
          )
        : _isProcessing
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      'Processing image...',
                      style: TextStyle(
                        color: ThemeColors.textSecondary(isDark),
                      ),
                    ),
                  ],
                ),
              )
            : Center(
                child: Text(
                  'Loading image...',
                  style: TextStyle(
                    color: ThemeColors.textSecondary(isDark),
                  ),
                ),
              );
  }

  /// Build preview mode UI (show final image)
  Widget _buildPreviewMode() {
    final isDark = ThemeNotifier.instance.isDark;
    return _finalImageBytes != null
        ? Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: ThemeColors.card(isDark),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ThemeColors.border(isDark)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  _finalImageBytes!,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          )
        : Center(
            child: Text(
              'No image preview available',
              style: TextStyle(
                color: ThemeColors.textSecondary(isDark),
              ),
            ),
          );
  }

  /// Build buttons for crop mode
  Widget _buildCropButtons() {
    final isDark = ThemeNotifier.instance.isDark;
    return Column(
      children: [
        // Skip Crop button (use original image)
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _isProcessing ? null : _skipCrop,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: BorderSide(color: ThemeColors.border(isDark)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Skip Crop (Use Original)',
              style: TextStyle(
                color: ThemeColors.textPrimary(isDark),
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Confirm Crop button
        CustomButton(
          text: _isProcessing ? 'Processing...' : 'Confirm Crop',
          onPressed: (_isProcessing || !_isImageLoaded)
              ? () {} // Empty callback when disabled
              : _cropAndSave,
          icon: Icons.check,
          width: double.infinity,
        ),
      ],
    );
  }

  /// Build buttons for preview mode
  Widget _buildPreviewButtons() {
    final isDark = ThemeNotifier.instance.isDark;
    // Extract Text button is disabled if no language selected
    final bool canExtract = _selectedLanguage != SelectedLanguage.none;

    return Column(
      children: [
        // Edit Crop button (go back to crop mode)
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () {
              setState(() {
                _finalImagePath = null;
                _finalImageBytes = null;
                _isCropped = false;
              });
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: BorderSide(color: ThemeColors.border(isDark)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Edit Crop',
              style: TextStyle(
                color: ThemeColors.textPrimary(isDark),
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Extract Text button (disabled until language selected)
        CustomButton(
          text: canExtract ? 'Extract Text' : 'Select Language First',
          onPressed: canExtract ? _extractText : () {},
          icon: Icons.text_fields,
          width: double.infinity,
        ),
      ],
    );
  }

  /// Build language selection button
  Widget _buildLanguageButton(
      String label, SelectedLanguage language, IconData icon) {
    final isDark = ThemeNotifier.instance.isDark;
    final bool isSelected = _selectedLanguage == language;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedLanguage = language;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.2)
              : ThemeColors.card(isDark),
          border: Border.all(
            color: isSelected ? AppColors.primary : ThemeColors.border(isDark),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected
                  ? AppColors.primary
                  : ThemeColors.textSecondary(isDark),
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? AppColors.primary
                    : ThemeColors.textSecondary(isDark),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
