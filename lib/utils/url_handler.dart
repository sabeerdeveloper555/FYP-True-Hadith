import 'package:flutter/foundation.dart';

/// Utility class to handle URL parameters and deep linking
class UrlHandler {
  /// Get the current URL (web only)
  /// Use Uri.base.toString() instead for cross-platform compatibility
  static String? getCurrentUrl() {
    if (kIsWeb) {
      try {
        return Uri.base.toString();
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  /// Extract action code from Firebase password reset URL
  /// Firebase reset URLs typically have format:
  /// https://your-app.com/reset-password?mode=resetPassword&oobCode=CODE&apiKey=KEY
  static String? extractActionCodeFromUrl(String url) {
    try {
      final uri = Uri.parse(url);

      // Check for oobCode parameter (Firebase's action code)
      final oobCode = uri.queryParameters['oobCode'];
      if (oobCode != null && oobCode.isNotEmpty) {
        return oobCode;
      }

      // Also check for 'code' parameter (alternative format)
      final code = uri.queryParameters['code'];
      if (code != null && code.isNotEmpty) {
        return code;
      }

      // Check if the URL path contains the code
      // Some formats: /reset-password/CODE or /action?mode=resetPassword&oobCode=CODE
      if (uri.pathSegments.isNotEmpty) {
        final lastSegment = uri.pathSegments.last;
        // If it looks like a Firebase action code (long alphanumeric string)
        if (lastSegment.length > 20 &&
            RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(lastSegment)) {
          return lastSegment;
        }
      }

      return null;
    } catch (e) {
      debugPrint('Error parsing URL: $e');
      return null;
    }
  }

  /// Extract email from Firebase password reset URL (if available)
  static String? extractEmailFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.queryParameters['email'];
    } catch (e) {
      return null;
    }
  }

  /// Check if URL is a password reset link
  /// Supports both custom URLs and Firebase's default format:
  /// - Custom: truehadith://reset-password?oobCode=CODE
  /// - Firebase default: https://PROJECT.firebaseapp.com/__/auth/action?mode=resetPassword&oobCode=CODE
  static bool isPasswordResetUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final mode = uri.queryParameters['mode'];

      // Check for mode parameter (Firebase's default format)
      if (mode == 'resetPassword') {
        return true;
      }

      // Check for oobCode parameter (Firebase action code)
      if (uri.queryParameters.containsKey('oobCode')) {
        return true;
      }

      // Check path for Firebase's default action handler
      final path = uri.path.toLowerCase();
      if (path.contains('/__/auth/action') ||
          path.contains('reset-password') ||
          path.contains('resetpassword') ||
          path.contains('action')) {
        return true;
      }

      // Check if it's Firebase's domain
      final host = uri.host.toLowerCase();
      if (host.contains('firebaseapp.com') || host.contains('firebase')) {
        // Check if it has action-related path
        if (path.contains('action') || path.contains('auth')) {
          return true;
        }
      }

      return false;
    } catch (e) {
      debugPrint('Error checking password reset URL: $e');
      return false;
    }
  }

  /// Build password reset URL for the app
  /// This should match your app's URL structure
  static String buildResetPasswordUrl({
    required String baseUrl,
    String? actionCode,
  }) {
    final uri = Uri.parse(baseUrl);
    final resetUrl = uri.replace(
      path: '/reset-password',
      queryParameters: actionCode != null ? {'oobCode': actionCode} : null,
    );
    return resetUrl.toString();
  }
}
