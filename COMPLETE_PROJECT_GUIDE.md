# Complete Project Guide - Screen by Screen
## Easy to Remember! 🎯

---

## 📱 **SCREEN 1: ONBOARDING SCREEN**
### **Purpose:** Welcome tour for first-time users (3 pages)

### **Files Used:**

#### **1. `lib/screens/onboarding_screen.dart`**
**Purpose:** The welcome screen itself

**Key Methods:**
- `_onPageChanged()` - Updates current page when user swipes
- `_nextPage()` - Moves to next page or completes onboarding
- `_skipToLogin()` - Skips all pages and goes to login
- `_completeOnboarding()` - Saves completion status

**What it does:**
- Shows 3 beautiful pages with animations
- User can swipe or click "Next"
- User can click "Skip" to go to login

**Remember:** "Onboarding = Welcome Tour"

---

#### **2. `lib/services/onboarding_service.dart`**
**Purpose:** Remembers if user has seen the tour

**Key Methods:**
- `isOnboardingCompleted()` - Checks if user saw tour before
- `completeOnboarding()` - Saves that user saw tour
- `resetOnboarding()` - Removes the memory (for testing)

**What it does:**
- Uses SharedPreferences (like a small notebook)
- Saves: "Has user seen tour? Yes/No"
- Only shows tour once per app installation

**Remember:** "OnboardingService = Memory Keeper"

---

#### **3. `lib/widgets/custom_button.dart`**
**Purpose:** Reusable button widget

**Key Methods:**
- `build()` - Creates the button with text and icon

**What it does:**
- Makes "Next" and "Get Started" buttons
- Shows loading spinner when processing
- Used in many screens

**Remember:** "CustomButton = Reusable Button"

---

### **Flow:**
```
App Starts → Check if tour seen? 
  → No: Show Onboarding Screen
  → Yes: Skip to Login
```

---

## 🔐 **SCREEN 2: LOGIN SCREEN**
### **Purpose:** User login and signup

### **Files Used:**

#### **1. `lib/screens/login_screen.dart`**
**Purpose:** The login/signup form

**Key Methods:**
- `_toggleMode()` - Switches between Login and Sign Up
- `_handleSubmit()` - Validates form and calls AuthService
- `_showForgotPasswordDialog()` - Shows password reset popup

**What it does:**
- Shows form: Email, Password, Name (for signup)
- Validates input
- Calls AuthService for login/signup
- Navigates to Home Screen on success

**Remember:** "LoginScreen = Form + Validation"

---

#### **2. `lib/services/auth_service.dart`**
**Purpose:** Handles authentication (login/signup)

**Key Methods:**
- `signUp()` - Creates Firebase account → Registers in backend
- `signIn()` - Checks Firebase credentials → Gets user data
- `sendPasswordResetEmail()` - Sends reset email via Firebase
- `getCurrentUserData()` - Gets logged-in user's data

**What it does:**
- **Sign Up:** Firebase creates account → Backend saves user
- **Sign In:** Firebase checks password → Backend returns user data
- Coordinates Firebase and Backend together

**Remember:** "AuthService = Authentication Manager"

---

#### **3. `lib/services/api_service.dart`**
**Purpose:** Talks to Python backend server

**Key Methods:**
- `registerUser()` - Sends user data to backend for signup
- `loginUser()` - Gets user data from backend for login
- `updateProfilePhoto()` - Updates profile photo in backend
- `deleteProfilePhoto()` - Deletes profile photo from backend

**What it does:**
- Sends HTTP requests to backend
- Receives JSON responses
- Converts JSON to UserModel

**Remember:** "ApiService = Backend Messenger"

---

#### **4. `lib/models/user_model.dart`**
**Purpose:** Box that holds user information

**Key Methods:**
- `fromJson()` - Converts JSON to UserModel
- `toJson()` - Converts UserModel to JSON

**What it does:**
- Stores: userId, username, email, photo, date joined
- Converts backend JSON to clean Dart object

