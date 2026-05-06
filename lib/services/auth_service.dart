import 'package:firebase_auth/firebase_auth.dart';
import 'api_service.dart';
import 'storage_service.dart';
import '../models/user_model.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Sign up a new user with Firebase and register in backend
  static Future<UserModel> signUp({
    required String name,
    required String email,
    required String password,
    String? profilePhotoUrl,
  }) async {
    try {
      // Step 1: Create user in Firebase
      final UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User? firebaseUser = userCredential.user;
      if (firebaseUser == null) {
        throw Exception('Failed to create Firebase user');
      }

      final String firebaseUid = firebaseUser.uid;

      // Step 2: Update Firebase display name
      await firebaseUser.updateDisplayName(name);
      await firebaseUser.reload();

      // Step 3: Register user in PostgreSQL backend
      final UserModel userModel = await ApiService.registerUser(
        firebaseUid: firebaseUid,
        username: name,
        email: email,
        profilePhotoUrl: profilePhotoUrl,
      );

      return userModel;
    } on FirebaseAuthException catch (e) {
      throw Exception(_getFirebaseErrorMessage(e.code, e.message));
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Sign up failed: ${e.toString()}');
    }
  }

  /// Sign in existing user with Firebase and get user data from backend
  static Future<UserModel> signIn({
    required String email,
    required String password,
  }) async {
    try {
      // Step 1: Sign in with Firebase
      final UserCredential userCredential =
          await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User? firebaseUser = userCredential.user;
      if (firebaseUser == null) {
        throw Exception('Failed to sign in');
      }

      final String firebaseUid = firebaseUser.uid;

      // Step 2: Get user data from PostgreSQL backend
      UserModel userModel;
      try {
        userModel = await ApiService.loginUser(
          firebaseUid: firebaseUid,
        );
      } catch (e) {
        // If user is in Firebase but not in our PostgreSQL backend, auto-register them
        if (e.toString().contains('User not found')) {
          userModel = await ApiService.registerUser(
            firebaseUid: firebaseUid,
            username: firebaseUser.displayName ?? email.split('@')[0],
            email: email,
            profilePhotoUrl: firebaseUser.photoURL,
          );
        } else {
          rethrow;
        }
      }

      return userModel;
    } on FirebaseAuthException catch (e) {
      throw Exception(_getFirebaseErrorMessage(e.code, e.message));
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Sign in failed: ${e.toString()}');
    }
  }

  /// Send password reset email.
  /// Firebase uses the Action URL set in Firebase Console → Authentication →
  /// Templates → Password reset. Set that to: truehadith://reset-password
  /// so the link opens the app directly via the custom URL scheme.
  static Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw Exception(_getFirebaseErrorMessage(e.code, e.message));
    } catch (e) {
      throw Exception('Failed to send password reset email: ${e.toString()}');
    }
  }

  /// Confirm password reset with action code and new password
  static Future<void> confirmPasswordReset({
    required String actionCode,
    required String newPassword,
  }) async {
    try {
      await _auth.confirmPasswordReset(
        code: actionCode,
        newPassword: newPassword,
      );
    } on FirebaseAuthException catch (e) {
      throw Exception(_getFirebaseErrorMessage(e.code, e.message));
    } catch (e) {
      throw Exception('Failed to reset password: ${e.toString()}');
    }
  }

  /// Verify password reset action code — returns the email associated with the code
  static Future<String> verifyPasswordResetCode(String actionCode) async {
    try {
      return await _auth.verifyPasswordResetCode(actionCode);
    } on FirebaseAuthException catch (e) {
      throw Exception(_getFirebaseErrorMessage(e.code, e.message));
    } catch (e) {
      throw Exception('Invalid or expired reset code: ${e.toString()}');
    }
  }

  /// Send email verification
  static Future<void> sendEmailVerification() async {
    try {
      final User? user = _auth.currentUser;
      if (user == null) {
        throw Exception('No user is currently signed in');
      }
      if (user.emailVerified) {
        throw Exception('Email is already verified');
      }
      await user.sendEmailVerification();
    } on FirebaseAuthException catch (e) {
      throw Exception(_getFirebaseErrorMessage(e.code, e.message));
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Failed to send verification email: ${e.toString()}');
    }
  }

  /// Reload current user to get latest data (e.g., email verification status)
  static Future<void> reloadUser() async {
    try {
      final User? user = _auth.currentUser;
      if (user != null) {
        await user.reload();
      }
    } catch (e) {
      throw Exception('Failed to reload user: ${e.toString()}');
    }
  }

  /// Check if current user's email is verified
  static bool isEmailVerified() {
    final User? user = _auth.currentUser;
    return user?.emailVerified ?? false;
  }

  /// Update user's display name in Firebase
  static Future<void> updateDisplayName(String displayName) async {
    try {
      final User? user = _auth.currentUser;
      if (user == null) {
        throw Exception('No user is currently signed in');
      }
      await user.updateDisplayName(displayName);
      await user.reload();
    } on FirebaseAuthException catch (e) {
      throw Exception(_getFirebaseErrorMessage(e.code, e.message));
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Failed to update display name: ${e.toString()}');
    }
  }

  /// Update user's email in Firebase
  /// Note: Email updates should be handled through your backend API
  /// or Firebase Console for security reasons
  /// This method is a placeholder - implement email update through backend
  static Future<void> updateEmail(String newEmail) async {
    // Email updates are sensitive operations and should be handled server-side
    // or through Firebase Console. Implement this through your backend API.
    throw Exception(
        'Email update should be handled through backend API or Firebase Console');
  }

  /// Update user's password
  static Future<void> updatePassword(String newPassword) async {
    try {
      final User? user = _auth.currentUser;
      if (user == null) {
        throw Exception('No user is currently signed in');
      }
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      throw Exception(_getFirebaseErrorMessage(e.code, e.message));
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Failed to update password: ${e.toString()}');
    }
  }

  /// Re-authenticate user (required for sensitive operations)
  static Future<void> reauthenticate(String password) async {
    try {
      final User? user = _auth.currentUser;
      if (user == null) {
        throw Exception('No user is currently signed in');
      }
      if (user.email == null) {
        throw Exception('User email is null');
      }

      final AuthCredential credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );

      await user.reauthenticateWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw Exception(_getFirebaseErrorMessage(e.code, e.message));
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Re-authentication failed: ${e.toString()}');
    }
  }

  /// Delete user account (requires re-authentication first)
  static Future<void> deleteAccount() async {
    try {
      final User? user = _auth.currentUser;
      if (user == null) {
        throw Exception('No user is currently signed in');
      }
      await user.delete();
    } on FirebaseAuthException catch (e) {
      throw Exception(_getFirebaseErrorMessage(e.code, e.message));
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Failed to delete account: ${e.toString()}');
    }
  }

  /// Sign out current user
  static Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Get current Firebase user
  static User? getCurrentUser() {
    return _auth.currentUser;
  }

  /// Check if user is signed in
  static bool isSignedIn() {
    return _auth.currentUser != null;
  }

  /// Stream of auth state changes
  /// Use this to listen to authentication state changes in real-time
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Stream of user changes (includes profile updates)
  /// Use this to listen to user profile changes
  static Stream<User?> get userChanges => _auth.userChanges();

  /// Get user data from backend if signed in
  /// Returns null if not signed in or if backend call fails
  static Future<UserModel?> getCurrentUserData() async {
    try {
      final User? firebaseUser = _auth.currentUser;
      if (firebaseUser == null) {
        return null;
      }

      final UserModel userModel = await ApiService.loginUser(
        firebaseUid: firebaseUser.uid,
      );

      return userModel;
    } catch (e) {
      return null;
    }
  }

  /// Update user's profile photo
  static Future<UserModel> updateProfilePhoto({
    required int userId,
    required String profilePhotoUrl,
  }) async {
    try {
      final UserModel updatedUser = await ApiService.updateProfilePhoto(
        userId: userId,
        profilePhotoUrl: profilePhotoUrl,
      );
      return updatedUser;
    } catch (e) {
      throw Exception('Failed to update profile photo: ${e.toString()}');
    }
  }

  /// Delete user's profile photo
  static Future<UserModel> deleteProfilePhoto({
    required int userId,
    String? photoUrl, // Optional: URL of photo to delete from Firebase Storage
  }) async {
    try {
      // Delete from Firebase Storage if URL provided
      if (photoUrl != null && photoUrl.isNotEmpty) {
        try {
          await StorageService.deleteProfilePhoto(photoUrl);
        } catch (e) {
          // Log but don't fail if Firebase deletion fails
          print('Warning: Failed to delete photo from Firebase Storage: $e');
        }
      }

      // Delete from backend database
      final UserModel updatedUser = await ApiService.deleteProfilePhoto(
        userId: userId,
      );
      return updatedUser;
    } catch (e) {
      throw Exception('Failed to delete profile photo: ${e.toString()}');
    }
  }

  /// Convert Firebase error codes to user-friendly messages
  static String _getFirebaseErrorMessage(String code,
      [String? defaultMessage]) {
    switch (code) {
      case 'weak-password':
        return 'The password provided is too weak.';
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'user-not-found':
        return 'No user found for that email. Please sign up first.';
      case 'wrong-password':
        return 'Wrong password provided. Please try again.';
      case 'invalid-email':
        return 'The email address is invalid.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'too-many-requests':
        return 'Too many requests. Please try again later.';
      case 'operation-not-allowed':
        return 'Signing in with Email and Password is not enabled.';
      case 'requires-recent-login':
        return 'This operation requires recent authentication. Please log in again.';
      case 'invalid-credential':
        return 'Invalid email or password. Please check your credentials and try again.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with the same email address but different sign-in credentials.';
      case 'network-request-failed':
        return 'A network error occurred. Please check your internet connection.';
      default:
        return defaultMessage != null && defaultMessage.isNotEmpty
            ? defaultMessage
            : 'An error occurred: $code';
    }
  }
}
