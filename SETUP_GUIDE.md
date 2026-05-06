# Setup Guide - True Hadith Flutter App

## Prerequisites

1. **Flutter SDK** (3.0.0 or higher)
   - Download from: https://flutter.dev/docs/get-started/install
   - Verify installation: `flutter doctor`

2. **Firebase Account**
   - Create account at: https://firebase.google.com/

3. **PostgreSQL Database**
   - Install PostgreSQL locally or use cloud service
   - Create database with the schema provided

4. **Python 3.8+** (for backend)
   - Download from: https://www.python.org/downloads/

## Step 1: Flutter Project Setup

### 1.1 Install Dependencies

```bash
# Navigate to project directory
cd "C:\Users\M.M\Documents\true hadith"

# Get Flutter packages
flutter pub get
```

### 1.2 Configure Firebase

#### Option A: Using Firebase CLI (Recommended)

1. Install Firebase CLI:
   ```bash
   npm install -g firebase-tools
   ```

2. Login to Firebase:
   ```bash
   firebase login
   ```

3. Initialize Firebase in your project:
   ```bash
   flutterfire configure
   ```
   This will create `firebase_options.dart` automatically.

#### Option B: Manual Setup

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create a new project or select existing one
3. Add Android/iOS apps:
   - **Android**: Register app with package name from `android/app/build.gradle`
   - **iOS**: Register app with bundle ID from `ios/Runner.xcodeproj`
4. Download configuration files:
   - Android: `google-services.json` → place in `android/app/`
   - iOS: `GoogleService-Info.plist` → place in `ios/Runner/`
5. Enable Authentication:
   - Go to Authentication → Sign-in method
   - Enable "Email/Password"

6. Create `lib/firebase_options.dart`:
   ```dart
   import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
   import 'package:flutter/foundation.dart'
       show defaultTargetPlatform, kIsWeb, TargetPlatform;

   class DefaultFirebaseOptions {
     static FirebaseOptions get currentPlatform {
       if (kIsWeb) {
         throw UnsupportedError('Web not supported');
       }
       switch (defaultTargetPlatform) {
         case TargetPlatform.android:
           return android;
         case TargetPlatform.iOS:
           return ios;
         default:
           throw UnsupportedError('Platform not supported');
       }
     }

     static const FirebaseOptions android = FirebaseOptions(
       apiKey: 'YOUR_ANDROID_API_KEY',
       appId: 'YOUR_ANDROID_APP_ID',
       messagingSenderId: 'YOUR_SENDER_ID',
       projectId: 'YOUR_PROJECT_ID',
       storageBucket: 'YOUR_STORAGE_BUCKET',
     );

     static const FirebaseOptions ios = FirebaseOptions(
       apiKey: 'YOUR_IOS_API_KEY',
       appId: 'YOUR_IOS_APP_ID',
       messagingSenderId: 'YOUR_SENDER_ID',
       projectId: 'YOUR_PROJECT_ID',
       storageBucket: 'YOUR_STORAGE_BUCKET',
       iosBundleId: 'YOUR_BUNDLE_ID',
     );
   }
   ```

7. Update `lib/main.dart`:
   ```dart
   import 'firebase_options.dart';
   
   // In main():
   await Firebase.initializeApp(
     options: DefaultFirebaseOptions.currentPlatform,
   );
   ```

### 1.3 Update Backend URL

Edit `lib/services/api_service.dart`:

```dart
// For Android Emulator:
static const String baseUrl = 'http://10.0.2.2:5000/api';

// For iOS Simulator:
static const String baseUrl = 'http://localhost:5000/api';

// For Physical Device (replace with your computer's IP):
static const String baseUrl = 'http://192.168.1.100:5000/api';
```

**To find your IP address:**
- Windows: `ipconfig` → Look for IPv4 Address
- Mac/Linux: `ifconfig` or `ip addr`

## Step 2: Backend Setup (Flask)

