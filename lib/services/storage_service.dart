import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

class StorageService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static final ImagePicker _picker = ImagePicker();

  /// Pick an image from gallery or camera
  /// For OCR purposes, uses higher quality settings
  static Future<File?> pickImage(
      {ImageSource source = ImageSource.gallery}) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 95, // Higher quality for better OCR results
        maxWidth: 2048, // Higher resolution for better OCR
        maxHeight: 2048, // Higher resolution for better OCR
      );

      if (image != null) {
        return File(image.path);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to pick image: ${e.toString()}');
    }
  }

  /// Upload profile photo to Firebase Storage
  /// Returns the download URL of the uploaded image
  static Future<String> uploadProfilePhoto(
      File imageFile, String userId) async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User must be authenticated to upload photos');
      }

      // Create a unique filename
      final String fileName =
          'profile_photos/${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Create a reference to the file location
      final Reference ref = _storage.ref().child(fileName);

      // Upload the file
      final UploadTask uploadTask = ref.putFile(
        imageFile,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'userId': userId,
            'uploadedAt': DateTime.now().toIso8601String(),
          },
        ),
      );

      // Wait for upload to complete
      final TaskSnapshot snapshot = await uploadTask;

      // Get the download URL
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      throw Exception('Failed to upload profile photo: ${e.toString()}');
    }
  }

  /// Delete a profile photo from Firebase Storage
  static Future<void> deleteProfilePhoto(String photoUrl) async {
    try {
      // Extract the file path from the Firebase Storage URL
      // URL format: https://firebasestorage.googleapis.com/v0/b/{bucket}/o/{path}?alt=media&token={token}
      final Uri uri = Uri.parse(photoUrl);

      // Extract the path from the URL
      // The path is in the format: profile_photos%2F{uid}_{timestamp}.jpg
      String? encodedPath;
      for (final segment in uri.pathSegments) {
        if (segment == 'o' &&
            uri.pathSegments.length > uri.pathSegments.indexOf(segment) + 1) {
          encodedPath = uri.pathSegments[uri.pathSegments.indexOf(segment) + 1];
          break;
        }
      }

      if (encodedPath == null) {
        // Try alternative method: extract from query or path
        final pathMatch = RegExp(r'/o/([^?]+)').firstMatch(photoUrl);
        if (pathMatch != null) {
          encodedPath = pathMatch.group(1);
        }
      }

      if (encodedPath == null) {
        throw Exception('Could not extract file path from URL');
      }

      // Decode the URL-encoded path
      final String decodedPath = Uri.decodeComponent(encodedPath);

      // Get reference to the file
      final Reference ref = _storage.ref().child(decodedPath);

      // Delete the file
      await ref.delete();
    } catch (e) {
      // Log but don't throw — the file may already be deleted or never existed.
      // Callers should not treat a missing Storage file as a fatal error.
      debugPrint('Warning: Failed to delete profile photo from Firebase Storage: ${e.toString()}');
    }
  }

  /// Show image source selection dialog
  /// Returns the selected ImageSource or null if cancelled
  static Future<ImageSource?> showImageSourceDialog() async {
    // This method should be called from a UI context
    // For now, we'll return a default source
    // You can implement a dialog in your UI code
    return ImageSource.gallery;
  }
}