**Remember:** "UserModel = User Info Box"

---

### **Flow:**
```
User fills form → LoginScreen validates
  → AuthService.signUp/signIn()
    → Firebase creates/checks account
    → ApiService talks to backend
      → Backend saves/returns user data
        → UserModel created
          → Navigate to Home Screen
```

---

## 🏠 **SCREEN 3: HOME SCREEN**
### **Purpose:** Main screen with input methods (text, image, voice)

### **Files Used:**

#### **1. `lib/screens/home_screen.dart`**
**Purpose:** Main screen with search options

**Key Methods:**
- `_searchHadith()` - Searches hadith with text input
- `_pickImage()` - Opens image picker
- `_pickAudio()` - Opens audio file picker
- `_startListening()` - Starts voice input
- `_stopListening()` - Stops voice input
- `_navigateToChatbot()` - Opens chatbot screen

**What it does:**
- Shows 3 input methods: Text, Image, Voice
- User can type, upload image, or speak
- Sends query to backend for hadith search
- Navigates to Result Page with results

**Remember:** "HomeScreen = Main Hub with 3 Input Methods"

---

#### **2. `lib/services/ocr_service.dart`**
**Purpose:** Extracts text from images

**Key Methods:**
- `extractTextFromImage()` - Uses Tesseract OCR to read text from image
- `preprocessImage()` - Enhances image for better OCR

**What it does:**
- Takes image file
- Uses Tesseract OCR to read text
- Returns extracted text
- Used when user uploads image

**Remember:** "OCRService = Image Text Reader"

---

#### **3. `lib/services/transcription_service.dart`**
**Purpose:** Converts audio to text

**Key Methods:**
- `transcribeAudio()` - Sends audio to backend for transcription

**What it does:**
- Takes audio file
- Sends to backend for speech-to-text
- Returns transcribed text
- Used when user uploads audio

**Remember:** "TranscriptionService = Audio to Text Converter"

---

#### **4. `lib/services/api_service.dart`** (Also used here)
**Purpose:** Searches hadith in backend

**Key Methods:**
- `searchHadith()` - Sends query to backend, gets hadith results
- `getHadithDetail()` - Gets full details of one hadith

**What it does:**
- Sends search query to backend
- Backend searches in database
- Returns list of matching hadiths

**Remember:** "ApiService.searchHadith() = Hadith Search"

---

#### **5. `lib/models/hadith_models.dart`**
**Purpose:** Boxes that hold hadith information

**Key Models:**
- `HadithSummary` - Short info (ID, text, classification)
- `HadithDetail` - Full info (all details)
- `HistoryEntry` - Search history entry
- `BookmarkEntry` - Bookmarked hadith

**What it does:**
- Structures hadith data
- Converts JSON to objects

**Remember:** "HadithModels = Hadith Info Boxes"

---

#### **6. `lib/widgets/profile_photo_widget.dart`**
**Purpose:** Shows and updates profile photo

**Key Methods:**
- `_pickImage()` - Opens image picker
- `_uploadPhoto()` - Uploads photo to Firebase Storage
- `_deletePhoto()` - Deletes photo

**What it does:**
- Shows user's profile photo
- Allows user to change photo
- Updates photo in Firebase and backend

**Remember:** "ProfilePhotoWidget = Photo Manager"

---

### **Flow:**
```
User inputs (text/image/voice)
  → HomeScreen processes input
    → If image: OCRService extracts text
    → If audio: TranscriptionService converts to text
    → ApiService.searchHadith() sends to backend
      → Backend searches database
        → Returns HadithSummary list
          → Navigate to Result Page
```

---

## 📄 **SCREEN 4: RESULT PAGE**
### **Purpose:** Shows list of search results

### **Files Used:**

#### **1. `lib/screens/result_page.dart`**
**Purpose:** Displays list of hadith results

**Key Methods:**
- `build()` - Shows list of hadith cards

