# 📚 TRUE HADITH PROJECT - Complete File-by-File Explanation

## 🎯 PROJECT OVERVIEW
**True Hadith** is a Flutter app that verifies hadith authenticity using AI. Users can search by:
- **Text** (typing)
- **Voice** (speech-to-text)
- **Image** (OCR - Optical Character Recognition)
- **Audio File** (transcription)

---

## 📁 FILE STRUCTURE & PURPOSE

### 🔷 **1. MODELS** (Data Structures)
*Location: `lib/models/`*

#### **`user_model.dart`** - User Data Container
**Purpose:** Stores user information from backend
- **Fields:** `userId`, `username`, `email`, `profilePhotoUrl`, `createdAt`
- **Used by:** All screens that need user info (HomeScreen, Drawer, Profile)
- **Key Method:** `fromJson()` - Converts backend JSON to UserModel object

#### **`hadith_models.dart`** - Hadith Data Containers
**Purpose:** Defines data structures for hadith search results
- **Classes:**
  - `HadithSummary` - Brief info (bookName, hadithNumber, grade) → Used in ResultPage
  - `HadithDetail` - Full info (all text in Arabic/English/Urdu) → Used in ResultDetailPage
  - `BookmarkEntry` - Saved hadith → Used in BookmarkPage
  - `HistoryEntry` - Search history → Used in HistoryPage
- **Used by:** ResultPage, ResultDetailPage, BookmarkPage, HistoryPage

---

### 🔷 **2. SERVICES** (Business Logic)
*Location: `lib/services/`*

#### **`api_service.dart`** - Backend Communication Hub ⭐
**Purpose:** ALL backend API calls go through here
- **Base URL:** `http://192.168.0.104:5000/api`
- **Key Methods:**
  - `registerUser()` - Create new account → Used by LoginScreen (signup)
  - `loginUser()` - Get user data → Used by LoginScreen (login)
  - `searchHadiths()` - Search hadiths → Used by HomeScreen
  - `getHadithDetailWithBookmark()` - Get full hadith → Used by ResultDetailPage
  - `createBookmark()` / `deleteBookmark()` - Manage bookmarks → Used by BookmarkPage
  - `getHistory()` / `deleteHistory()` - Manage history → Used by HistoryPage
  - `sendChatMessage()` - AI chatbot → Used by ChatbotScreen
  - `getAllUserMessages()` - Load chat history → Used by ChatbotScreen
  - `updateProfilePhoto()` / `deleteProfilePhoto()` - Profile photos → Used by ProfilePhotoWidget

#### **`auth_service.dart`** - Firebase Authentication Manager
**Purpose:** Handles all Firebase auth operations
- **Key Methods:**
  - `signUp()` - Create Firebase user + register in backend → Used by LoginScreen
  - `signIn()` - Login with Firebase + get backend data → Used by LoginScreen
  - `sendPasswordResetEmail()` - Send reset link → Used by LoginScreen
  - `confirmPasswordReset()` - Reset password → Used by ResetPasswordScreen
  - `signOut()` - Logout → Used by HomeDrawer
  - `getCurrentUserData()` - Get logged-in user → Used by AuthWrapper in main.dart
  - `updateProfilePhoto()` / `deleteProfilePhoto()` - Profile management → Used by ProfilePhotoWidget

#### **`ocr_service.dart`** - Image Text Extraction Engine ⭐
**Purpose:** Extracts text from images using OCR
- **Strategy:**
  - **English** → Tesseract OCR (local, fast)
  - **Arabic/Urdu** → EasyOCR (backend API, accurate)
- **Key Methods:**
  - `extractTextFromImageWithDetails()` - Main OCR function → Used by HomeScreen
  - `_extractWithTesseract()` - English OCR (local)
  - `_extractWithEasyOCRWithDetails()` - Arabic/Urdu OCR (backend)
  - `_preprocessImageEnglish()` - Image enhancement for English
  - `_preprocessImageArabicUrdu()` - Image enhancement for Arabic/Urdu
- **Used by:** HomeScreen (after image selection)

#### **`language_detector.dart`** - Script Type Detector
**Purpose:** Detects if image contains Arabic/Urdu or English text
- **Key Method:** `detectScript()` - Analyzes image visually
- **Note:** Currently NOT actively used (user selects language manually in CropImagePage)
- **Used by:** (Reserved for future auto-detection)

