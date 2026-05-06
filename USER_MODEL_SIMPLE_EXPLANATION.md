# UserModel - Simple Explanation

## 🎯 **What is UserModel?**

`UserModel` is like a **box** that holds user information. It has:
- `userId` - Your unique number (like 1, 2, 3...)
- `username` - Your name (like "John Doe")
- `createdAt` - When you joined (date and time)
- `email` - Your email (optional)
- `profilePhotoUrl` - Your photo link (optional)

---

## 📍 **Where It's Used (5 Places)**

### **1. Backend → App (Converting JSON to Object)**

**File: `api_service.dart`**

**What happens:**
- Backend sends JSON (like a letter)
- We convert it to `UserModel` (like reading the letter)

**Code:**
```dart
// Backend sends: {"user_id": 1, "username": "John"}
// We convert it to UserModel object
return UserModel.fromJson(data);
```

**Used in:** `registerUser()`, `loginUser()`, `updateProfilePhoto()`, `deleteProfilePhoto()`

---

### **2. Authentication (Login/Signup)**

**File: `auth_service.dart`**

**What happens:**
- When you login/signup, we get `UserModel` from backend
- We return it to the screen

**Code:**
```dart
// Sign up
static Future<UserModel> signUp(...) {
  // Create Firebase account
  // Then get UserModel from backend
  final UserModel userModel = await ApiService.registerUser(...);
  return userModel;  // Give it to login screen
}

// Sign in
static Future<UserModel> signIn(...) {
  // Check Firebase credentials
  // Then get UserModel from backend
  final UserModel userModel = await ApiService.loginUser(...);
  return userModel;  // Give it to login screen
}
```

---

### **3. Login Screen (Receives UserModel)**

**File: `login_screen.dart`**

**What happens:**
- After login/signup, we get `UserModel`
- We pass it to Home Screen

**Code:**
```dart
// After login/signup
UserModel userModel = await AuthService.signIn(...);

// Pass to Home Screen
HomeScreen(
  userId: userModel.userId,        // 1
  username: userModel.username,     // "John Doe"
  createdAt: userModel.createdAt,   // Date
  profilePhotoUrl: userModel.profilePhotoUrl,  // Photo link
)
```

---

### **4. Main App (Stores User Data)**

**File: `main.dart`**

**What happens:**
- App remembers who is logged in
- Stores `UserModel` in memory

**Code:**
```dart
// Store user data
UserModel? _userData;

// Load user data
_userData = await AuthService.getCurrentUserData();

// Update when profile photo changes
void _onUserDataUpdated(UserModel updatedUser) {
  _userData = updatedUser;  // Update stored data
}
```

---

### **5. Home Screen (Shows User Data)**

**File: `home_screen.dart`**

**What happens:**
- Receives user data
- Shows it on screen
- Updates when profile photo changes

**Code:**
```dart
// Receives callback when photo updates
void _onProfilePhotoUpdated(UserModel updatedUser) {
  // Update photo on screen
  _currentProfilePhotoUrl = updatedUser.profilePhotoUrl;
  
  // Tell main app to update
  widget.onProfilePhotoUpdated!(updatedUser);
}
```

---

## 🔄 **Simple Flow**

```
1. Backend sends JSON
   ↓
2. ApiService converts to UserModel
   ↓
3. AuthService returns UserModel
   ↓
4. Login Screen receives UserModel
   ↓
5. Main App stores UserModel
   ↓
6. Home Screen shows UserModel data
```

---

## 💡 **Key Points**

1. **UserModel = User Information Box**
   - Holds: ID, name, email, photo, date joined

2. **Used in 5 Places:**
   - Converting JSON → Object (api_service)
   - Authentication (auth_service)
   - Login Screen (receives data)
   - Main App (stores data)
   - Home Screen (shows data)

3. **Flow:**
   - Backend → Convert → Auth → Login → Main → Home

4. **Updates:**
   - When profile photo changes, UserModel is updated
   - All screens get the new data

---

## 📝 **In One Sentence**

**"UserModel is a box that carries user information from the backend through authentication to the home screen, and gets updated when the user changes their profile photo."**

---

That's it! Simple and easy to understand. 🎉