**What it does:**
- Receives list of HadithSummary
- Shows each hadith as a card
- User can click to see details
- Navigates to Result Detail Page

**Remember:** "ResultPage = Results List"

---

#### **2. `lib/services/api_service.dart`**
**Purpose:** Saves search to history

**Key Methods:**
- `saveSearchHistory()` - Saves search query and results to database

**What it does:**
- When user searches, saves to history
- Stores: query, results, timestamp

**Remember:** "ApiService.saveSearchHistory() = History Saver"

---

### **Flow:**
```
Result Page receives HadithSummary list
  → Shows cards for each result
    → User clicks one
      → Navigate to Result Detail Page
```

---

## 📖 **SCREEN 5: RESULT DETAIL PAGE**
### **Purpose:** Shows full details of one hadith

### **Files Used:**

#### **1. `lib/screens/result_detail_page.dart`**
**Purpose:** Shows complete hadith information

**Key Methods:**
- `_loadHadithDetail()` - Gets full hadith details from backend
- `_bookmarkHadith()` - Saves hadith to bookmarks
- `_unbookmarkHadith()` - Removes from bookmarks

**What it does:**
- Shows: Full text, classification, source, narrator, etc.
- User can bookmark/unbookmark
- User can share hadith

**Remember:** "ResultDetailPage = Full Hadith Info"

---

#### **2. `lib/services/api_service.dart`**
**Purpose:** Gets hadith details and manages bookmarks

**Key Methods:**
- `getHadithDetail()` - Gets full hadith info
- `addBookmark()` - Adds to bookmarks
- `removeBookmark()` - Removes from bookmarks

**What it does:**
- Fetches complete hadith data
- Saves/removes bookmarks in database

**Remember:** "ApiService = Detail Fetcher + Bookmark Manager"

---

### **Flow:**
```
User clicks hadith from Result Page
  → ResultDetailPage loads
    → ApiService.getHadithDetail() gets full info
      → Shows all details
        → User can bookmark
```

---

## 📚 **SCREEN 6: HISTORY PAGE**
### **Purpose:** Shows user's search history

### **Files Used:**

#### **1. `lib/screens/history_page.dart`**
**Purpose:** Lists all past searches

**Key Methods:**
- `_loadHistory()` - Gets history from backend
- `_deleteHistory()` - Deletes one history entry

**What it does:**
- Shows list of past searches
- Each entry shows: query, date, results count
- User can click to see details
- User can delete entries

**Remember:** "HistoryPage = Past Searches List"

---

#### **2. `lib/services/api_service.dart`**
**Purpose:** Gets and deletes history

**Key Methods:**
- `getSearchHistory()` - Gets all history entries
- `deleteSearchHistory()` - Deletes one entry

**What it does:**
- Fetches history from database
- Deletes history entries

**Remember:** "ApiService = History Manager"

---

### **Flow:**
```
User opens History Page
  → ApiService.getSearchHistory() gets all entries
    → Shows list
      → User clicks one
        → Navigate to History Detail Page
```

---

## 🔖 **SCREEN 7: BOOKMARK PAGE**
### **Purpose:** Shows user's bookmarked hadiths

### **Files Used:**

#### **1. `lib/screens/bookmark_page.dart`**
**Purpose:** Lists all bookmarked hadiths

**Key Methods:**
- `_loadBookmarks()` - Gets bookmarks from backend
- `_deleteBookmark()` - Removes bookmark

**What it does:**
- Shows list of saved hadiths
- User can click to see details
- User can remove bookmarks

**Remember:** "BookmarkPage = Saved Hadiths List"

---

#### **2. `lib/services/api_service.dart`**
**Purpose:** Gets and deletes bookmarks

**Key Methods:**
- `getBookmarks()` - Gets all bookmarks
- `removeBookmark()` - Removes one bookmark

**What it does:**
- Fetches bookmarks from database
- Deletes bookmarks

**Remember:** "ApiService = Bookmark Manager"

---

