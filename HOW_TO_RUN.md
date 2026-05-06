# How to Run True Hadith App

## Prerequisites

### Required Software:
1. **Flutter SDK** (latest stable version)
2. **Python 3.8+** (for backend)
3. **PostgreSQL** (database)
4. **Firebase Account** (for authentication)
5. **VS Code / Android Studio** (IDE)

---

## Step 1: Flutter Setup

### 1.1 Install Flutter Dependencies
```bash
# Navigate to project directory
cd "C:\Users\M.M\Documents\true hadith"

# Get Flutter packages
flutter pub get
```

### 1.2 Verify Flutter Installation
```bash
flutter doctor
```
Make sure all required components are installed (Android/iOS SDK, etc.)

---

## Step 2: Firebase Setup

### 2.1 Create Firebase Project
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Add Project"
3. Enter project name: "True Hadith"
4. Follow the setup wizard

### 2.2 Enable Authentication
1. In Firebase Console, go to **Authentication**
2. Click **Get Started**
3. Enable **Email/Password** authentication
4. Click **Save**

### 2.3 Add Flutter App to Firebase
1. In Firebase Console, click the **Flutter icon** (or Add App)
2. Register your app:
   - **Android**: Enter package name (e.g., `com.example.true_hadith`)
   - **iOS**: Enter bundle ID (e.g., `com.example.trueHadith`)
3. Download configuration files:
   - **Android**: `google-services.json` → Place in `android/app/`
   - **iOS**: `GoogleService-Info.plist` → Place in `ios/Runner/`

### 2.4 Install Firebase CLI (Optional but Recommended)
```bash
# Install Firebase CLI
npm install -g firebase-tools

# Login to Firebase
firebase login

# Initialize Firebase in your project
firebase init
```

### 2.5 Generate Firebase Options (Recommended)
```bash
# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Configure Firebase for Flutter
flutterfire configure
```
This will create `lib/firebase_options.dart` automatically.

### 2.6 Update main.dart
If you generated `firebase_options.dart`, update `lib/main.dart`:
```dart
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(const MyApp());
}
```

---

## Step 3: PostgreSQL Database Setup

