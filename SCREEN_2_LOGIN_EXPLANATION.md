# Screen 2: Login Screen - Complete Explanation

## 📱 **UI/Design Overview**

### Visual Elements:
1. **Curved Header with Gradient**:
   - Green gradient background: `[Color(0xFF2E8B57), Color(0xFF006A60)]` - Emerald to Dark Teal
   - Custom curved clipper creates smooth wave effect at bottom
   - Arabic calligraphy watermark pattern in background (10% opacity)
   - Title changes dynamically: "Welcome Back" (Login) or "Create Account" (Sign Up)

2. **Dual-Mode Card Interface**:
   - White card with rounded corners (20px radius) and elevation shadow
   - Tab selector at top: "Login" and "Sign Up" tabs
   - Active tab highlighted in green (`AppColors.primary`)
   - Smooth tab switching animation

3. **Form Fields**:
   - **Login Mode**: Email field, Password field (with visibility toggle), "Forgot Password?" link
   - **Sign Up Mode**: Full Name field, Email field, Password field (with visibility toggle)
   - All fields have icons (email, lock, person) and rounded borders
   - Custom validation with error messages

4. **Action Elements**:
   - Primary button: "Login" or "Sign Up" (full width, green background)
   - Loading spinner shown during async operations
   - Mode switcher text at bottom: "Don't have an account? Sign Up" / "Already have an account? Login"
   - Footer: Decorative line with gold dot and "Made with 🤍 for the Ummah"

---

## 💻 **Frontend Code Breakdown**

### **File: `lib/screens/login_screen.dart`**

#### **1. Main Widget: `LoginScreen`**
```dart
class LoginScreen extends StatefulWidget
```
- **Purpose**: Dual-mode authentication interface (Login/Sign Up)
- **State Management**: Tracks mode (`_isLogin`), password visibility (`_obscurePassword`), loading state (`_isLoading`)
- **Form Controllers**: Manages email, password, and name input fields

**Key Methods:**
- `_toggleMode()`: Switches between Login and Sign Up mode (resets animation)
- `_handleSubmit()`: Validates form and calls AuthService for login/signup
- `_showForgotPasswordDialog()`: Shows password reset dialog popup

#### **2. State Variables**
```dart
bool _isLogin = true;              // true = Login mode, false = Sign Up mode
bool _obscurePassword = true;      // Controls password field visibility
bool _isLoading = false;           // Loading state for async operations

final _formKey = GlobalKey<FormState>();
final _emailController = TextEditingController();
final _passwordController = TextEditingController();
final _nameController = TextEditingController();
```
- Form key for validation
- Text controllers for each input field
- Boolean flags for UI state management

#### **3. Animation Controller**
```dart
late AnimationController _animationController;
late Animation<double> _fadeAnimation;
late Animation<Offset> _slideAnimation;
```
- **Purpose**: Smooth fade-in and slide-up animations for form card
- **Duration**: 800ms with easeIn/easeOut curves
- **Implementation**: Uses `SingleTickerProviderStateMixin`

#### **4. Custom UI Components**

**CustomTextField Widget:**
```dart
class CustomTextField extends StatelessWidget
```
- Reusable text field with consistent styling
- Features: Icon prefix, rounded borders, validation support
- States: Normal, focused (green border), error (red border)

**CurvedHeaderClipper:**
```dart
class CurvedHeaderClipper extends CustomClipper<Path>
```
- Custom clipper for curved header shape
- Uses `quadraticBezierTo` for smooth wave curve
- Creates modern, flowing design

**CalligraphyPainter:**
```dart
class CalligraphyPainter extends CustomPainter
```
- Draws Arabic calligraphy pattern in header background
- Uses flowing curves and decorative dots
- 10% opacity for subtle watermark effect

#### **5. Form Validation**
- **Email**: Checks for `@` symbol and non-empty value
- **Password**: Minimum 6 characters required
- **Name**: Required for sign up (non-empty)
- Real-time validation with error messages below fields

---

## 🔧 **Backend/Storage Code**

### **File: `lib/services/auth_service.dart`**

#### **Purpose**: Handles Firebase Authentication and coordinates with backend API

#### **Key Methods:**

