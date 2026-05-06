# 🔧 Firebase Configuration for Your App

## Your App URL
**Your app is running at:** `http://localhost:65007/`

## ✅ What to Put in Firebase Console

### Step-by-Step Instructions:

1. **Go to Firebase Console:**
   - Open: https://console.firebase.google.com/
   - Select project: **true-hadith**

2. **Navigate to Password Reset Template:**
   - Click **Authentication** (left sidebar)
   - Click **Templates** tab (at the top)
   - Click **Password reset** template

3. **Set the Action URL:**
   - Find the **Action URL** field
   - Enter this **EXACT URL** (copy and paste):
   ```
   http://localhost:65007/reset-password
   ```
   ⚠️ **Important:**
   - No trailing slash at the end
   - Use `http://` not `https://`
   - Port number is `65007` (your port)
   - Must end with `/reset-password`

4. **Click Save**

5. **Verify Authorized Domains:**
   - Go to **Authentication** → **Settings**
   - Scroll to **Authorized domains**
   - Make sure `localhost` is listed
   - If not, click **Add domain** and add `localhost`

---

## 🧪 Test It

1. **Request a NEW password reset email** (old emails won't work)
   - Go to your app: http://localhost:65007
   - Click "Forgot Password?"
   - Enter your email
   - Click "Send Reset Link"

2. **Check your email** and click the reset link

3. **It should now open in your app** (not a new Chrome window!)

---

## 📝 Quick Reference

| Item | Value |
|------|-------|
| Your App URL | `http://localhost:65007` |
| Reset Password URL | `http://localhost:65007/reset-password` |
| Firebase Console Path | Authentication → Templates → Password reset → Action URL |
| Authorized Domain | `localhost` |

---

## ❌ Still Opening in New Window?

**Check these:**

1. ✅ Did you click **Save** in Firebase Console?
2. ✅ Did you request a **NEW** reset email after saving?
3. ✅ Is the URL exactly: `http://localhost:65007/reset-password` (no typos)?
4. ✅ Is `localhost` in Authorized domains?
5. ✅ Is your app still running at `http://localhost:65007`?

**If still not working:**
- Clear browser cache
- Request a fresh reset email
- Check browser console (F12) for errors

