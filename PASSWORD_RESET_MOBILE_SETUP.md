# 📱 Password Reset Setup for Mobile Devices

## ✅ Configuration Complete

Your password reset is now configured to work on mobile devices using your laptop's IP address.

## 📋 What You Need to Do in Firebase Console

### Step 1: Add IP Address to Authorized Domains

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **true-hadith**
3. Navigate to **Authentication** → **Settings**
4. Scroll to **Authorized domains**
5. Click **Add domain**
6. Enter: `192.168.0.104`
7. Click **Add**

### Step 2: Update Password Reset Template

1. Still in Firebase Console, go to **Authentication** → **Templates**
2. Click on **Password reset** template
3. In the **Action URL** field, enter:
   ```
   http://192.168.0.104/reset-password
   ```
4. Click **Save**

## ✅ Code Already Updated

The code has been updated to use your IP address:
- `lib/screens/login_screen.dart` - Now uses `http://192.168.0.104/reset-password`

## 🧪 How to Test

1. **Make sure your laptop and mobile device are on the same Wi-Fi network**

2. **Request a NEW password reset email**:
   - Open your app on mobile device
   - Go to login screen
   - Click "Forgot Password?"
   - Enter your email
   - Click "Send Reset Link"

3. **Check your email** and click the reset link

4. **Expected behavior**:
   - ✅ The app should open automatically
   - ✅ You should be navigated to Reset Password screen
   - ✅ Action code should be automatically extracted

## ⚠️ Important Notes

1. **Same Network Required**: Your laptop and mobile device must be on the same Wi-Fi network

2. **IP Address Changes**: If your laptop's IP address changes (when you reconnect to Wi-Fi), you'll need to:
   - Update Firebase Console → Authorized domains
   - Update Firebase Console → Templates → Password reset → Action URL
   - Update `lib/screens/login_screen.dart` line ~300

3. **No Web Server Needed**: You don't need to run a web server. The app will intercept the deep link directly.

4. **For Production**: Use a real domain with App Links/Universal Links instead of IP addresses.

## 🔍 Troubleshooting

### Link still opens in browser?
- ✅ Check that IP address is in Firebase Authorized domains
- ✅ Check that Action URL in Firebase Console matches: `http://192.168.0.104/reset-password`
- ✅ Request a NEW password reset email (old emails won't work)
- ✅ Make sure laptop and mobile are on same Wi-Fi network

### "This site can't be reached" error?
- ✅ This is normal - the app intercepts the link before it tries to load
- ✅ The app should still open and navigate to reset password screen
- ✅ Check debug console for: `🔗 Deep link received: ...`

### IP Address Changed?
- Find new IP: `ipconfig` (Windows) or `ifconfig` (Mac/Linux)
- Update Firebase Console (both Authorized domains and Action URL)
- Update `lib/screens/login_screen.dart` line ~300

---

**Current Configuration:**
- IP Address: `192.168.0.104`
- Reset URL: `http://192.168.0.104/reset-password`
- Status: ✅ Code updated, waiting for Firebase Console updates

