# 📱 Password Reset for Mobile Apps

## How Password Reset Works on Mobile

When using the app on **Android** or **iOS**, the password reset flow works differently than on web.

---

## ✅ Option 1: Use Reset Link in Email (Recommended)

### Steps:

1. **Click "Forgot Password?"** in the app
2. **Enter your email** and click "Send Reset Link"
3. **Check your email** on your phone
4. **Click the reset link** in the email
5. **The link opens in your browser** (Chrome/Safari)
6. **Firebase shows a page** where you can reset your password
7. **Enter your new password** and confirm
8. **Go back to the app** and login with your new password

**This is the simplest method** - Firebase handles everything in the browser.

---

## ✅ Option 2: Manual Code Entry (For Mobile)

If you prefer to stay in the app, you can manually enter the reset code:

### Steps:

1. **Click "Forgot Password?"** in the app
2. **Enter your email** and click "Send Reset Link"
3. **Check your email** on your phone
4. **Look for the reset code** in the email link
   - The link looks like: `https://...?oobCode=ABC123XYZ...`
   - Copy the code after `oobCode=` (the long alphanumeric string)
5. **In the app**, click **"Enter Reset Code"** (below "Forgot Password?")
6. **Paste the code** you copied from the email
7. **Click "Verify Code"**
8. **Enter your new password** and confirm

---

## 📧 Finding the Reset Code in Email

The reset code is in the email link. Here's how to find it:

### Example Email Link:
```
https://true-hadith.firebaseapp.com/__/auth/action?mode=resetPassword&oobCode=ABC123XYZ456DEF789&apiKey=...
```

### The Code You Need:
The part after `oobCode=` - in this example: `ABC123XYZ456DEF789`

**How to copy it:**
1. Long-press on the link in your email
2. Select "Copy link" or "Copy"
3. Paste it somewhere (Notes app, etc.)
4. Find the part that starts after `oobCode=`
5. Copy just that code (it's a long string of letters and numbers)

---

## 🔄 Complete Mobile Flow

### Method 1: Browser (Easiest)
```
App → Forgot Password → Email Sent
Email → Click Link → Browser Opens
Browser → Enter New Password → Done
App → Login with New Password
```

### Method 2: Manual Code (Stay in App)
```
App → Forgot Password → Email Sent
Email → Copy Code from Link
App → Enter Reset Code → Verify
App → Enter New Password → Done
App → Login with New Password
```

---

## 💡 Tips for Mobile Users

1. **Keep the app open** while checking email
2. **Copy the code carefully** - it's case-sensitive
3. **Codes expire after 1 hour** - use it quickly
4. **Each code can only be used once** - request a new one if needed
5. **Check spam folder** if email doesn't arrive

---

## ❓ Troubleshooting

### Email not received?
- ✅ Check spam/junk folder
- ✅ Verify email is registered in Firebase
- ✅ Wait a few minutes (emails can be delayed)
- ✅ Request a new reset email

### Code not working?
- ✅ Make sure you copied the entire code
- ✅ Check for typos (code is case-sensitive)
- ✅ Code might be expired (request a new one)
- ✅ Code might already be used (request a new one)

### Link opens but can't reset?
- ✅ Make sure you're using the latest code
- ✅ Try requesting a fresh reset email
- ✅ Clear browser cache and try again

---

## 🎯 Quick Reference

| Action | Location |
|--------|----------|
| Request Reset | App → Login → "Forgot Password?" |
| Enter Code Manually | App → Login → "Enter Reset Code" |
| Find Code | Email link → After `oobCode=` |
| Reset in Browser | Email → Click link → Browser opens |

---

## 📝 Notes

- **For web apps**: Links open directly in the app
- **For mobile apps**: Links open in browser (or use manual code entry)
- **Both methods work** - choose what's easier for you
- **Codes expire in 1 hour** - use them quickly

---

## 🆘 Still Need Help?

1. **Try Method 1** (browser) - it's the simplest
2. **If that doesn't work**, try Method 2 (manual code)
3. **Request a fresh reset email** if code is expired
4. **Check your email** is correct in Firebase Console

