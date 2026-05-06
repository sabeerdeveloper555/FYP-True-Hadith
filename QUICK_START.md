# Quick Start Guide

## 🚀 Fastest Way to Run

### Option 1: Using Scripts (Easiest)

**Windows:**
```bash
# Double-click or run:
start_backend.bat
```

**Mac/Linux:**
```bash
chmod +x start_backend.sh
./start_backend.sh
```

Then in another terminal:
```bash
flutter run
```

---

### Option 2: Manual Steps

#### Step 1: Start Backend (Terminal 1)
```bash
# Navigate to project
cd "C:\Users\M.M\Documents\true hadith"

# Create and activate virtual environment
python -m venv venv
venv\Scripts\activate  # Windows
# OR: source venv/bin/activate  # Mac/Linux

# Install dependencies
pip install -r requirements.txt

# Run backend
python backend_api_example.py
```

#### Step 2: Run Flutter App (Terminal 2)
```bash
# Navigate to project
cd "C:\Users\M.M\Documents\true hadith"

# Get packages
flutter pub get

# Run app
flutter run
```

---

## ⚙️ Before First Run

### 1. Set Up Firebase
- Create Firebase project at https://console.firebase.google.com/
- Enable Email/Password authentication
- Download `google-services.json` (Android) or `GoogleService-Info.plist` (iOS)
- Place in `android/app/` or `ios/Runner/` respectively

### 2. Set Up PostgreSQL
- Install PostgreSQL
- Create database:
```sql
CREATE DATABASE true_hadith_db;
```
- Create users table (see `HOW_TO_RUN.md` for full SQL)

### 3. Configure Backend URL
Edit `lib/services/api_service.dart`:
- **Android Emulator**: `http://10.0.2.2:5000/api`
- **iOS Simulator**: `http://localhost:5000/api`
- **Physical Device**: `http://YOUR_COMPUTER_IP:5000/api`

---

## 📱 Testing

1. **Sign Up**: Create a new account
2. **Login**: Sign in with existing account
3. **Home Screen**: Should show user ID, username, and creation date

---

## 🐛 Common Issues

**Backend not connecting?**
- Make sure backend is running on port 5000
- Check firewall settings
- Verify API URL in `api_service.dart`

**Firebase errors?**
- Verify `google-services.json` is in correct location
- Check Firebase console that Email/Password auth is enabled

**Database errors?**
- Ensure PostgreSQL is running
- Check database credentials in `.env` file (create if needed)

---

For detailed instructions, see `HOW_TO_RUN.md`
