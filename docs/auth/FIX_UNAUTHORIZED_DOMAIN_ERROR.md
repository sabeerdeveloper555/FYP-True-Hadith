# 🔧 Fix: Unauthorized Domain Error

## ❌ Error Message
```
Error: An error occured: unauthorized-domain: The configured custom domain is not allowlisted. 
Please allowlist the domain in the firebase console -> Authentication -> setting -> authorized domain tab.
```

## ✅ Solution

The error occurs because Firebase requires **HTTP/HTTPS URLs** that are allowlisted in Firebase Console. Custom URL schemes (like `truehadith://`) cannot be used with `ActionCodeSettings`.

### Quick Fix (Applied)

I've updated the code to **not use ActionCodeSettings** for mobile apps. This means:
- ✅ The error will no longer occur
- ✅ Password reset emails will be sent successfully
- ⚠️ The link will open in the browser (Firebase's default behavior)

### How It Works Now

1. User clicks "Forgot Password?" and enters email
2. Firebase sends email with default reset link
3. Link format: `https://PROJECT.firebaseapp.com/__/auth/action?mode=resetPassword&oobCode=CODE`
4. Link opens in browser (Firebase's default handler)
5. User can copy the action code or use the browser interface

## 🎯 Better Solution: Make Links Open in App

To make password reset links open directly in your app, you have two options:

### Option 1: Use Allowlisted Web URL (Recommended for Development)

1. **Add `localhost` to Firebase Authorized Domains**:
   - Go to Firebase Console → Authentication → Settings
   - Scroll to **Authorized domains**
   - Add `localhost` if not already there

2. **Update the code to use localhost URL**:
   ```dart
   // In lib/screens/login_screen.dart, change:
   await AuthService.sendPasswordResetEmail(
     email,
     continueUrl: 'http://localhost/reset-password', // Use allowlisted domain
   );
   ```

3. **Update Firebase Console**:
   - Go to Authentication → Templates → Password reset
   - Set Action URL to: `http://localhost/reset-password`

### Option 2: Configure App Links/Universal Links (For Production)

This requires setting up proper domain verification:

1. **Get a domain** (e.g., `yourdomain.com`)
2. **Add domain to Firebase Authorized Domains**
3. **Configure Android App Links**:
   - Add `.well-known/assetlinks.json` to your domain
   - Update `AndroidManifest.xml` with your domain
4. **Configure iOS Universal Links**:
   - Add `.well-known/apple-app-site-association` to your domain
   - Update `Info.plist` with your domain
5. **Use your domain URL** in `ActionCodeSettings`

## 📝 Current Status

✅ **Error Fixed**: Code updated to not use custom URL scheme
✅ **Emails Send**: Password reset emails will now send successfully
⚠️ **Link Behavior**: Links will open in browser (Firebase default)

## 🔄 Next Steps

1. **Test the password reset flow**:
   - Request a password reset email
   - Verify email is sent (no error)
   - Click the link (will open in browser)

2. **If you want links to open in app**:
   - Follow Option 1 (for development) or Option 2 (for production)
   - Update the code as shown above

## 📚 Additional Notes

- The deep link handler in `main.dart` is still configured and will work if you set up App Links/Universal Links
- The URL handler supports Firebase's default link format
- For now, users can use the browser interface or manually copy the action code

---

**Current Implementation**: Password reset emails send successfully, but links open in browser (Firebase default behavior).

