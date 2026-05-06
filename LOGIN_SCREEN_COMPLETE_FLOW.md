# Login Screen - Complete Flow Explanation

## 🔄 **SIGN UP FLOW (Complete Step-by-Step)**

### **Step 1: User Interaction**
```
User fills form:
  - Name: "John Doe"
  - Email: "john@example.com"
  - Password: "password123"
  
User clicks "Sign Up" button
```

### **Step 2: Form Validation (Frontend)**
**File: `lib/screens/login_screen.dart`**
```dart
Future<void> _handleSubmit() async {
  // Line 72: Validate form
  if (!_formKey.currentState!.validate()) return;
  
  // Validation checks:
  // - Name: Not empty
  // - Email: Contains '@' symbol
  // - Password: At least 6 characters
  
  // Line 74: Set loading state
  setState(() => _isLoading = true);
  // Button now shows loading spinner
```

**What happens:**
- Form validates all fields
- If validation fails → Shows error message, stops here
- If validation passes → Continues to next step
- Button shows loading spinner

### **Step 3: Call AuthService.signUp()**
**File: `lib/screens/login_screen.dart` (Line 109-113)**
```dart
userModel = await AuthService.signUp(
  name: _nameController.text.trim(),      // "John Doe"
  email: _emailController.text.trim(),    // "john@example.com"
  password: _passwordController.text,     // "password123"
);
```

**What happens:**
- Calls `AuthService.signUp()` method
- Passes trimmed name, email, and password
- Waits for response (async operation)

---

### **Step 4: Firebase User Creation**
**File: `lib/services/auth_service.dart` (Lines 17-28)**
```dart
// Step 1: Create user in Firebase
final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
  email: email,        // "john@example.com"
  password: password,  // "password123"
);

final User? firebaseUser = userCredential.user;
if (firebaseUser == null) {
  throw Exception('Failed to create Firebase user');
}

final String firebaseUid = firebaseUser.uid;  // Gets unique ID like "abc123xyz456"
```

**What happens:**
- Firebase receives email and password
- Firebase encrypts password (bcrypt)
- Firebase creates user account
- Firebase generates unique UID (like "abc123xyz456")
- Returns `UserCredential` object with user info

**Possible Errors:**
- `email-already-in-use`: Email already registered
- `weak-password`: Password too weak
- `invalid-email`: Email format invalid
- `network-request-failed`: No internet connection

---

### **Step 5: Update Firebase Display Name**
**File: `lib/services/auth_service.dart` (Lines 30-32)**
```dart
// Step 2: Update Firebase display name
await firebaseUser.updateDisplayName(name);  // "John Doe"
await firebaseUser.reload();
```

**What happens:**
- Updates Firebase user profile with display name
- Reloads user data to get latest info
- This name appears in Firebase Console

---

### **Step 6: Register User in Backend Database**
**File: `lib/services/auth_service.dart` (Lines 34-40)**
```dart
// Step 3: Register user in PostgreSQL backend
final UserModel userModel = await ApiService.registerUser(
  firebaseUid: firebaseUid,    // "abc123xyz456"
  username: name,              // "John Doe"
  email: email,                // "john@example.com"
  profilePhotoUrl: profilePhotoUrl,  // null (optional)
);
```

**What happens:**
- Calls `ApiService.registerUser()` method
- Passes Firebase UID, username, email
- Waits for backend response

---

### **Step 7: HTTP Request to Backend**
**File: `lib/services/api_service.dart` (Lines 22-33)**
```dart
final response = await http.post(
  Uri.parse('$baseUrl/auth/register'),  // http://192.168.0.104:5000/api/auth/register
  headers: {
    'Content-Type': 'application/json',
  },
  body: jsonEncode({
    'firebase_uid': firebaseUid,    // "abc123xyz456"
    'username': username,            // "John Doe"
    'email': email,                  // "john@example.com"
    // profile_photo_url is optional
  }),
);
```

**What happens:**
- Creates HTTP POST request
- Sends JSON data to Flask backend
- Waits for response