#### **`storage_service.dart`** - Firebase Storage Manager
**Purpose:** Handles file uploads/downloads from Firebase Storage
- **Key Methods:**
  - `pickImage()` - Select image from gallery/camera → Used by HomeScreen, ProfilePhotoWidget
  - `uploadProfilePhoto()` - Upload to Firebase Storage → Used by ProfilePhotoWidget
  - `deleteProfilePhoto()` - Delete from Firebase Storage → Used by ProfilePhotoWidget
- **Used by:** HomeScreen, ProfilePhotoWidget

#### **`transcription_service.dart`** - Audio-to-Text Converter
**Purpose:** Converts audio files to text using backend Whisper API
- **Key Method:**
  - `transcribeAudio()` - Send audio to backend → Used by AudioTrimmingPage
- **Parameters:** `audioPath`, `startSeconds`, `endSeconds`, `language` (en/ur/ar)
- **Used by:** AudioTrimmingPage

#### **`audio_trimming_service.dart`** - Audio Processing Helper
**Purpose:** Client-side audio utilities (waveform, validation)
- **Key Methods:**
  - `generateWaveform()` - Create visual waveform → Used by AudioTrimmingPage
  - `validateTrimParameters()` - Validate start/end times → Used by AudioTrimmingPage
- **Used by:** AudioTrimmingPage

#### **`onboarding_service.dart`** - First-Time User Manager
**Purpose:** Tracks if user has seen onboarding screens
- **Key Methods:**
  - `isOnboardingCompleted()` - Check status → Used by AuthWrapper in main.dart
  - `completeOnboarding()` - Mark as completed → Used by OnboardingScreen
- **Used by:** main.dart (AuthWrapper), OnboardingScreen

---

### 🔷 **3. SCREENS** (User Interface)
*Location: `lib/screens/`*

#### **`main.dart`** - App Entry Point & Navigation Hub ⭐
**Purpose:** App initialization, routing, auth state management
- **Key Components:**
  - `MyApp` - MaterialApp with routes
  - `AuthWrapper` - Decides: Onboarding → Login → HomeScreen
  - **Routes:** All screen navigation paths defined here
- **Flow:**
  1. Check onboarding → Show OnboardingScreen if needed
  2. Check Firebase auth → Show LoginScreen or HomeScreen
  3. Handle deep links (password reset)

#### **`onboarding_screen.dart`** - First-Time User Introduction
**Purpose:** Shows 3-page introduction to app features
- **Key Methods:**
  - `_completeOnboarding()` - Saves completion status → Calls OnboardingService
- **Used by:** main.dart (AuthWrapper)

#### **`login_screen.dart`** - Authentication Screen
**Purpose:** Login, Signup, Password Reset
- **Key Methods:**
  - `_handleSubmit()` - Login or Signup → Calls AuthService
  - `_showForgotPasswordDialog()` - Password reset → Calls AuthService.sendPasswordResetEmail()
- **Uses:** AuthService (signIn, signUp, sendPasswordResetEmail)
- **Navigates to:** HomeScreen after successful login

#### **`reset_password_screen.dart`** - Password Reset Handler
**Purpose:** Handles password reset from email link
- **Uses:** AuthService (confirmPasswordReset, verifyPasswordResetCode)
- **Opened via:** Deep link from email

#### **`home_screen.dart`** - Main Search Interface ⭐
**Purpose:** Central hub for all search methods
- **Key Features:**
  - Search bar with voice input (mic button)
  - "+" button → Opens input options (Camera, Gallery, Audio)
  - Drawer → Profile, History, Bookmarks
  - Floating button → Chatbot
- **Key Methods:**
  - `_submitQuery()` - Search hadiths → Calls ApiService.searchHadiths() → Navigates to ResultPage
  - `_toggleListening()` - Voice input → Uses speech_to_text package
  - `_showInputOptionsSheet()` - Shows Camera/Gallery/Audio options
- **Uses:** 
  - ApiService (searchHadiths)
  - OCRService (extractTextFromImageWithDetails) - After image selection
  - StorageService (pickImage)
- **Navigates to:** ResultPage, CropImagePage, AudioTrimmingPage, ChatbotScreen

#### **`crop_image_page.dart`** - Image Cropping & Language Selection
**Purpose:** Crop image + Select language for OCR
- **Key Features:**
  - Free-form cropping (optional)
  - **MANDATORY language selection** (English/Urdu/Arabic)
  - Preview after crop
- **Key Methods:**
  - `_cropAndSave()` - Crop image with padding
  - `_skipCrop()` - Use original image
  - `_extractText()` - Return to HomeScreen with image path + language
- **Returns:** `{imagePath: String, language: SelectedLanguage}` to HomeScreen
- **Used by:** HomeScreen (after camera/gallery selection)

