# 📱 Fix: Password Reset on Mobile Device

## ❌ Problem
When clicking the password reset link on a mobile device, it tries to open `http://localhost/reset-password`, but `localhost` on the mobile device refers to the device itself, not your laptop/server.

## ✅ Solution: Use Your Laptop's IP Address

### Step 1: Find Your Laptop's IP Address

**On Windows:**
```bash
ipconfig
```
Look for **IPv4 Address** under your active network adapter (usually starts with `192.168.x.x` or `10.0.x.x`)

**On Mac/Linux:**
```bash
ifconfig
# or
ip addr
```

Example IP: `192.168.0.104` (use YOUR actual IP)

### Step 2: Add IP Address to Firebase Authorized Domains

1. Go to Firebase Console → Authentication → Settings
2. Scroll to **Authorized domains**
3. Click **Add domain**
4. Enter your IP address (e.g., `192.168.0.104`)
5. Click **Add**

### Step 3: Update Firebase Console Template

1. Go to Firebase Console → Authentication → Templates → Password reset
2. In **Action URL** field, enter:
   ```
   http://YOUR_IP_ADDRESS/reset-password
   ```
   Example: `http://192.168.0.104/reset-password`
3. Click **Save**

### Step 4: Update Your Code

Update `lib/screens/login_screen.dart` line ~300:

```dart
await AuthService.sendPasswordResetEmail(
  email,
  continueUrl: 'http://YOUR_IP_ADDRESS/reset-password', // Replace with your IP
);
```

**Important:** Make sure your laptop and mobile device are on the same Wi-Fi network!

---

## 🔄 Alternative: Use Firebase Default Handler

If you don't want to use IP addresses, you can use Firebase's default handler:

1. **Remove the continueUrl** (already done in code)
2. **Reset Firebase Console Template** to default (or leave it as is)
3. The link will be: `https://true-hadith.firebaseapp.com/__/auth/action?mode=resetPassword&oobCode=CODE`
4. This will open in the browser
5. User can copy the action code and enter it manually in the app

---

## 📝 Quick Reference

| Item | Value |
|------|-------|
| Laptop IP | `192.168.0.104` (example - use YOUR IP) |
| Reset URL | `http://192.168.0.104/reset-password` |
| Firebase Console | Authentication → Templates → Password reset → Action URL |
| Authorized Domain | Add your IP address |

---

## ⚠️ Important Notes

1. **IP Address Changes**: Your laptop's IP may change when you reconnect to Wi-Fi. You'll need to update Firebase Console and code if it changes.

2. **Same Network**: Your laptop and mobile device must be on the same Wi-Fi network.

3. **Firewall**: Make sure your laptop's firewall allows connections on the port (if you're running a web server).

4. **For Production**: Use a real domain with App Links/Universal Links instead of IP addresses.

