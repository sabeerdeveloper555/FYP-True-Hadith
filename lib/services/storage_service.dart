import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'api_service.dart';

class StorageService {
  static final ImagePicker _picker = ImagePicker();

  /// Pick an image from gallery or camera
  static Future<File?> pickImage(
      {ImageSource source = ImageSource.gallery}) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (image != null) {
        return File(image.path);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to pick image: ${e.toString()}');
    }
  }

  /// Upload profile photo to the Flask backend.
  /// Returns the download URL of the uploaded image.
  static Future<String> uploadProfilePhoto(
      File imageFile, String userId) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final ext = imageFile.path.toLowerCase().endsWith('.png') ? 'png' : 'jpg';

      final url = await ApiService.uploadProfilePhoto(
        userId: int.parse(userId),
        imageBytes: bytes,
        imageFormat: ext,
      );

      return url;
    } catch (e) {
      throw Exception('Failed to upload profile photo: ${e.toString()}');
    }
  }

  /// Delete a profile photo.
  /// Photos are stored on the Flask backend; the database URL is cleared
  /// by ApiService.deleteProfilePhoto — no separate file deletion needed here.
  static Future<void> deleteProfilePhoto(String photoUrl) async {
    // No-op: file cleanup (if needed) is handled server-side.
    // The database URL is cleared by the caller via ApiService.deleteProfilePhoto.
    debugPrint('StorageService.deleteProfilePhoto: photo URL cleared from DB.');
  }
}