1. **`signUp()`**
   ```dart
   static Future<UserModel> signUp({
     required String name,
     required String email,
     required String password,
   })
   ```
   - **Step 1**: Creates user in Firebase with `createUserWithEmailAndPassword()`
   - **Step 2**: Updates Firebase display name
   - **Step 3**: Registers user in PostgreSQL backend via `ApiService.registerUser()`
   - Returns `UserModel` with user data from backend
   - Handles `FirebaseAuthException` with user-friendly error messages

2. **`signIn()`**
   ```dart
   static Future<UserModel> signIn({
     required String email,
     required String password,
   })
   ```
   - **Step 1**: Authenticates with Firebase using `signInWithEmailAndPassword()`
   - **Step 2**: Gets Firebase UID from authenticated user
   - **Step 3**: Fetches user data from PostgreSQL backend via `ApiService.loginUser()`
   - Returns `UserModel` with complete user profile

3. **`sendPasswordResetEmail()`**
   ```dart
   static Future<void> sendPasswordResetEmail(String email)
   ```
   - Sends password reset email via Firebase
   - User receives email with reset link
   - Handles Firebase errors gracefully

### **File: `lib/services/api_service.dart`**

#### **Purpose**: HTTP client for communicating with Flask backend

#### **Key Methods:**

1. **`registerUser()`**
   ```dart
   static Future<UserModel> registerUser({
     required String firebaseUid,
     required String username,
     required String email,
   })
   ```
   - Sends POST request to `/api/auth/register`
   - Payload: `{firebase_uid, username, email, profile_photo_url?}`
   - Returns `UserModel` parsed from JSON response
   - Handles HTTP errors (400, 409, 500)

2. **`loginUser()`**
   ```dart
   static Future<UserModel> loginUser({
     required String firebaseUid,
   })
   ```
   - Sends POST request to `/api/auth/login`
   - Payload: `{firebase_uid}`
   - Returns `UserModel` with user profile data
   - Handles 404 if user not found

### **File: `backend_api_example.py`**

#### **Flask Endpoints:**

1. **`/api/auth/register` (POST)**
   ```python
   @app.route('/api/auth/register', methods=['POST'])
   def register_user():
   ```
   - **Input**: `{firebase_uid, username, email, profile_photo_url?}`
   - **Process**: 
     - Checks if user exists (by `FK_firebase_uid`)
     - If new: Inserts into `users` table
     - Returns user data with `user_id`
   - **Output**: `{user_id, username, profile_photo_url, created_at}`
   - **Status Codes**: 201 (created), 409 (exists), 400 (bad request), 500 (error)

2. **`/api/auth/login` (POST)**
   ```python
   @app.route('/api/auth/login', methods=['POST'])
   def login_user():
   ```
   - **Input**: `{firebase_uid}`
   - **Process**: 
     - Queries `users` table by `FK_firebase_uid`
     - Returns user profile data
   - **Output**: `{user_id, username, profile_photo_url, created_at}`
   - **Status Codes**: 200 (success), 404 (not found), 400 (bad request), 500 (error)

---

## 🔄 **Flow & Navigation**

### **Sign Up Flow:**

1. **User fills form** → Name, Email, Password entered
2. **Form validation** → Checks all fields are valid
3. **`_handleSubmit()` called** → Sets `_isLoading = true`
4. **`AuthService.signUp()` called**:
   - Creates Firebase user → Gets Firebase UID
   - Updates Firebase display name
   - Calls `ApiService.registerUser()` with Firebase UID
5. **Backend registration**:
   - HTTP POST to `/api/auth/register`
   - PostgreSQL INSERT into `users` table
   - Returns user data
6. **Success handling**:
   - Shows "Account created!" SnackBar
   - Navigates to `HomeScreen` with user data
   - Sets `_isLoading = false`

### **Login Flow:**

1. **User fills form** → Email, Password entered
2. **Form validation** → Checks email format and password length
3. **`_handleSubmit()` called** → Sets `_isLoading = true`
4. **`AuthService.signIn()` called**:
   - Authenticates with Firebase → Gets Firebase UID
   - Calls `ApiService.loginUser()` with Firebase UID
5. **Backend lookup**:
   - HTTP POST to `/api/auth/login`
   - PostgreSQL SELECT from `users` table
   - Returns user profile data
6. **Success handling**:
   - Shows "Login Successful!" SnackBar
   - Navigates to `HomeScreen` with user data
   - Sets `_isLoading = false`

### **Password Reset Flow:**