**Request Body:**
```json
{
  "firebase_uid": "abc123xyz456",
  "username": "John Doe",
  "email": "john@example.com"
}
```

---

### **Step 8: Backend Receives Request**
**File: `backend_api_example.py` (Lines 164-174)**
```python
data = request.get_json()

if not data:
    return jsonify({'message': 'No data provided'}), 400

firebase_uid = data.get('firebase_uid')    # "abc123xyz456"
username = data.get('username')            # "John Doe"
email = data.get('email')                  # "john@example.com"

if not all([firebase_uid, username, email]):
    return jsonify({'message': 'Missing required fields'}), 400
```

**What happens:**
- Flask receives POST request
- Extracts JSON data
- Validates all required fields present
- If missing → Returns 400 error

---

### **Step 9: Check if User Exists**
**File: `backend_api_example.py` (Lines 176-189)**
```python
conn = get_db_connection()
cursor = conn.cursor(cursor_factory=RealDictCursor)

# Check if user already exists
cursor.execute(
    "SELECT user_id FROM users WHERE FK_firebase_uid = %s",
    (firebase_uid,)  # "abc123xyz456"
)
existing_user = cursor.fetchone()

if existing_user:
    cursor.close()
    conn.close()
    return jsonify({'message': 'User already exists'}), 409
```

**What happens:**
- Connects to PostgreSQL database
- Queries `users` table for existing Firebase UID
- If user exists → Returns 409 Conflict error
- If user doesn't exist → Continues to next step

**SQL Query:**
```sql
SELECT user_id FROM users WHERE FK_firebase_uid = 'abc123xyz456'
```

---

### **Step 10: Insert User into Database**
**File: `backend_api_example.py` (Lines 191-205)**
```python
# Get profile_photo_url if provided
profile_photo_url = data.get('profile_photo_url')  # null

# Insert new user
cursor.execute(
    """
    INSERT INTO users (FK_firebase_uid, user_name, name_email, profile_photo_url, created_at)
    VALUES (%s, %s, %s, %s, %s)
    RETURNING user_id, user_name, profile_photo_url, created_at
    """,
    (firebase_uid, username, email, profile_photo_url, datetime.now())
)

user = cursor.fetchone()  # Gets inserted row
conn.commit()  # Saves to database
```

**What happens:**
- Executes SQL INSERT statement
- Inserts: Firebase UID, username, email, profile photo (null), current timestamp
- `RETURNING` clause gets the inserted row back
- Commits transaction to database

**SQL Query:**
```sql
INSERT INTO users (FK_firebase_uid, user_name, name_email, profile_photo_url, created_at)
VALUES ('abc123xyz456', 'John Doe', 'john@example.com', NULL, '2024-01-15 10:30:00')
RETURNING user_id, user_name, profile_photo_url, created_at
```

**Database Result:**
```python
user = {
    'user_id': 1,
    'user_name': 'John Doe',
    'profile_photo_url': None,
    'created_at': datetime(2024, 1, 15, 10, 30, 0)
}
```

---

### **Step 11: Backend Returns Response**
**File: `backend_api_example.py` (Lines 207-215)**
```python
cursor.close()
conn.close()

return jsonify({
    'user_id': user['user_id'],                    # 1
    'username': user['user_name'],                 # "John Doe"
    'profile_photo_url': user.get('profile_photo_url'),  # None
    'created_at': user['created_at'].isoformat(),  # "2024-01-15T10:30:00"
}), 201
```

**What happens:**
- Closes database connection
- Creates JSON response
- Returns HTTP 201 Created status

**Response Body:**
```json
{
  "user_id": 1,
  "username": "John Doe",
  "profile_photo_url": null,
  "created_at": "2024-01-15T10:30:00"
}
```

---

### **Step 12: API Service Processes Response**
**File: `lib/services/api_service.dart` (Lines 35-37)**
```dart
if (response.statusCode == 200 || response.statusCode == 201) {
  final data = jsonDecode(response.body);
  return UserModel.fromJson(data);
}
```

**What happens:**
- Checks if status code is 200 or 201 (success)
- Parses JSON response
- Converts JSON to `UserModel` object