### 3.1 Install PostgreSQL
- Download from [PostgreSQL Official Site](https://www.postgresql.org/download/)
- Install with default settings
- Remember your **postgres** user password

### 3.2 Create Database
```sql
-- Open PostgreSQL command line (psql) or pgAdmin

-- Connect to PostgreSQL
psql -U postgres

-- Create database
CREATE DATABASE true_hadith_db;

-- Connect to database
\c true_hadith_db

-- Create users table
CREATE TABLE users (
    user_id SERIAL PRIMARY KEY,
    FK_firebase_uid VARCHAR(255) UNIQUE NOT NULL,
    user_name VARCHAR(255) NOT NULL,
    name_email VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create user_type table
CREATE TABLE user_type (
    user_type_id SERIAL PRIMARY KEY,
    user_type_name VARCHAR(50) NOT NULL
);

-- Insert user types
INSERT INTO user_type (user_type_name) VALUES ('user'), ('bot');

-- Verify tables
\dt
```

### 3.3 Create .env File for Backend
Create `backend/.env` file:
```env
DB_HOST=localhost
DB_NAME=true_hadith_db
DB_USER=postgres
DB_PASSWORD=your_postgres_password
DB_PORT=5432
```

---

## Step 4: Backend Setup (Flask)

### 4.1 Create Virtual Environment (Recommended)
```bash
# Navigate to project root
cd "C:\Users\M.M\Documents\true hadith"

# Create virtual environment
python -m venv venv

# Activate virtual environment
# Windows:
venv\Scripts\activate
# Mac/Linux:
source venv/bin/activate
```

### 4.2 Install Python Dependencies
```bash
pip install -r requirements.txt
```

Or install manually:
```bash
pip install flask flask-cors psycopg2-binary python-dotenv
```

### 4.3 Update Backend API URL
Edit `lib/services/api_service.dart`:
```dart
// For Android Emulator:
static const String baseUrl = 'http://10.0.2.2:5000/api';

// For iOS Simulator:
static const String baseUrl = 'http://localhost:5000/api';

// For Physical Device (use your computer's IP):
// Find your IP: ipconfig (Windows) or ifconfig (Mac/Linux)
static const String baseUrl = 'http://192.168.1.XXX:5000/api';
```

### 4.4 Run Flask Backend
```bash
# Make sure virtual environment is activated
python backend_api_example.py
```

You should see:
```
 * Running on http://0.0.0.0:5000
```

**Keep this terminal open!** The backend must be running for the app to work.

---

## Step 5: Run Flutter App

### 5.1 Check Connected Devices
```bash
# List connected devices/emulators
flutter devices
```

### 5.2 Run on Android Emulator
```bash
# Start Android emulator first (from Android Studio)
# Then run:
flutter run
```

### 5.3 Run on iOS Simulator (Mac only)
```bash
# Open iOS Simulator
open -a Simulator

# Run app
flutter run
```

### 5.4 Run on Physical Device
```bash
# Connect device via USB
# Enable USB debugging (Android) or Developer Mode (iOS)
flutter run
```

---

## Step 6: Testing the App

### 6.1 Test Sign Up Flow
1. App starts with **Onboarding Screen**
2. Swipe through or click "Skip"
3. On **Login Screen**, click "Sign Up" tab
4. Enter:
   - Name: "Test User"
   - Email: "test@example.com"
   - Password: "password123"
5. Click "Sign Up"
6. Should navigate to **Home Screen** showing user data

### 6.2 Test Login Flow
1. Sign out (if logged in)
2. On **Login Screen**, enter:
   - Email: "test@example.com"
   - Password: "password123"
3. Click "Login"
4. Should navigate to **Home Screen** with user data

---

## Troubleshooting

### Issue: Firebase not initialized
**Solution:**
- Make sure `google-services.json` (Android) or `GoogleService-Info.plist` (iOS) is in correct location
- Run `flutter clean` then `flutter pub get`
- Check Firebase console that Email/Password auth is enabled

### Issue: Cannot connect to backend
**Solution:**
- Make sure Flask backend is running (`python backend_api_example.py`)
- Check backend URL in `api_service.dart` matches your setup
- For physical device, ensure phone and computer are on same WiFi network
- Check firewall isn't blocking port 5000

### Issue: Database connection error
**Solution:**
- Verify PostgreSQL is running
- Check `.env` file has correct database credentials
- Test connection: `psql -U postgres -d true_hadith_db`

### Issue: Flutter packages not found
**Solution:**
```bash
flutter clean
flutter pub get
flutter pub upgrade
```

### Issue: Build errors
**Solution:**
```bash
# Clean build
flutter clean

# Get packages
flutter pub get

# Rebuild
flutter run
```

---

## Quick Start Commands Summary

```bash
# Terminal 1: Start Backend
cd "C:\Users\M.M\Documents\true hadith"
python -m venv venv
venv\Scripts\activate
pip install -r requirements.txt
python backend_api_example.py

# Terminal 2: Run Flutter App
cd "C:\Users\M.M\Documents\true hadith"
flutter pub get
flutter run
```

---

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
├── requirements.txt
└── README_AUTHENTICATION.md
```

---

## Next Steps

1. ✅ Complete Firebase setup
2. ✅ Set up PostgreSQL database
3. ✅ Configure backend API URL
4. ✅ Run backend server
5. ✅ Run Flutter app
6. ✅ Test authentication flow

---

## Need Help?

- Check `README_AUTHENTICATION.md` for authentication flow details
- Check `backend_api_example.py` for backend API structure
- Flutter docs: https://flutter.dev/docs
- Firebase docs: https://firebase.google.com/docs