#### **`result_page.dart`** - Search Results List
**Purpose:** Shows list of matching hadiths
- **Key Features:**
  - Displays HadithSummary cards
  - Shows: bookName, hadithNumber, chapterNumber, grade (color-coded)
- **Key Method:**
  - `_ResultCard` - Individual result card → Navigates to ResultDetailPage on tap
- **Uses:** HadithSummary model
- **Navigates to:** ResultDetailPage

#### **`result_detail_page.dart`** - Full Hadith Details
**Purpose:** Shows complete hadith information
- **Key Features:**
  - Full text (Arabic, English, Urdu)
  - Bookmark button
  - Narrator, grade, chapter info
- **Uses:** ApiService (getHadithDetailWithBookmark, createBookmark, deleteBookmark)
- **Used by:** ResultPage

#### **`history_page.dart`** - Search History
**Purpose:** Shows past search queries
- **Uses:** ApiService (getHistory, deleteHistory)
- **Navigates to:** HistoryDetailPage

#### **`history_detail_page.dart`** - History Entry Details
**Purpose:** Shows details of a past search
- **Uses:** HistoryEntry model
- **Used by:** HistoryPage

#### **`bookmark_page.dart`** - Saved Hadiths
**Purpose:** Shows bookmarked hadiths
- **Uses:** ApiService (getBookmarks, deleteBookmark)
- **Navigates to:** BookmarkDetailPage

#### **`bookmark_detail_page.dart`** - Bookmarked Hadith Details
**Purpose:** Shows full details of bookmarked hadith
- **Uses:** ApiService (getHadithDetailWithBookmark)
- **Used by:** BookmarkPage

#### **`chatbot_screen.dart`** - AI Assistant Chat
**Purpose:** Chat interface with AI for Islamic questions
- **Key Methods:**
  - `_loadPreviousMessages()` - Load chat history → Calls ApiService.getAllUserMessages()
  - `_sendMessage()` - Send question → Calls ApiService.sendChatMessage()
- **Uses:** ApiService (sendChatMessage, getAllUserMessages)
- **Features:**
  - User messages (RHS - right side)
  - Bot messages (LHS - left side)
  - Auto-scroll to bottom
  - Loading indicators

#### **`voice_input_page.dart`** - Standalone Voice Input
**Purpose:** Full-screen voice input (currently placeholder)
- **Note:** Currently not fully implemented (TODO in code)
- **Used by:** (Reserved for future use)

#### **`audio_trimming_page.dart`** - Audio Trimming & Transcription
**Purpose:** Trim audio file + Generate transcript
- **Key Features:**
  - Visual waveform with draggable handles
  - Playback controls (play/pause/stop)
  - **MANDATORY language selection** (English/Urdu/Arabic)
  - Generate transcript button
- **Key Methods:**
  - `_loadAudio()` - Load audio file
  - `_generateWaveform()` - Create waveform visualization
  - `_togglePlayPause()` - Play/pause audio
  - `_generateTranscript()` - Transcribe audio → Calls TranscriptionService
- **Uses:** 
  - TranscriptionService (transcribeAudio)
  - AudioTrimmingService (generateWaveform, validateTrimParameters)
- **Returns:** Transcript text to HomeScreen
- **Used by:** HomeScreen (after audio file selection)

---

### 🔷 **4. WIDGETS** (Reusable UI Components)
*Location: `lib/widgets/`*

#### **`custom_button.dart`** - Standardized Button
**Purpose:** Consistent button styling across app
- **Features:** Loading state, icons, custom colors
- **Used by:** All screens

#### **`profile_photo_widget.dart`** - Profile Photo Display & Management
**Purpose:** Shows user photo with update/delete options
- **Key Methods:**
  - `_showProfilePhotoMenu()` - Bottom sheet with options
  - `_pickAndUploadPhoto()` - Upload new photo → Uses StorageService + AuthService
  - `_deletePhoto()` - Delete photo → Uses AuthService
- **Uses:** StorageService, AuthService
- **Used by:** HomeDrawer (in HomeScreen)

---

### 🔷 **5. UTILS** (Helper Functions)
*Location: `lib/utils/`*