**UserModel Created:**
```dart
UserModel(
  userId: 1,
  username: "John Doe",
  createdAt: DateTime(2024, 1, 15, 10, 30, 0),
  email: null,
  profilePhotoUrl: null,
)
```

---

### **Step 13: AuthService Returns UserModel**
**File: `lib/services/auth_service.dart` (Line 42)**
```dart
return userModel;  // Returns UserModel to login_screen.dart
```

**What happens:**
- Returns `UserModel` object to `login_screen.dart`
- Sign up process complete

---

### **Step 14: Show Success Message**
**File: `lib/screens/login_screen.dart` (Lines 115-121)**
```dart
if (mounted) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Account created!'),
      backgroundColor: AppColors.success,  // Green color
    ),
  );
}
```

**What happens:**
- Shows green success message at bottom of screen
- Message: "Account created!"
- Auto-dismisses after few seconds

---

### **Step 15: Navigate to Home Screen**
**File: `lib/screens/login_screen.dart` (Lines 123-134)**
```dart
Navigator.pushReplacement(
  context,
  MaterialPageRoute(
    builder: (context) => HomeScreen(
      userId: userModel.userId,              // 1
      username: userModel.username,           // "John Doe"
      createdAt: userModel.createdAt,         // DateTime object
      profilePhotoUrl: userModel.profilePhotoUrl,  // null
    ),
  ),
);
```

**What happens:**
- Replaces login screen with home screen
- Passes user data to home screen
- User is now logged in and on home screen

---

### **Step 16: Cleanup**
**File: `lib/screens/login_screen.dart` (Line 148)**
```dart
finally {
  if (mounted) setState(() => _isLoading = false);
}
```

**What happens:**
- Hides loading spinner
- Button returns to normal state
- Process complete

---

## 🔐 **LOGIN FLOW (Complete Step-by-Step)**

### **Step 1: User Interaction**
```
User fills form:
  - Email: "john@example.com"
  - Password: "password123"
  
User clicks "Login" button
```

### **Step 2: Form Validation (Frontend)**
**File: `lib/screens/login_screen.dart`**
```dart
Future<void> _handleSubmit() async {
  // Line 72: Validate form
  if (!_formKey.currentState!.validate()) return;
  
  // Validation checks:
  // - Email: Contains '@' symbol
  // - Password: At least 6 characters
  
  // Line 74: Set loading state
  setState(() => _isLoading = true);
}
```

**What happens:**
- Form validates email and password
- If validation fails → Shows error, stops
- If validation passes → Continues
- Button shows loading spinner

---

### **Step 3: Call AuthService.signIn()**
**File: `lib/screens/login_screen.dart` (Lines 81-84)**
```dart
userModel = await AuthService.signIn(
  email: _emailController.text.trim(),    // "john@example.com"
  password: _passwordController.text,     // "password123"
);
```

**What happens:**
- Calls `AuthService.signIn()` method
- Passes email and password
- Waits for response

---

### **Step 4: Firebase Authentication**
**File: `lib/services/auth_service.dart` (Lines 60-71)**
```dart
// Step 1: Sign in with Firebase
final UserCredential userCredential = await _auth.signInWithEmailAndPassword(
  email: email,        // "john@example.com"
  password: password,  // "password123"
);

final User? firebaseUser = userCredential.user;
if (firebaseUser == null) {
  throw Exception('Failed to sign in');
}

final String firebaseUid = firebaseUser.uid;  // "abc123xyz456"
```

**What happens:**
- Firebase receives email and password
- Firebase checks: Does email exist? Is password correct?
- If credentials match → Returns user with UID
- If credentials don't match → Throws error

**Possible Errors:**
- `user-not-found`: Email doesn't exist
- `wrong-password`: Password is incorrect
- `invalid-email`: Email format invalid
- `user-disabled`: Account disabled
- `network-request-failed`: No internet

---

### **Step 5: Get User Data from Backend**
**File: `lib/services/auth_service.dart` (Lines 73-76)**
```dart
// Step 2: Get user data from PostgreSQL backend
final UserModel userModel = await ApiService.loginUser(
  firebaseUid: firebaseUid,  // "abc123xyz456"
);
```