### **Flow:**
```
User opens Bookmark Page
  → ApiService.getBookmarks() gets all bookmarks
    → Shows list
      → User clicks one
        → Navigate to Bookmark Detail Page
```

---

## 🤖 **SCREEN 8: CHATBOT SCREEN**
### **Purpose:** AI chatbot for Islamic questions

### **Files Used:**

#### **1. `lib/screens/chatbot_screen.dart`**
**Purpose:** Chat interface with AI

**Key Methods:**
- `_sendMessage()` - Sends user message to backend
- `_loadChatHistory()` - Gets past conversations

**What it does:**
- Shows chat interface
- User types question
- Sends to backend AI
- Shows AI response

**Remember:** "ChatbotScreen = AI Chat Interface"

---

#### **2. `lib/services/api_service.dart`**
**Purpose:** Sends messages to AI backend

**Key Methods:**
- `sendChatMessage()` - Sends message, gets AI response

**What it does:**
- Sends user question to backend
- Backend uses OpenAI to generate answer
- Returns AI response

**Remember:** "ApiService.sendChatMessage() = AI Messenger"

---

### **Flow:**
```
User types question
  → ApiService.sendChatMessage() sends to backend
    → Backend uses OpenAI
      → Returns AI answer
        → Shows in chat
```

---

## 🖼️ **SCREEN 9: CROP IMAGE PAGE**
### **Purpose:** Allows user to crop uploaded image

### **Files Used:**

#### **1. `lib/screens/crop_image_page.dart`**
**Purpose:** Image cropping interface

**Key Methods:**
- `_cropImage()` - Crops the image
- `_saveCroppedImage()` - Saves cropped image

**What it does:**
- Shows image with crop tool
- User adjusts crop area
- Saves cropped image
- Returns to Home Screen with cropped image

**Remember:** "CropImagePage = Image Cropper"

---

### **Flow:**
```
User uploads image
  → Crop Image Page opens
    → User crops image
      → Returns cropped image
        → OCRService extracts text
```

---

## 🎤 **SCREEN 10: VOICE INPUT PAGE**
### **Purpose:** Voice input for hadith search

### **Files Used:**

#### **1. `lib/screens/voice_input_page.dart`**
**Purpose:** Voice recording interface

**Key Methods:**
- `_startRecording()` - Starts voice recording
- `_stopRecording()` - Stops and processes audio

**What it does:**
- Records user's voice
- Converts to text
- Sends to backend for search

**Remember:** "VoiceInputPage = Voice Recorder"

---

#### **2. `lib/services/transcription_service.dart`**
**Purpose:** Converts audio to text

**Key Methods:**
- `transcribeAudio()` - Sends audio to backend

**What it does:**
- Takes recorded audio
- Sends to backend
- Gets transcribed text

**Remember:** "TranscriptionService = Audio to Text"

---

### **Flow:**
```
User records voice
  → TranscriptionService converts to text
    → Sends to backend for search
      → Shows results
```

---

## 🔑 **SCREEN 11: RESET PASSWORD SCREEN**
### **Purpose:** Allows user to reset forgotten password

### **Files Used:**

#### **1. `lib/screens/reset_password_screen.dart`**
**Purpose:** Password reset form

**Key Methods:**
- `_resetPassword()` - Resets password with Firebase

**What it does:**
- User enters new password
- Validates password
- Calls Firebase to reset
- Shows success/error message

**Remember:** "ResetPasswordScreen = Password Reset Form"

---

#### **2. `lib/services/auth_service.dart`**
**Purpose:** Handles password reset

**Key Methods:**
- `confirmPasswordReset()` - Resets password in Firebase

**What it does:**
- Takes reset code and new password
- Updates password in Firebase

**Remember:** "AuthService.confirmPasswordReset() = Password Updater"

---

### **Flow:**
```
User clicks reset link from email
  → Reset Password Screen opens
    → User enters new password
      → AuthService.confirmPasswordReset()
        → Firebase updates password
          → Success message
```

---

## 📊 **SUMMARY TABLE - ALL FILES**