#### **`apps_colors.dart`** - Color Palette
**Purpose:** Centralized color definitions
- **Key Colors:**
  - `primary` - Emerald green (#2E8B57)
  - `background` - Ivory white
  - `textPrimary`, `textSecondary` - Text colors
  - `sahih`, `hasan`, `daif`, `mawdu` - Hadith grade colors
- **Used by:** All screens and widgets

#### **`url_handler.dart`** - Deep Link Parser
**Purpose:** Extracts action codes from password reset URLs
- **Key Methods:**
  - `extractActionCodeFromUrl()` - Get reset code from URL
  - `isPasswordResetUrl()` - Check if URL is reset link
- **Used by:** main.dart (AuthWrapper) for deep link handling

---

## 🔄 DATA FLOW EXAMPLES

### **Example 1: Image Search Flow**
```
User taps "+" → HomeScreen._showInputOptionsSheet()
  → User selects "Camera" → StorageService.pickImage()
  → Navigate to CropImagePage
  → User crops + selects language (English/Urdu/Arabic)
  → CropImagePage returns {imagePath, language}
  → HomeScreen calls OCRService.extractTextFromImageWithDetails()
    → If English → Tesseract OCR (local)
    → If Arabic/Urdu → EasyOCR (backend API)
  → Extracted text → HomeScreen._searchController.text
  → User submits → HomeScreen._submitQuery()
  → ApiService.searchHadiths() → Backend FAISS search
  → Navigate to ResultPage with results
```

### **Example 2: Audio Search Flow**
```
User taps "+" → HomeScreen._showInputOptionsSheet()
  → User selects "Upload MP3/WAV"
  → FilePicker selects audio file
  → Navigate to AudioTrimmingPage
  → User trims audio (selects start/end) + selects language
  → User taps "Generate Transcript"
  → AudioTrimmingPage calls TranscriptionService.transcribeAudio()
  → Backend Whisper API transcribes audio
  → Transcript returned to HomeScreen
  → HomeScreen._searchController.text = transcript
  → User submits → Search flow continues...
```

### **Example 3: Login Flow**
```
App starts → main.dart AuthWrapper
  → Check OnboardingService.isOnboardingCompleted()
    → If false → Show OnboardingScreen
    → If true → Check AuthService.isSignedIn()
      → If false → Show LoginScreen
      → If true → Load user data → Show HomeScreen

User on LoginScreen:
  → Enters email/password → _handleSubmit()
  → AuthService.signIn() → Firebase auth + ApiService.loginUser()
  → Get UserModel → Navigate to HomeScreen
```

### **Example 4: Chatbot Flow**
```
User taps floating button → Navigate to ChatbotScreen
  → ChatbotScreen.initState() → _loadPreviousMessages()
  → ApiService.getAllUserMessages() → Load all chat history
  → User types message → _sendMessage()
  → ApiService.sendChatMessage() → Backend AI responds
  → Display bot reply in chat bubble
```

---

## 🎯 KEY CONCEPTS TO REMEMBER

### **1. Service Layer Pattern**
- **Services** = Business logic (API calls, auth, OCR, etc.)
- **Screens** = UI only, call services for data
- **Models** = Data structures

### **2. Language Selection is MANDATORY**
- **CropImagePage:** User MUST select language before OCR
- **AudioTrimmingPage:** User MUST select language before transcription
- **Why?** Ensures correct OCR/transcription engine is used

### **3. OCR Strategy**
- **English** → Tesseract (local, fast, free)
- **Arabic/Urdu** → EasyOCR (backend, accurate, requires internet)

### **4. Navigation Flow**
- **main.dart** defines all routes
- Screens navigate using `Navigator.pushNamed()` or `Navigator.push()`
- Data passed via route `arguments`

### **5. Firebase Integration**
- **AuthService** handles Firebase Authentication
- **StorageService** handles Firebase Storage (profile photos)
- Backend API stores user data in PostgreSQL

---

## 📝 QUICK REFERENCE

| Screen | Main Purpose | Key Service Used |
|--------|-------------|-------------------|
| OnboardingScreen | First-time intro | OnboardingService |
| LoginScreen | Auth | AuthService |
| HomeScreen | Search hub | ApiService, OCRService |
| CropImagePage | Image crop + language | (Returns to HomeScreen) |
| ResultPage | Show results | ApiService |
| ResultDetailPage | Full hadith | ApiService |
| ChatbotScreen | AI chat | ApiService |
| AudioTrimmingPage | Audio trim + transcribe | TranscriptionService |
| HistoryPage | Search history | ApiService |
| BookmarkPage | Saved hadiths | ApiService |

---

## 🚀 REMEMBER THIS!
1. **ApiService** = All backend communication
2. **AuthService** = All Firebase auth
3. **OCRService** = Image text extraction
4. **Language selection** = Required for OCR & transcription
5. **main.dart** = App entry point & routing
6. **HomeScreen** = Central hub for all search methods