**What happens:**
- Calls `ApiService.loginUser()` method
- Passes Firebase UID only (not email/password)
- Waits for backend response

---

### **Step 6: HTTP Request to Backend**
**File: `lib/services/api_service.dart` (Lines 54-62)**
```dart
final response = await http.post(
  Uri.parse('$baseUrl/auth/login'),  // http://192.168.0.104:5000/api/auth/login
  headers: {
    'Content-Type': 'application/json',
  },
  body: jsonEncode({
    'firebase_uid': firebaseUid,  // "abc123xyz456"
  }),
);
```

**What happens:**
- Creates HTTP POST request
- Sends only Firebase UID (not password)
- Waits for response

**Request Body:**
```json
{
  "firebase_uid": "abc123xyz456"
}
```

---

### **Step 7: Backend Receives Request**
**File: `backend_api_example.py` (Lines 247-255)**
```python
data = request.get_json()

if not data:
    return jsonify({'message': 'No data provided'}), 400

firebase_uid = data.get('firebase_uid')  # "abc123xyz456"

if not firebase_uid:
    return jsonify({'message': 'Missing firebase_uid'}), 400
```

**What happens:**
- Flask receives POST request
- Extracts Firebase UID
- Validates Firebase UID present
- If missing → Returns 400 error

---

### **Step 8: Query Database for User**
**File: `backend_api_example.py` (Lines 257-270)**
```python
conn = get_db_connection()
cursor = conn.cursor(cursor_factory=RealDictCursor)

# Find user by firebase_uid
cursor.execute(
    """
    SELECT user_id, user_name, profile_photo_url, created_at
    FROM users
    WHERE FK_firebase_uid = %s
    """,
    (firebase_uid,)  # "abc123xyz456"
)

user = cursor.fetchone()
```

**What happens:**
- Connects to PostgreSQL database
- Queries `users` table for matching Firebase UID
- Returns user data if found

**SQL Query:**
```sql
SELECT user_id, user_name, profile_photo_url, created_at
FROM users
WHERE FK_firebase_uid = 'abc123xyz456'
```

**Database Result:**
```python
user = {
    'user_id': 1,
    'user_name': 'John Doe',
    'profile_photo_url': None,
    'created_at': datetime(2024, 1, 15, 10, 30, 0)
}
```

---

### **Step 9: Check if User Found**
**File: `backend_api_example.py` (Lines 272-276)**
```python
cursor.close()
conn.close()

if not user:
    return jsonify({'message': 'User not found'}), 404
```

**What happens:**
- Closes database connection
- Checks if user exists
- If not found → Returns 404 Not Found error
- If found → Continues to next step

---

### **Step 10: Backend Returns Response**
**File: `backend_api_example.py` (Lines 278-283)**
```python
return jsonify({
    'user_id': user['user_id'],                    # 1
    'username': user['user_name'],                 # "John Doe"
    'profile_photo_url': user.get('profile_photo_url'),  # None
    'created_at': user['created_at'].isoformat(),  # "2024-01-15T10:30:00"
}), 200
```

**What happens:**
- Creates JSON response
- Returns HTTP 200 OK status

**Response Body:**
```json
{
  "user_id": 1,
  "username": "John Doe",
  "profile_photo_url": null,
  "created_at": "2024-01-15T10:30:00"
}
```

---

### **Step 11: API Service Processes Response**
**File: `lib/services/api_service.dart` (Lines 64-66)**
```dart
if (response.statusCode == 200) {
  final data = jsonDecode(response.body);
  return UserModel.fromJson(data);
}
```

**What happens:**
- Checks if status code is 200 (success)
- Parses JSON response
- Converts JSON to `UserModel` object

**UserModel Created:**
```dart
UserModel(
  userId: 1,
  username: "John Doe",
  createdAt: DateTime(2024, 1, 15, 10, 30, 0),
  email: null,
  profilePhotoUrl: null,
)
```

---

