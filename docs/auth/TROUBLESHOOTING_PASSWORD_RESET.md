# 🔧 Troubleshooting: "This site can't be reached" Error

## ❌ Problem
When you click the password reset link, you get:
**"This site can't be reached"** or **"ERR_CONNECTION_REFUSED"**

## ✅ Solutions

### Solution 1: Make Sure Your App is Running

**The most common cause:** Your Flutter app must be running when you click the link!

1. **Before clicking the reset link:**
   - Make sure your app is running: `flutter run -d chrome`
   - Your app should be open at: `http://localhost:65007`

2. **Then click the reset link** from your email

3. **If the app isn't running:**
   - The browser tries to connect to `http://localhost:65007`
   - But nothing is listening on that port
   - Result: "This site can't be reached"

---

### Solution 2: Check Firebase Console Action URL

**Make sure the Action URL in Firebase Console is EXACTLY:**

```
http://localhost:65007/reset-password
```

**Steps:**
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Authentication → Templates → Password reset
3. Check the **Action URL** field
4. It should be: `http://localhost:65007/reset-password`
5. **No trailing slash!**
6. Click **Save**

---

### Solution 3: Check the Email Link Format

**The link in your email should look like:**
```
http://localhost:65007/reset-password?mode=resetPassword&oobCode=ABC123&apiKey=XYZ
```

**If it looks different:**
- The Action URL in Firebase Console is wrong
- Request a NEW reset email after fixing Firebase Console

---

### Solution 4: Verify Port Number

**Your app URL:** `http://localhost:65007`

**Check:**
1. Is your app actually running on port `65007`?
2. Check the browser address bar when app is open
3. Check terminal output when running `flutter run -d chrome`

**If port changed:**
- Update Firebase Console with the new port
- Request a new reset email

---

### Solution 5: Check Authorized Domains

1. Firebase Console → Authentication → Settings
2. Scroll to **Authorized domains**
3. Make sure `localhost` is listed
4. If not, click **Add domain** and add `localhost`

---

## 🧪 Step-by-Step Test

1. **Start your app:**
   ```bash
   flutter run -d chrome
   ```

2. **Verify app is running:**
   - App should open at: `http://localhost:65007`
   - Check browser address bar

3. **Configure Firebase Console:**
   - Action URL: `http://localhost:65007/reset-password`
   - Save

4. **Request NEW reset email:**
   - Go to your app
   - Click "Forgot Password?"
   - Enter email
   - Click "Send Reset Link"

5. **Check your email:**
   - Open the reset email
   - Look at the link - it should start with: `http://localhost:65007/reset-password`

6. **Click the link:**
   - **Make sure your app is still running!**
   - Click the link
   - It should open in your app (or same browser tab)

---

## 🔍 Debug Checklist

- [ ] App is running at `http://localhost:65007`
- [ ] Firebase Console Action URL is: `http://localhost:65007/reset-password`
- [ ] No trailing slash in Action URL
- [ ] `localhost` is in Authorized domains
- [ ] Requested a NEW reset email after configuring Firebase
- [ ] Port number matches (65007)
- [ ] Using `http://` not `https://` for localhost

---

## 💡 Common Mistakes

### ❌ Wrong:
```
http://localhost:65007/reset-password/  (trailing slash)
https://localhost:65007/reset-password  (https instead of http)
http://localhost:5000/reset-password    (wrong port)
http://127.0.0.1:65007/reset-password  (127.0.0.1 instead of localhost)
```

### ✅ Correct:
```
http://localhost:65007/reset-password
```

---

## 🆘 Still Not Working?

1. **Check browser console (F12):**
   - Look for errors
   - Check Network tab

2. **Check Flutter debug console:**
   - Look for URL parsing errors
   - Check if action code is detected

3. **Try manually:**
   - Copy the link from email
   - Make sure app is running
   - Paste link in browser address bar
   - Press Enter

4. **Clear browser cache:**
   - Sometimes old URLs are cached
   - Clear cache and try again

---

## 📝 Quick Fix Summary

1. ✅ **App must be running** at `http://localhost:65007`
2. ✅ **Firebase Console** → Action URL = `http://localhost:65007/reset-password`
3. ✅ **Request NEW email** after configuring Firebase
4. ✅ **Click link** while app is running

---

## 🎯 Expected Behavior

**When working correctly:**
1. You click the reset link
2. Browser opens/navigates to: `http://localhost:65007/reset-password?mode=resetPassword&oobCode=...`
3. Your Flutter app handles the URL
4. Reset Password screen opens automatically
5. You can enter your new password

**If you see "This site can't be reached":**
- App is not running, OR
- Wrong URL in Firebase Console, OR
- Wrong port number

