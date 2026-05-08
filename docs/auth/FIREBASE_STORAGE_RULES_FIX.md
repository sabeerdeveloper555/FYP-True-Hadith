# Firebase Storage Security Rules Fix

## Problem
Error: `[firebase_storage/unauthorized] User is not authorized to perform the desired action`

This happens because Firebase Storage security rules are blocking the upload.

## Solution

### Step 1: Go to Firebase Console

1. Open [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Click on **Storage** in the left menu
4. Click on the **Rules** tab

### Step 2: Update Security Rules

Replace your current rules with these:

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // Profile photos - allow authenticated users to upload/delete their own photos
    match /profile_photos/{allPaths=**} {
      // Anyone can read profile photos
      allow read: if true;
      
      // Only authenticated users can write (upload/delete)
      allow write: if request.auth != null;
    }
    
    // Default: deny all other access
    match /{allPaths=**} {
      allow read, write: if false;
    }
  }
}
```

### Step 3: Publish Rules

1. Click **Publish** button
2. Wait for confirmation that rules are published

## Alternative: More Restrictive Rules (Recommended for Production)

If you want more security, use these rules that verify the user owns the file:

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // Profile photos - allow authenticated users to upload/delete their own photos
    match /profile_photos/{fileName} {
      // Anyone can read profile photos
      allow read: if true;
      
      // Users can only upload files that start with their Firebase UID
      allow write: if request.auth != null && 
                     fileName.matches('^' + request.auth.uid + '_.*\\.jpg$');
      
      // Users can delete files that start with their Firebase UID
      allow delete: if request.auth != null && 
                      fileName.matches('^' + request.auth.uid + '_.*\\.jpg$');
    }
    
    // Default: deny all other access
    match /{allPaths=**} {
      allow read, write: if false;
    }
  }
}
```

## How It Works

### File Naming Pattern
Your app uploads files with this pattern:
```
profile_photos/{firebase_uid}_{timestamp}.jpg
```

Example: `profile_photos/abc123xyz_1234567890.jpg`

### Rule Explanation

**Simple Rules (First Option):**
- ✅ Any authenticated user can upload to `profile_photos/`
- ✅ Anyone can read/download photos
- ✅ Any authenticated user can delete from `profile_photos/`

**Restrictive Rules (Second Option):**
- ✅ Users can only upload files starting with their Firebase UID
- ✅ Users can only delete files starting with their Firebase UID
- ✅ Anyone can read/download photos

## Testing

After updating the rules:

1. **Try uploading a profile photo** in your app
2. **Check Firebase Console → Storage** to see if the file appears
3. **Try deleting a profile photo** to verify delete works

## Troubleshooting

### Still Getting Authorization Error?

1. **Check if user is authenticated:**
   - Make sure user is logged in before uploading
   - Check Firebase Auth is properly initialized

2. **Verify rules are published:**
   - Rules take effect immediately after publishing
   - Refresh your app after publishing rules

3. **Check file path:**
   - Make sure files are uploaded to `profile_photos/` folder
   - File name should match pattern: `{uid}_{timestamp}.jpg`

4. **Check Firebase Storage is enabled:**
   - Go to Firebase Console → Storage
   - Make sure Storage is enabled for your project

### Common Issues

**Issue:** Rules not saving
- **Solution:** Make sure you're logged into Firebase Console with correct account

**Issue:** Rules published but still getting errors
- **Solution:** Wait a few seconds for rules to propagate, then try again

**Issue:** Can upload but can't delete
- **Solution:** Make sure delete rule is included (both options above include delete)

## Security Best Practices

1. **For Development:** Use the simple rules (first option)
2. **For Production:** Use the restrictive rules (second option)
3. **Monitor Usage:** Check Firebase Console → Storage → Usage regularly
4. **Set File Size Limits:** Consider adding file size validation in your app

## File Size Limits

You can add file size limits in your Flutter app:

```dart
// In storage_service.dart, before upload:
final int fileSize = await imageFile.length();
if (fileSize > 5 * 1024 * 1024) { // 5MB limit
  throw Exception('File size too large. Maximum 5MB allowed.');
}
```