### **Step 12: AuthService Returns UserModel**
**File: `lib/services/auth_service.dart` (Line 78)**
```dart
return userModel;  // Returns UserModel to login_screen.dart
```

**What happens:**
- Returns `UserModel` object to `login_screen.dart`
- Login process complete

---

### **Step 13: Show Success Message**
**File: `lib/screens/login_screen.dart` (Lines 86-92)**
```dart
if (mounted) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Login Successful!'),
      backgroundColor: AppColors.success,  // Green color
    ),
  );
}
```

**What happens:**
- Shows green success message
- Message: "Login Successful!"
- Auto-dismisses after few seconds

---

### **Step 14: Navigate to Home Screen**
**File: `lib/screens/login_screen.dart` (Lines 94-105)**
```dart
Navigator.pushReplacement(
  context,
  MaterialPageRoute(
    builder: (context) => HomeScreen(
      userId: userModel.userId,              // 1
      username: userModel.username,           // "John Doe"
      createdAt: userModel.createdAt,         // DateTime object
      profilePhotoUrl: userModel.profilePhotoUrl,  // null
    ),
  ),
);
```

**What happens:**
- Replaces login screen with home screen
- Passes user data to home screen
- User is now logged in and on home screen

---

### **Step 15: Cleanup**
**File: `lib/screens/login_screen.dart` (Line 148)**
```dart
finally {
  if (mounted) setState(() => _isLoading = false);
}
```

**What happens:**
- Hides loading spinner
- Button returns to normal state
- Process complete

---

## ⚠️ **ERROR HANDLING FLOW**

### **If Error Occurs:**

**File: `lib/screens/login_screen.dart` (Lines 137-146)**
```dart
} on Exception catch (e) {
  final errMsg = e.toString().replaceAll('Exception: ', '');
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error: $errMsg'),
        backgroundColor: Colors.red,
      ),
    );
  }
} finally {
  if (mounted) setState(() => _isLoading = false);
}
```

**What happens:**
- Catches any exception
- Shows red error message
- Hides loading spinner
- User can try again

**Common Errors:**
- "An account already exists for that email" (Sign Up)
- "No user found for that email" (Login)
- "Wrong password provided" (Login)
- "Network error: Connection failed" (Network)
- "User not found" (Backend)

---

## 📊 **FLOW DIAGRAM SUMMARY**

### **Sign Up Flow:**
```
User Input → Form Validation → AuthService.signUp()
    ↓
Firebase.createUserWithEmailAndPassword()
    ↓
Get Firebase UID → Update Display Name
    ↓
ApiService.registerUser() → HTTP POST /api/auth/register
    ↓
Backend: Check if exists → Insert into database
    ↓
Return UserModel → Show Success → Navigate to Home
```

### **Login Flow:**
```
User Input → Form Validation → AuthService.signIn()
    ↓
Firebase.signInWithEmailAndPassword()
    ↓
Get Firebase UID
    ↓
ApiService.loginUser() → HTTP POST /api/auth/login
    ↓
Backend: Query database → Return user data
    ↓
Return UserModel → Show Success → Navigate to Home
```

---

## 🔑 **KEY DIFFERENCES**

| Aspect | Sign Up | Login |
|--------|--------|-------|
| **Firebase Action** | Creates new user | Authenticates existing user |
| **Backend Action** | Inserts new record | Queries existing record |
| **Data Sent** | Firebase UID + Username + Email | Only Firebase UID |
| **Validation** | Checks if user exists (409 if exists) | Checks if user found (404 if not) |
| **Success Message** | "Account created!" | "Login Successful!" |
| **HTTP Status** | 201 Created | 200 OK |

---

## 📝 **IMPORTANT NOTES**

1. **Password is NEVER sent to backend** - Only Firebase handles passwords
2. **Firebase UID is the link** - Connects Firebase account to database record
3. **Two-step process** - Both Firebase and backend must succeed
4. **Error handling** - Errors at any step show user-friendly messages
5. **Loading states** - Button shows spinner during async operations
6. **Navigation** - Uses `pushReplacement` to prevent going back to login

---

**This completes the full flow explanation for both Login and Sign Up processes!**