1. **User clicks "Forgot Password?"** → Dialog appears
2. **User enters email** → Validation checks email format
3. **`AuthService.sendPasswordResetEmail()` called**
4. **Firebase sends email** → User receives reset link
5. **User clicks link** → Opens reset password screen
6. **User sets new password** → Firebase updates password

### **Navigation Paths:**
```
LoginScreen → HomeScreen (on successful login/signup)
           → ResetPasswordScreen (via email link)
```

---

## 🎨 **Design Patterns Used**

1. **State Management**: StatefulWidget with local state (`_isLogin`, `_obscurePassword`, `_isLoading`)
2. **Form Validation**: Flutter's built-in `Form` widget with `GlobalKey<FormState>`
3. **Animation**: AnimationController with Tween animations (fade, slide)
4. **Custom Painting**: CustomClipper for curved header, CustomPainter for calligraphy
5. **Service Layer**: Separation of concerns (AuthService, ApiService)
6. **Widget Composition**: Reusable CustomTextField and CustomButton widgets
7. **Error Handling**: Try-catch blocks with user-friendly error messages
8. **Async/Await**: Proper handling of asynchronous operations

---

## 📊 **Technical Details**

### **Dependencies Used:**
- `firebase_auth`: Firebase Authentication
- `http`: HTTP client for API calls
- `flutter/material.dart`: UI components
- Custom widgets: `CustomButton`, `CustomTextField`

### **Database Schema (PostgreSQL):**
```sql
CREATE TABLE users (
    user_id SERIAL PRIMARY KEY,
    FK_firebase_uid VARCHAR(255) UNIQUE NOT NULL,
    user_name VARCHAR(255) NOT NULL,
    name_email VARCHAR(255) NOT NULL,
    profile_photo_url TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### **Security Features:**
- **Password Encryption**: Handled by Firebase (bcrypt)
- **SQL Injection Prevention**: Parameterized queries in backend
- **Error Message Sanitization**: User-friendly messages without exposing system details
- **Token Management**: Firebase handles JWT tokens automatically
- **HTTPS**: API calls should use HTTPS in production

### **Performance Optimizations:**
- Controllers disposed in `dispose()` method
- AnimationController properly managed
- Efficient rebuilds with `setState()` only when needed
- Form validation prevents unnecessary API calls

### **Accessibility:**
- Clear labels on all form fields
- Icons provide visual context
- Error messages are descriptive
- Large touch targets for buttons

---

## 🎯 **Key Features**

✅ **Dual-mode interface** - Single screen handles both login and signup  
✅ **Form validation** - Real-time validation with error messages  
✅ **Loading states** - Visual feedback during async operations  
✅ **Password visibility toggle** - Eye icon to show/hide password  
✅ **Password reset** - Integrated forgot password flow  
✅ **Smooth animations** - Fade and slide transitions  
✅ **Error handling** - Comprehensive error catching and user-friendly messages  
✅ **Firebase integration** - Secure password management  
✅ **Backend synchronization** - User data stored in PostgreSQL  
✅ **Islamic design** - Green colors and Arabic calligraphy patterns  

---

## 🔍 **Code Locations**

- **Main Screen**: `lib/screens/login_screen.dart` (934 lines)
- **Auth Service**: `lib/services/auth_service.dart` (385 lines)
- **API Service**: `lib/services/api_service.dart` (lines 15-77 for auth methods)
- **Backend API**: `backend_api_example.py` (lines 142-290)
- **User Model**: `lib/models/user_model.dart` (36 lines)
- **Button Widget**: `lib/widgets/custom_button.dart` (74 lines)
- **Colors**: `lib/utils/apps_colors.dart` (122 lines)

---

## 📝 **Notes for FYP Presentation**

1. **Hybrid Authentication**: Uses Firebase for credentials + PostgreSQL for profile data
2. **Two-Step Process**: Sign up requires both Firebase account creation and backend registration
3. **Security**: Passwords never stored in our database (handled by Firebase)
4. **Error Handling**: Comprehensive error messages for network, validation, and Firebase errors
5. **User Experience**: Smooth animations, clear validation, and helpful error messages
6. **Database Design**: `FK_firebase_uid` links Firebase authentication to our user records
7. **Scalability**: Architecture supports future features (OAuth, social login, email verification)

---

**Next Screen**: Home Screen (Screen 3)
