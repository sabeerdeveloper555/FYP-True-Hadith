# Profile Photo Implementation Guide

This guide explains how to use the profile photo functionality that has been added to your app.

## Overview

The profile photo feature allows users to:
1. Upload profile photos during registration (optional)
2. Update their profile photo after registration
3. Display profile photos throughout the app

## What Has Been Implemented

### Backend (Python/Flask)
- ✅ Updated `/api/auth/register` endpoint to accept `profile_photo_url`
- ✅ Updated `/api/auth/login` endpoint to return `profile_photo_url`
- ✅ Added `/api/user/update-profile-photo` endpoint to update profile photos
- ✅ Database field `profile_photo_url` is now used in all user queries

### Flutter App
- ✅ Updated `UserModel` to include `profilePhotoUrl` field
- ✅ Added Firebase Storage dependency (`firebase_storage`)
- ✅ Added Image Picker dependency (`image_picker`)
- ✅ Created `StorageService` for handling photo uploads to Firebase Storage
- ✅ Updated `ApiService` to handle profile photo URLs
- ✅ Updated `AuthService` to support profile photo during signup and updates
- ✅ Created `ProfilePhotoWidget` for easy profile photo display and updates

## Setup Instructions

### 1. Install Dependencies

Run this command in your Flutter project directory:
```bash
flutter pub get
```

### 2. Configure Firebase Storage

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Navigate to **Storage** in the left menu
4. Click **Get Started**
5. Choose **Start in test mode** (for development) or set up security rules
6. Select a storage location

### 3. Update Firebase Storage Security Rules (Recommended)

In Firebase Console → Storage → Rules, update to:
```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // Allow authenticated users to upload profile photos
    match /profile_photos/{userId}_{timestamp}.jpg {
      allow read: if true; // Anyone can read
      allow write: if request.auth != null && 
                      request.auth.uid == resource.metadata.userId;
    }
  }
}
```

## Usage Examples

### Example 1: Display Profile Photo in Home Screen

```dart
import 'package:flutter/material.dart';
import '../widgets/profile_photo_widget.dart';
import '../models/user_model.dart';

class HomeScreen extends StatelessWidget {
  final UserModel user;

  const HomeScreen({required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Welcome, ${user.username}'),
      ),
      body: Center(
        child: ProfilePhotoWidget(
          photoUrl: user.profilePhotoUrl,
          userId: user.userId,
          size: 120,
          onPhotoUpdated: (updatedUser) {
            // Handle photo update
            print('Photo updated: ${updatedUser.profilePhotoUrl}');
          },
        ),
      ),
    );
  }
}
```

### Example 2: Upload Photo During Registration

```dart
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../services/storage_service.dart';
import '../services/auth_service.dart';

// In your signup screen
Future<void> _signUpWithPhoto() async {
  // 1. Pick image
  final File? imageFile = await StorageService.pickImage(
    source: ImageSource.gallery,
  );
  
  if (imageFile == null) {
    // User cancelled, proceed without photo
    await AuthService.signUp(
      name: name,
      email: email,
      password: password,
    );
    return;
  }

  // 2. Upload to Firebase Storage
  final String photoUrl = await StorageService.uploadProfilePhoto(
    imageFile,
    'temp_user_id', // Use Firebase UID if available
  );

  // 3. Register with photo URL
  await AuthService.signUp(
    name: name,
    email: email,
    password: password,
    profilePhotoUrl: photoUrl,
  );
}
```

### Example 3: Update Profile Photo After Login

```dart
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../services/storage_service.dart';
import '../services/auth_service.dart';

Future<void> _updateProfilePhoto(int userId) async {
  try {
    // Pick image
    final File? imageFile = await StorageService.pickImage(
      source: ImageSource.gallery,
    );
    
    if (imageFile == null) return;

    // Upload to Firebase Storage
    final String photoUrl = await StorageService.uploadProfilePhoto(
      imageFile,
      userId.toString(),
    );

    // Update in backend
    final UserModel updatedUser = await AuthService.updateProfilePhoto(
      userId: userId,
      profilePhotoUrl: photoUrl,
    );

    // Use updatedUser.profilePhotoUrl to update UI
    print('New photo URL: ${updatedUser.profilePhotoUrl}');
  } catch (e) {
    print('Error updating photo: $e');
  }
}
```

## API Endpoints

### Register User (with optional profile photo)
```
POST /api/auth/register
Body: {
  "firebase_uid": "string",
  "username": "string",
  "email": "string",
  "profile_photo_url": "string" (optional)
}
```

### Login User (returns profile photo URL)
```
POST /api/auth/login
Body: {
  "firebase_uid": "string"
}
Response: {
  "user_id": int,
  "username": "string",
  "profile_photo_url": "string" (nullable),
  "created_at": "ISO datetime string"
}
```

### Update Profile Photo
```
PUT /api/user/update-profile-photo
Body: {
  "user_id": int,
  "profile_photo_url": "string"
}
Response: {
  "user_id": int,
  "username": "string",
  "profile_photo_url": "string",
  "created_at": "ISO datetime string"
}
```

## File Structure

```
lib/
├── models/
│   └── user_model.dart (updated with profilePhotoUrl)
├── services/
│   ├── api_service.dart (updated with profile photo support)
│   ├── auth_service.dart (updated with profile photo methods)
│   └── storage_service.dart (new - handles Firebase Storage)
└── widgets/
    └── profile_photo_widget.dart (new - reusable profile photo widget)
```

## Important Notes

1. **Permissions**: Make sure to add camera and storage permissions in your `android/app/src/main/AndroidManifest.xml` and `ios/Runner/Info.plist`

2. **Image Compression**: The `StorageService.pickImage()` method automatically compresses images to 85% quality and resizes them to max 1024x1024px to save storage space.

3. **Error Handling**: Always wrap photo upload operations in try-catch blocks as shown in the examples.

4. **Loading States**: The `ProfilePhotoWidget` shows a loading indicator while uploading.

5. **Storage Costs**: Firebase Storage has free tier limits. Monitor your usage in Firebase Console.

## Next Steps

1. Add profile photo display to your home screen or profile screen
2. Add profile photo selection during registration (optional)
3. Add a settings screen where users can update their profile photo
4. Consider adding photo deletion functionality if needed

## Troubleshooting

- **"Permission denied"**: Check Firebase Storage security rules
- **"Image picker not working"**: Verify permissions in AndroidManifest.xml and Info.plist
- **"Upload fails"**: Check Firebase Storage is enabled and configured correctly
- **"Photo not displaying"**: Verify the URL is correct and accessible

