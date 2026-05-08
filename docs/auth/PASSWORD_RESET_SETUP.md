# Password Reset Link Configuration Guide

This guide explains how to configure Firebase so that password reset links redirect back to your app instead of using Firebase's default handler.

## Overview

When a user clicks "Forgot Password?", they receive an email with a reset link. By default, Firebase opens this link in a browser. We've configured the app to:

1. **Send password reset emails with a custom action URL** that points back to your app
2. **Handle the reset link** when users click it, extracting the action code from the URL
3. **Navigate to the Reset Password screen** automatically with the action code

## Step 1: Configure Firebase Console

### 1.1 Set Custom Action URL in Email Template

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **true-hadith**
3. Navigate to **Authentication** → **Templates**
4. Click on **Password reset** template
5. In the **Action URL** field, enter your app's URL:

   **For Web App (Development):**
   ```
   http://localhost:PORT/reset-password
   ```
   Replace `PORT` with your Flutter web app port (usually 5000, 8080, or auto-assigned)

   **For Web App (Production):**
   ```
   https://your-domain.com/reset-password
   ```
   Replace `your-domain.com` with your actual domain

6. Click **Save**

### 1.2 Configure Authorized Domains

1. In Firebase Console, go to **Authentication** → **Settings**
2. Scroll to **Authorized domains**
3. Ensure these domains are listed:
   - `localhost` (for development)
   - Your production domain (e.g., `your-domain.com`)
   - `true-hadith.firebaseapp.com` (default Firebase domain)
4. Add any custom domains if needed

### 1.3 Verify Email/Password Authentication is Enabled

1. Go to **Authentication** → **Sign-in method**
2. Ensure **Email/Password** is enabled (toggle ON)
3. Click **Save** if you made changes

## Step 2: How It Works

### User Flow:

1. **User clicks "Forgot Password?"** on login screen
2. **Dialog opens** → User enters email → Email sent with custom action URL
3. **User receives email** with reset link like:
   ```
   https://your-app.com/reset-password?mode=resetPassword&oobCode=ABC123&apiKey=XYZ
   ```
4. **User clicks link** → App opens and detects the URL parameters
5. **App extracts action code** (`oobCode`) from URL
6. **App navigates** to Reset Password screen with the action code
7. **User enters new password** → Password reset confirmed
8. **User redirected** to login screen

### Code Flow:

1. **`login_screen.dart`**: When sending reset email, builds custom `continueUrl`
2. **`auth_service.dart`**: Sends email with `ActionCodeSettings` containing the custom URL
3. **`main.dart`**: On app start, checks URL for password reset parameters
4. **`url_handler.dart`**: Extracts `oobCode` from URL query parameters
5. **`reset_password_screen.dart`**: Receives action code and allows password reset

## Step 3: Testing

### Test the Flow:

1. **Run your Flutter web app:**
   ```bash
   flutter run -d chrome
   ```

2. **Note the URL** where your app is running (e.g., `http://localhost:5000`)

3. **Update Firebase Console:**
   - Go to Authentication → Templates → Password reset
   - Set Action URL to: `http://localhost:5000/reset-password`
   - Save

4. **Test the flow:**
   - Go to login screen
   - Click "Forgot Password?"
   - Enter a registered email
   - Check your email inbox
   - Click the reset link
   - App should open and navigate to reset password screen
   - Enter new password and confirm

### Troubleshooting:

**Issue: Link opens in browser but doesn't navigate to app**
- ✅ Check that Action URL in Firebase Console matches your app URL
- ✅ Verify the URL format: `http://localhost:PORT/reset-password` (no trailing slash)
- ✅ Check browser console for errors

**Issue: Action code not detected**
- ✅ Check that URL contains `oobCode` parameter
- ✅ Verify `url_handler.dart` is correctly extracting the code
- ✅ Check debug console for "Password reset action code detected" message

**Issue: "Invalid or expired reset code" error**
- ✅ Reset codes expire after 1 hour (Firebase default)
- ✅ Request a new reset email
- ✅ Check that the code wasn't already used

**Issue: Email not received**
- ✅ Check spam folder
- ✅ Verify email is registered in Firebase Authentication
- ✅ Check Firebase Console → Authentication → Users
- ✅ Verify Email/Password authentication is enabled

## Step 4: Production Deployment

### For Production:

1. **Update Action URL in Firebase Console:**
   ```
   https://your-production-domain.com/reset-password
   ```

2. **Add your domain to Authorized Domains:**
   - Firebase Console → Authentication → Settings → Authorized domains
   - Add your production domain

3. **Update `login_screen.dart` if needed:**
   - The code automatically detects the current URL
   - For production, ensure your app is served from the correct domain

4. **Test in production:**
   - Deploy your app
   - Test the password reset flow
   - Verify links work correctly

## Technical Details

### URL Format:

Firebase password reset links have this format:
```
https://your-app.com/reset-password?mode=resetPassword&oobCode=ACTION_CODE&apiKey=API_KEY&continueUrl=CONTINUE_URL&lang=en
```

The app extracts:
- `oobCode`: The action code needed to reset the password
- `email`: User's email (if included in URL)

### Files Modified:

1. **`lib/services/auth_service.dart`**
   - Added `continueUrl` parameter to `sendPasswordResetEmail()`
   - Uses `ActionCodeSettings` for custom redirect URL

2. **`lib/screens/login_screen.dart`**
   - Builds custom `continueUrl` when sending reset email
   - Points to `/reset-password` route

3. **`lib/main.dart`**
   - Checks URL on app start for password reset parameters
   - Navigates to Reset Password screen if action code detected

4. **`lib/utils/url_handler.dart`** (NEW)
   - Utility functions to extract action code from URLs
   - Handles URL parsing and validation

5. **`lib/screens/reset_password_screen.dart`**
   - Receives action code and email
   - Verifies code and allows password reset

## Additional Notes

- **Action codes expire after 1 hour** (Firebase default)
- **Each code can only be used once**
- **The app automatically handles URL parsing** - no manual intervention needed
- **Works for both development and production** environments

## Support

If you encounter issues:
1. Check Firebase Console configuration
2. Verify URL format matches your app's URL structure
3. Check browser console for errors
4. Verify action code is being extracted correctly (check debug logs)