| File | Purpose | Used In Screens | Key Methods |
|------|---------|----------------|-------------|
| **onboarding_screen.dart** | Welcome tour | Onboarding | `_nextPage()`, `_completeOnboarding()` |
| **onboarding_service.dart** | Remembers tour seen | Onboarding | `isOnboardingCompleted()`, `completeOnboarding()` |
| **login_screen.dart** | Login/signup form | Login | `_handleSubmit()`, `_toggleMode()` |
| **auth_service.dart** | Authentication | Login, Reset Password | `signUp()`, `signIn()`, `confirmPasswordReset()` |
| **api_service.dart** | Backend communication | All screens | `registerUser()`, `searchHadith()`, `getBookmarks()` |
| **user_model.dart** | User data container | Login, Home | `fromJson()`, `toJson()` |
| **home_screen.dart** | Main screen | Home | `_searchHadith()`, `_pickImage()`, `_startListening()` |
| **ocr_service.dart** | Image text extraction | Home | `extractTextFromImage()` |
| **transcription_service.dart** | Audio to text | Home, Voice Input | `transcribeAudio()` |
| **hadith_models.dart** | Hadith data containers | Result, History, Bookmark | `HadithSummary`, `HadithDetail` |
| **result_page.dart** | Results list | Result | Shows list of hadiths |
| **result_detail_page.dart** | Full hadith details | Result Detail | `_loadHadithDetail()`, `_bookmarkHadith()` |
| **history_page.dart** | Search history | History | `_loadHistory()`, `_deleteHistory()` |
| **bookmark_page.dart** | Bookmarked hadiths | Bookmark | `_loadBookmarks()`, `_deleteBookmark()` |
| **chatbot_screen.dart** | AI chat | Chatbot | `_sendMessage()` |
| **crop_image_page.dart** | Image cropping | Crop Image | `_cropImage()` |
| **voice_input_page.dart** | Voice recording | Voice Input | `_startRecording()` |
| **reset_password_screen.dart** | Password reset | Reset Password | `_resetPassword()` |
| **custom_button.dart** | Reusable button | All screens | `build()` |
| **profile_photo_widget.dart** | Profile photo | Home | `_uploadPhoto()`, `_deletePhoto()` |

---

## 🎯 **EASY MEMORY TRICKS**

### **Screen Flow:**
```
1. Onboarding → Welcome Tour
2. Login → Get In
3. Home → Main Hub
4. Result → See Results
5. Result Detail → Full Info
6. History → Past Searches
7. Bookmark → Saved Hadiths
8. Chatbot → Ask AI
9. Crop Image → Fix Image
10. Voice Input → Speak
11. Reset Password → Change Password
```

### **Service Files:**
- **AuthService** = "Authentication Manager"
- **ApiService** = "Backend Messenger"
- **OCRService** = "Image Text Reader"
- **TranscriptionService** = "Audio to Text"
- **OnboardingService** = "Memory Keeper"
- **StorageService** = "File Uploader"

### **Model Files:**
- **UserModel** = "User Info Box"
- **HadithModels** = "Hadith Info Boxes"

---

## 🔄 **COMPLETE APP FLOW**

```
App Starts
  ↓
Onboarding (if first time)
  ↓
Login Screen
  ↓
Home Screen
  ├─ Text Input → Search → Result Page → Result Detail
  ├─ Image Upload → Crop → OCR → Search → Result Page
  ├─ Voice Input → Transcribe → Search → Result Page
  └─ Chatbot → AI Answers
  ↓
History Page (past searches)
  ↓
Bookmark Page (saved hadiths)
```

---

## 💡 **KEY CONCEPTS TO REMEMBER**

1. **Screens** = What user sees
2. **Services** = What does the work
3. **Models** = What holds the data
4. **Widgets** = Reusable UI components

**Flow Pattern:**
```
Screen → Service → Backend → Service → Model → Screen
```

---

That's the complete project! Easy to remember! 🎉

