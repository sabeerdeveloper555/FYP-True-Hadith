# Firebase Setup Guide - Quick Fix for Login Error

## 🔴 Current Error
You're seeing: **"api-key-not-valid.-please-pass-a-valid-api-key"**

This happens because `firebase_options.dart` contains placeholder values. You need to add your real Firebase credentials.

---

## ✅ Quick Solution (Choose One)

### Option 1: Using FlutterFire CLI (Easiest - Recommended)

1. **Install FlutterFire CLI:**
   ```bash
   dart pub global activate flutterfire_cli
   ```

2. **Run configuration:**
   ```bash
   flutterfire configure
   ```

3. **Follow the prompts:**
   - Select your Firebase project (or create a new one)
   - Choose platforms: **Web** (and others if needed)
   - The tool will automatically update `lib/firebase_options.dart` with correct values

4. **Restart your app:**
   ```bash
   flutter run
   ```

---

### Option 2: Manual Setup from Firebase Console

#### Step 1: Get Firebase Web Configuration

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project (or create a new one)
3. Click the **⚙️ gear icon** → **Project Settings**
4. Scroll down to **"Your apps"** section
5. Click the **`</>` (Web)** icon to add a web app
6. Register your app:
   - App nickname: `True Hadith Web`
   - (Don't check "Also set up Firebase Hosting" unless you need it)
7. Click **Register app**
8. You'll see a config object like this:
   ```javascript
   const firebaseConfig = {
     apiKey: "AIzaSyXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
     authDomain: "your-project-id.firebaseapp.com",
     projectId: "your-project-id",
     storageBucket: "your-project-id.appspot.com",
     messagingSenderId: "123456789012",
     appId: "1:123456789012:web:abcdef123456"
   };
   ```

#### Step 2: Update firebase_options.dart

Open `lib/firebase_options.dart` and replace the placeholder values:

```dart
static const FirebaseOptions web = FirebaseOptions(
  apiKey: 'AIzaSyXXXXXXXXXXXXXXXXXXXXXXXXXXXXX', // From firebaseConfig.apiKey
  appId: '1:123456789012:web:abcdef123456',      // From firebaseConfig.appId
  messagingSenderId: '123456789012',              // From firebaseConfig.messagingSenderId
  projectId: 'your-project-id',                   // From firebaseConfig.projectId
  authDomain: 'your-project-id.firebaseapp.com', // From firebaseConfig.authDomain
  storageBucket: 'your-project-id.appspot.com',   // From firebaseConfig.storageBucket
);
```

#### Step 3: Enable Email/Password Authentication

1. In Firebase Console, go to **Authentication**
2. Click **Get Started** (if first time)
3. Go to **Sign-in method** tab
4. Click **Email/Password**
5. Enable **Email/Password** (toggle ON)
6. Click **Save**

#### Step 4: Restart Your App

```bash
flutter run
```

---

## 🧪 Test Your Setup

1. Run the app: `flutter run`
2. Try to sign up with a new email/password
3. If successful, you should see "Account created!" message
4. Try logging in with the same credentials

---

## 🐛 Troubleshooting

### Still seeing "api-key-not-valid" error?
- ✅ Double-check you copied the values correctly (no extra spaces)
- ✅ Make sure you're using the **Web app** config (not Android/iOS)
- ✅ Verify the values are inside quotes: `'your-value'`
- ✅ Restart the app after making changes

### "Firebase not initialized" error?
- ✅ Check that `firebase_options.dart` exists in `lib/` folder
- ✅ Verify `main.dart` imports `firebase_options.dart`
- ✅ Make sure `DefaultFirebaseOptions.currentPlatform` is used

### Authentication not working?
- ✅ Verify Email/Password is enabled in Firebase Console
- ✅ Check Firebase Console → Authentication → Users (to see if users are created)
- ✅ Check browser console for additional error messages

---

## 📝 Example: What Your firebase_options.dart Should Look Like

```dart
static const FirebaseOptions web = FirebaseOptions(
  apiKey: 'AIzaSyC1234567890abcdefghijklmnopqrstuvwxyz',
  appId: '1:123456789012:web:abcdef1234567890',
  messagingSenderId: '123456789012',
  projectId: 'true-hadith-app',
  authDomain: 'true-hadith-app.firebaseapp.com',
  storageBucket: 'true-hadith-app.appspot.com',
);
```

**Note:** These are example values. Use YOUR actual values from Firebase Console!

---

## 💡 Need Help?

If you're still stuck:
1. Check the browser console (F12) for detailed error messages
2. Verify your Firebase project is active and billing is enabled (if required)
3. Make sure you're logged into the correct Firebase account
