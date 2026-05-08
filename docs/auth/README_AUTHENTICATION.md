# Authentication Flow Documentation

## Overview
This document explains the authentication flow between Flutter app, Firebase Authentication, and PostgreSQL backend.

## Flow Diagram

### Sign Up Flow:
```
1. User enters: email, password, username
2. Flutter → Firebase: Create user account
3. Firebase → Flutter: Returns firebase_uid
4. Flutter → Backend API: POST /api/auth/register
   Body: { firebase_uid, username, email }
5. Backend → PostgreSQL: Insert into users table
6. Backend → Flutter: Returns { user_id, username, created_at }
7. Flutter → HomeScreen: Navigate with user data
```

### Login Flow:
```
1. User enters: email, password
2. Flutter → Firebase: Sign in user
3. Firebase → Flutter: Returns firebase_uid
4. Flutter → Backend API: POST /api/auth/login
   Body: { firebase_uid }
5. Backend → PostgreSQL: Query users table by firebase_uid
6. Backend → Flutter: Returns { user_id, username, created_at }
7. Flutter → HomeScreen: Navigate with user data
```

## Files Created

### Flutter App Files:
1. **lib/models/user_model.dart** - User data model
2. **lib/services/api_service.dart** - HTTP client for backend communication
3. **lib/services/auth_service.dart** - Firebase + Backend integration
4. **lib/screens/login_screen.dart** - Updated login screen
5. **lib/screens/home_screen.dart** - Home screen that receives user data
6. **lib/utils/apps_colors.dart** - Color constants
7. **lib/widgets/custom_button.dart** - Reusable button widget

### Backend Example:
- **backend_api_example.py** - Flask API endpoints example

## Configuration

### Flutter App:
1. Update `lib/services/api_service.dart` with your backend URL:
   ```dart
   static const String baseUrl = 'http://YOUR_IP:5000/api';
   ```
   
   - Android Emulator: `http://10.0.2.2:5000/api`
   - iOS Simulator: `http://localhost:5000/api`
   - Physical Device: `http://YOUR_COMPUTER_IP:5000/api`

2. Add dependencies to `pubspec.yaml`:
   ```yaml
   dependencies:
     firebase_auth: ^latest_version
     http: ^latest_version
   ```

### Backend:
1. Install Python dependencies:
   ```bash
   pip install flask flask-cors psycopg2-binary python-dotenv
   ```

2. Set up environment variables (`.env` file):
   ```
   DB_HOST=localhost
   DB_NAME=true_hadith_db
   DB_USER=postgres
   DB_PASSWORD=your_password
   DB_PORT=5432
   ```

3. Run the Flask server:
   ```bash
   python backend_api_example.py
   ```

## Database Schema

The `users` table should have:
- `user_id` (PK, auto-generated)
- `FK_firebase_uid` (UNIQUE, NOT NULL)
- `user_name` (username)
- `name_email` (email)
- `created_at` (timestamp, auto-generated)

## API Endpoints

### POST /api/auth/register
**Request:**
```json
{
  "firebase_uid": "abc123...",
  "username": "John Doe",
  "email": "john@example.com"
}
```

**Response (201):**
```json
{
  "user_id": 1,
  "username": "John Doe",
  "created_at": "2025-12-16T10:30:00"
}
```

### POST /api/auth/login
**Request:**
```json
{
  "firebase_uid": "abc123..."
}
```

**Response (200):**
```json
{
  "user_id": 1,
  "username": "John Doe",
  "created_at": "2025-12-16T10:30:00"
}
```

## Error Handling

The app handles:
- Firebase authentication errors
- Network errors
- Backend API errors
- User not found errors

All errors are displayed to the user via SnackBar messages.

## Security Notes

1. Firebase handles password storage - no passwords in PostgreSQL
2. Backend validates firebase_uid before returning user data
3. CORS is enabled for Flutter app communication
4. All sensitive data should be transmitted over HTTPS in production