### 2.1 Install Python Dependencies

```bash
# Create virtual environment (recommended)
python -m venv venv

# Activate virtual environment
# Windows:
venv\Scripts\activate
# Mac/Linux:
source venv/bin/activate

# Install dependencies
pip install flask flask-cors psycopg2-binary python-dotenv
```

### 2.2 Configure Database

1. Create `.env` file in project root:
   ```env
   DB_HOST=localhost
   DB_NAME=true_hadith_db
   DB_USER=postgres
   DB_PASSWORD=your_password
   DB_PORT=5432
   ```

2. Create PostgreSQL database:
   ```sql
   CREATE DATABASE true_hadith_db;
   ```

3. Create users table:
   ```sql
   CREATE TABLE users (
       user_id SERIAL PRIMARY KEY,
       FK_firebase_uid VARCHAR(255) UNIQUE NOT NULL,
       user_name VARCHAR(255) NOT NULL,
       name_email VARCHAR(255) NOT NULL,
       created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
   );
   ```

### 2.3 Run Backend Server

```bash
# Make sure you're in the project directory
python backend_api_example.py
```

The server should start on `http://localhost:5000`

**Test the API:**
```bash
curl http://localhost:5000/api/health
```

## Step 3: Run Flutter App

### 3.1 Check Connected Devices

```bash
# List available devices
flutter devices
```

### 3.2 Run the App

```bash
# Run on connected device/emulator
flutter run

# Or specify device
flutter run -d <device_id>

# Run in release mode (for production)
flutter run --release
```

## Step 4: Testing the Flow

### Test Sign Up:
1. Open app → Skip onboarding → Sign Up tab
2. Enter: Name, Email, Password
3. Should create Firebase account → Register in backend → Navigate to Home

### Test Login:
1. Use existing email/password
2. Should authenticate with Firebase → Get user data from backend → Navigate to Home

## Troubleshooting

### Firebase Issues:
- **"Firebase not initialized"**: Check `firebase_options.dart` exists and is imported
- **"Platform not supported"**: Make sure you've added Android/iOS apps in Firebase Console
- **Authentication errors**: Verify Email/Password is enabled in Firebase Console

### Backend Issues:
- **Connection refused**: Check backend is running and URL is correct
- **CORS errors**: Make sure `flask-cors` is installed and enabled
- **Database errors**: Verify PostgreSQL is running and credentials are correct

### Flutter Issues:
- **Package errors**: Run `flutter pub get`
- **Build errors**: Run `flutter clean` then `flutter pub get`
- **Device not found**: Start emulator or connect physical device

## Common Commands

```bash
# Flutter
flutter pub get          # Install dependencies
flutter clean           # Clean build files
flutter run             # Run app
flutter doctor          # Check Flutter setup

# Backend
python backend_api_example.py    # Run Flask server
pip install -r requirements.txt  # Install Python packages (if you create requirements.txt)
```

## Project Structure

```
true hadith/
├── lib/
│   ├── main.dart
│   ├── models/
│   │   └── user_model.dart
│   ├── screens/
│   │   ├── onboarding_screen.dart
│   │   ├── login_screen.dart
│   │   └── home_screen.dart
│   ├── services/
│   │   ├── auth_service.dart
│   │   └── api_service.dart
│   ├── utils/
│   │   └── apps_colors.dart
│   └── widgets/
│       └── custom_button.dart
├── backend_api_example.py
├── pubspec.yaml
└── README_AUTHENTICATION.md
```

## Next Steps

1. ✅ Set up Firebase Authentication
2. ✅ Configure backend API
3. ✅ Test authentication flow
4. ⏭️ Implement hadith verification features
5. ⏭️ Add OCR functionality
6. ⏭️ Integrate RAG model

## Support

If you encounter issues:
1. Check Flutter doctor: `flutter doctor -v`
2. Verify Firebase configuration
3. Check backend logs for errors
4. Review database connection settings

