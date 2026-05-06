# 🔗 How to Find Your App URL and Fix Password Reset Links

## ❌ Problem
When you click the password reset link, it opens in a **new Chrome window** instead of staying in your app.

## ✅ Solution
You need to configure Firebase Console with your app's URL. Here's how:

---

## 📍 Quick Answer: Where to Find Your App URL

**When your Flutter app is running:**

1. **Look at your browser's address bar** - that's your app URL!
   - Example: `http://localhost:5000`
   - Example: `http://localhost:65007` ← **This is YOUR app URL!**

2. **Or check the terminal** when you run `flutter run -d chrome`
   - It shows: `An Observatory debugger... at: http://127.0.0.1:XXXXX`

3. **Your reset password URL = Your app URL + `/reset-password`**
   - If app is at: `http://localhost:65007` ← **YOUR URL**
   - Then use: `http://localhost:65007/reset-password` ← **PUT THIS IN FIREBASE!**

---

## Step 1: Find Your App's URL

### When Running Flutter Web App:

1. **Run your app:**
   ```bash
   flutter run -d chrome
   ```

2. **Look at the terminal output.** You'll see something like:
   ```
   Flutter run key commands.
   ...
   An Observatory debugger and profiler on Chrome is available at: http://127.0.0.1:XXXXX
   ```

3. **Or check the browser address bar** when the app opens. It will show:
   ```
   http://localhost:XXXXX
   ```
   or
   ```
   http://127.0.0.1:XXXXX
   ```

4. **Your app URL is:** `http://localhost:XXXXX` (replace XXXXX with your port number)

   Common ports:
   - `http://localhost:5000`
   - `http://localhost:8080`
   - `http://localhost:XXXXX` (random port assigned by Flutter)

### Example:
If your app opens at `http://localhost:5000`, then your reset password URL should be:
```
http://localhost:5000/reset-password
```

---

## Step 2: Configure Firebase Console

### 2.1 Go to Firebase Console

1. Open [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **true-hadith**

### 2.2 Navigate to Email Templates

1. Click **Authentication** (left sidebar)
2. Click **Templates** tab (at the top)
3. Click **Password reset** template

### 2.3 Set the Action URL

1. Find the **Action URL** field
2. Enter your app's reset password URL:

   **For Development (Local):**
   ```
   http://localhost:5000/reset-password
   ```
   ⚠️ **Replace `5000` with YOUR actual port number!**

   **For Production:**
   ```
   https://your-domain.com/reset-password
   ```

3. **IMPORTANT:** Make sure the URL:
   - ✅ Starts with `http://` (for local) or `https://` (for production)
   - ✅ Includes your port number (for local development)
   - ✅ Ends with `/reset-password` (exactly as shown)
   - ✅ No trailing slash

4. Click **Save**

### 2.4 Verify Authorized Domains

1. Still in Firebase Console, go to **Authentication** → **Settings**
2. Scroll to **Authorized domains**
3. Make sure `localhost` is listed (for development)
4. If not, click **Add domain** and add `localhost`

---

## Step 3: Test the Flow

1. **Run your app:**
   ```bash
   flutter run -d chrome
   ```

2. **Note the URL** from the browser (e.g., `http://localhost:5000`)

3. **Update Firebase Console** with that exact URL + `/reset-password`

4. **Test:**
   - Click "Forgot Password?" in your app
   - Enter your email
   - Check your email inbox
   - Click the reset link
   - **It should now open in your app, not a new window!**

---

## Step 4: Check the Debug Console

When you send a password reset email, check your browser's **Developer Console** (F12). You should see:

```
🔗 Password reset URL: http://localhost:5000/reset-password
📧 Make sure this URL is set in Firebase Console → Authentication → Templates → Password reset → Action URL
```

**Copy this exact URL** and paste it into Firebase Console!

---

## Troubleshooting

### ❌ Link still opens in new window?

**Check:**
1. ✅ Firebase Console → Authentication → Templates → Password reset
   - Action URL matches your app URL exactly
   - No typos or extra characters
   - Includes `/reset-password` at the end

2. ✅ Firebase Console → Authentication → Settings → Authorized domains
   - `localhost` is listed (for development)

3. ✅ Your app is running at the URL you configured
   - Check browser address bar
   - URL should match what's in Firebase Console

4. ✅ Try requesting a NEW reset email after updating Firebase Console
   - Old emails have old links
   - Request a fresh reset email

### ❌ "Invalid or expired reset code" error?

- Reset codes expire after 1 hour
- Each code can only be used once
- Request a new reset email

### ❌ Can't find the Action URL field?

1. Make sure you're in: **Authentication → Templates → Password reset**
2. Look for "Action URL" or "Custom action URL" field
3. If you don't see it, try clicking "Edit" or "Customize" button

---

## Quick Reference

### Your App URL Format:
```
http://localhost:PORT/reset-password
```

### Firebase Console Path:
```
Firebase Console → Authentication → Templates → Password reset → Action URL
```

### Where to Find Your Port:
- Check browser address bar when app is running
- Check terminal output when running `flutter run -d chrome`
- Usually: `5000`, `8080`, or a random port

---

## Still Having Issues?

1. **Check browser console** (F12) for errors
2. **Check Flutter debug console** for the reset URL
3. **Verify the URL** in Firebase Console matches exactly
4. **Request a fresh reset email** after making changes
5. **Clear browser cache** and try again

