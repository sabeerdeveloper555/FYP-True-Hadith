# 🔗 Deep Link Setup Guide for Password Reset

This guide explains how to configure your app so that password reset links open directly in your mobile app instead of a browser.

## ✅ What's Been Configured

1. **Deep linking package added**: `app_links` package for handling deep links
2. **Auth service updated**: Now uses `ActionCodeSettings` to send deep link URLs
3. **Android configured**: Custom URL scheme `truehadith://` added to AndroidManifest.xml
4. **iOS configured**: Custom URL scheme `truehadith://` added to Info.plist
5. **Deep link handler**: Added in `main.dart` to handle incoming links

## 📱 How It Works

1. User clicks "Forgot Password?" and enters their email
2. Firebase sends an email with a password reset link
3. The link uses the custom URL scheme: `truehadith://reset-password?oobCode=ACTION_CODE`
4. When user clicks the link, the app opens automatically
5. The app extracts the `oobCode` from the URL
6. User is navigated to the Reset Password screen
7. User enters new password and confirms

## 🔧 Configuration Steps

### Step 1: Update Package Names (if needed)

Check your actual package names and update them in `lib/services/auth_service.dart`:

**For Android:**
- Current: `com.example.true_hadith`
- Check: `android/app/src/main/AndroidManifest.xml` → `package` attribute

**For iOS:**
- Current: `com.example.trueHadith` (placeholder)
- Check: Open `ios/Runner.xcworkspace` in Xcode → Target → General → Bundle Identifier

Update these in `lib/services/auth_service.dart` lines 102-103 if they differ.

### Step 2: Install Dependencies

Run this command to install the new `app_links` package:

```bash
flutter pub get
```

### Step 3: Test the Setup

1. **Build and run your app** on a physical device or emulator:
   ```bash
   flutter run
   ```

2. **Request a password reset**:
   - Go to login screen
   - Click "Forgot Password?"
   - Enter a registered email
   - Click "Send Reset Link"

3. **Check your email** and click the reset link

4. **Expected behavior**:
   - ✅ App should open automatically (not browser)
   - ✅ You should be navigated to Reset Password screen
   - ✅ Action code should be automatically filled

## 🐛 Troubleshooting

### Issue: Link still opens in browser

**Solutions:**
1. **Check Firebase Console**:
   - Go to Firebase Console → Authentication → Templates → Password reset
   - The Action URL should be set to your custom scheme: `truehadith://reset-password`
   - ⚠️ **Important**: You need to request a NEW password reset email after changing this

2. **Verify package names**:
   - Make sure `androidPackageName` and `iOSBundleId` in `auth_service.dart` match your actual package names
   - Check Android: `android/app/src/main/AndroidManifest.xml`
   - Check iOS: Xcode project settings

3. **Test on physical device**:
   - Some emulators may not handle deep links correctly
   - Test on a real device for best results

### Issue: App opens but doesn't navigate to reset screen

**Solutions:**
1. **Check debug console** for deep link logs:
   - Look for: `🔗 Deep link received: ...`
   - Look for: `✅ Password reset action code detected: ...`

2. **Verify URL format**:
   - The link should be: `truehadith://reset-password?oobCode=CODE`
   - Check that `oobCode` parameter is present

3. **Check URL handler**:
   - Verify `lib/utils/url_handler.dart` is correctly extracting the action code

### Issue: "Invalid or expired reset code" error

**Solutions:**
1. Reset codes expire after 1 hour (Firebase default)
2. Request a new password reset email
3. Make sure the code hasn't been used already

## 📝 Firebase Console Configuration

### Option 1: Custom URL Scheme (Recommended for Development)

In Firebase Console → Authentication → Templates → Password reset:
- **Action URL**: `truehadith://reset-password`

This works immediately without domain verification.

### Option 2: Universal Links (For Production)

For production, you can use Universal Links (iOS) or App Links (Android):

1. **Set up a domain** (e.g., `https://yourdomain.com`)
2. **Configure Android App Links**:
   - Add `.well-known/assetlinks.json` to your domain
   - Update `AndroidManifest.xml` with your domain
   
3. **Configure iOS Universal Links**:
   - Add `.well-known/apple-app-site-association` to your domain
   - Update `Info.plist` with your domain

4. **Update Firebase Action URL** to: `https://yourdomain.com/reset-password`

## 🔍 Testing Deep Links Manually

You can test deep links manually using ADB (Android) or command line (iOS):

**Android:**
```bash
adb shell am start -W -a android.intent.action.VIEW -d "truehadith://reset-password?oobCode=TEST_CODE" com.example.true_hadith
```

**iOS (Simulator):**
```bash
xcrun simctl openurl booted "truehadith://reset-password?oobCode=TEST_CODE"
```

## 📚 Additional Resources

- [Firebase Auth Deep Links Documentation](https://firebase.google.com/docs/auth/custom-email-handler)
- [Flutter app_links Package](https://pub.dev/packages/app_links)
- [Android App Links](https://developer.android.com/training/app-links)
- [iOS Universal Links](https://developer.apple.com/documentation/xcode/supporting-universal-links-in-your-app)

## ✅ Checklist

- [ ] Installed `app_links` package (`flutter pub get`)
- [ ] Updated package names in `auth_service.dart` if needed
- [ ] Tested password reset flow on Android device
- [ ] Tested password reset flow on iOS device
- [ ] Verified Firebase Console Action URL is set correctly
- [ ] Confirmed deep links open app (not browser)
- [ ] Verified navigation to reset password screen works

---

**Note**: For the best user experience, test on physical devices. Some emulators may not handle deep links correctly.

