# Complete Project Explanation
## Services → Models → Screens → Backend Communication

---

# 📦 **PART 1: SERVICES FOLDER**
## What They Do Between UI and Backend

Services are like **workers** that do specific jobs. They sit between the UI (what user sees) and Backend (Python server).

---

## 🔧 **1. ApiService (`lib/services/api_service.dart`)**

### **Purpose:**
The **messenger** that talks to your Python backend server. It sends requests and receives responses.

### **What It Does:**
- Sends HTTP requests (GET, POST, PUT, DELETE) to backend
- Receives JSON responses from backend
- Converts JSON to Model objects
- Handles errors and network issues

### **Key Methods with Examples:**

#### **`registerUser()`**
**Example:** User signs up
```
UI: User clicks "Sign Up" button
  ↓
ApiService.registerUser() sends:
  POST /api/auth/register
  Body: {"firebase_uid": "abc123", "username": "John", "email": "john@email.com"}
  ↓
Backend: Saves to database, returns JSON
  {"user_id": 1, "username": "John", "created_at": "2024-01-15"}
  ↓
ApiService: Converts JSON to UserModel
  Returns: UserModel(userId: 1, username: "John")
```

#### **`loginUser()`**
**Example:** User logs in
```
UI: User clicks "Login" button
  ↓
ApiService.loginUser() sends:
  POST /api/auth/login
  Body: {"firebase_uid": "abc123"}
  ↓
Backend: Finds user, returns JSON
  {"user_id": 1, "username": "John", "profile_photo_url": "https://..."}
  ↓
ApiService: Converts to UserModel
  Returns: UserModel with all user data
```

#### **`searchHadith()`**
**Example:** User searches for hadith
```
UI: User types "prayer" and clicks search
  ↓
ApiService.searchHadith() sends:
  POST /api/search
  Body: {"query": "prayer", "user_id": 1}
  ↓
Backend: Searches database using FAISS, returns JSON
  {"results": [{"hadith_id": 1, "book": "Bukhari", ...}, ...]}
  ↓
ApiService: Converts JSON to List<HadithSummary>
  Returns: List of hadith results
```

#### **`getHadithDetail()`**
**Example:** User clicks on a hadith
```
UI: User clicks hadith from results
  ↓
ApiService.getHadithDetail() sends:
  GET /api/hadith/123
  ↓
Backend: Gets full hadith data, returns JSON
  {"hadith_id": 123, "arabic_text": "...", "english_text": "...", ...}
  ↓
ApiService: Converts to HadithDetail
  Returns: HadithDetail with all information
```

#### **`saveSearchHistory()`**
**Example:** After search, save to history
```
UI: Search completed
  ↓
ApiService.saveSearchHistory() sends:
  POST /api/history
  Body: {"user_id": 1, "query": "prayer", "results_count": 5}
  ↓
Backend: Saves to history table
  Returns: {"history_id": 10, "created_at": "2024-01-15"}
```

#### **`getHistory()`**
**Example:** User opens history page
```
UI: User opens History Page
  ↓
ApiService.getHistory() sends:
  GET /api/history?user_id=1
  ↓
Backend: Gets all history entries, returns JSON
  {"history": [{"history_id": 10, "query": "prayer", ...}, ...]}
  ↓
ApiService: Converts to List<HistoryEntry>
  Returns: List of past searches
```

#### **`addBookmark()` / `removeBookmark()`**
**Example:** User bookmarks a hadith
```
UI: User clicks bookmark button
  ↓
ApiService.addBookmark() sends:
  POST /api/bookmarks
  Body: {"user_id": 1, "hadith_id": 123}
  ↓
Backend: Saves bookmark, returns JSON
  {"bookmark_id": 5, "created_at": "2024-01-15"}
```

#### **`sendChatMessage()`**
**Example:** User asks AI chatbot
```
UI: User types "What is prayer?" in chatbot
  ↓
ApiService.sendChatMessage() sends:
  POST /api/chat
  Body: {"message": "What is prayer?", "user_id": 1}
  ↓
Backend: Uses OpenAI to generate answer, returns JSON
  {"response": "Prayer is one of the five pillars..."}
  ↓
ApiService: Returns response string
  Returns: "Prayer is one of the five pillars..."
```

### **Remember:**
**ApiService = Backend Messenger**
- Sends requests to Python server
- Receives JSON responses
- Converts JSON to Models
- Used in almost every screen

---

## 🔐 **2. AuthService (`lib/services/auth_service.dart`)**

### **Purpose:**
The **authentication manager** that coordinates Firebase (password security) and Backend (user data).

### **What It Does:**
- Handles login/signup with Firebase
- Coordinates with ApiService to save/get user data
- Manages password reset
- Updates profile information

### **Key Methods with Examples:**

#### **`signUp()`**
**Example:** New user creates account
```
UI: User fills signup form, clicks "Sign Up"
  ↓
AuthService.signUp() called:
  Step 1: Firebase.createUserWithEmailAndPassword()
    → Firebase creates account, encrypts password
    → Returns Firebase UID: "abc123xyz"
  ↓
  Step 2: ApiService.registerUser(firebaseUid: "abc123xyz", ...)
    → Sends to backend
    → Backend saves user to database
    → Returns UserModel
  ↓
AuthService: Returns UserModel to UI
  UI: Shows "Account created!" and navigates to Home
```

#### **`signIn()`**
**Example:** Existing user logs in
```
UI: User enters email/password, clicks "Login"
  ↓
AuthService.signIn() called:
  Step 1: Firebase.signInWithEmailAndPassword()
    → Firebase checks: Email exists? Password correct?
    → If yes: Returns Firebase UID: "abc123xyz"
  ↓
  Step 2: ApiService.loginUser(firebaseUid: "abc123xyz")
    → Sends UID to backend
    → Backend finds user in database
    → Returns UserModel with profile data
  ↓
AuthService: Returns UserModel to UI
  UI: Shows "Login Successful!" and navigates to Home
```

#### **`sendPasswordResetEmail()`**
**Example:** User forgets password
```
UI: User clicks "Forgot Password?" and enters email
  ↓
AuthService.sendPasswordResetEmail(email: "john@email.com")
  → Firebase sends email with password reset link
  → Link format: https://true-hadith.firebaseapp.com/__/auth/action?mode=resetPassword&oobCode=CODE
  → User clicks link in email
  → Link opens in browser (Firebase's default handler)
  → User can reset password directly in the browser
  → After reset, user can login with new password
```

#### **`getCurrentUserData()`**
**Example:** App checks who is logged in
```
App starts / User returns to app
  ↓
AuthService.getCurrentUserData()
  → Gets Firebase UID from Firebase
  → Calls ApiService.loginUser()
  → Returns UserModel
  → App shows Home Screen with user data
```

### **Remember:**
**AuthService = Authentication Coordinator**
- Works with Firebase (passwords)
- Works with ApiService (user data)
- Coordinates both systems
- Used in Login Screen

---

## 📸 **3. OCRService (`lib/services/ocr_service.dart`)**

### **Purpose:**
The **text extractor** that reads text from images using OCR (Optical Character Recognition).

### **What It Does:**
- Takes image file
- Uses Tesseract OCR (local) or EasyOCR (backend) to read text
- Returns extracted text
- Handles Arabic, Urdu, and English

### **Key Methods with Examples:**

#### **`extractTextFromImage()`**
**Example:** User uploads image of hadith
```
UI: User uploads image from gallery
  ↓
OCRService.extractTextFromImage(imageFile)
  Step 1: Tries Tesseract OCR (local, fast)
    → Reads text from image
    → If successful: Returns text
  ↓
  Step 2: If Tesseract fails, tries EasyOCR (backend)
    → Sends image to backend /api/ocr endpoint
    → Backend uses EasyOCR to read text
    → Returns extracted text
  ↓
OCRService: Returns extracted text
  UI: Uses text for hadith search
```

**Real Example:**
```
User uploads image with Arabic text: "صلاة"
  ↓
OCRService extracts: "صلاة" (prayer in Arabic)
  ↓
Text is sent to ApiService.searchHadith()
  ↓
Backend searches for hadiths about prayer
```

### **Remember:**
**OCRService = Image Text Reader**
- Reads text from images
- Tries local first (Tesseract)
- Falls back to backend (EasyOCR)
- Used in Home Screen (image upload)

---

## 🎤 **4. TranscriptionService (`lib/services/transcription_service.dart`)**

### **Purpose:**
The **audio converter** that converts speech/audio files to text.

### **What It Does:**
- Takes audio file
- Sends to backend for speech-to-text conversion
- Returns transcribed text

### **Key Methods with Examples:**

#### **`transcribeAudio()`**
**Example:** User records voice or uploads audio
```
UI: User records voice saying "What is prayer?"
  ↓
TranscriptionService.transcribeAudio(audioFile)
  → Sends audio file to backend /api/transcribe
  → Backend uses speech recognition
  → Returns transcribed text: "What is prayer?"
  ↓
TranscriptionService: Returns text
  UI: Uses text for hadith search
```

**Real Example:**
```
User speaks: "صلاة کیا ہے؟" (What is prayer? in Urdu)
  ↓
TranscriptionService sends audio to backend
  ↓
Backend converts to text: "صلاة کیا ہے؟"
  ↓
Text is sent to ApiService.searchHadith()
  ↓
Backend searches for hadiths
```

### **Remember:**
**TranscriptionService = Audio to Text Converter**
- Converts speech to text
- Sends audio to backend
- Returns transcribed text
- Used in Home Screen (voice input) and Voice Input Page

---

## 💾 **5. StorageService (`lib/services/storage_service.dart`)**

### **Purpose:**
The **file uploader** that uploads files to Firebase Storage.

### **What It Does:**
- Uploads profile photos to Firebase Storage
- Gets download URLs for uploaded files
- Deletes files from Firebase Storage

### **Key Methods with Examples:**

#### **`uploadProfilePhoto()`**
**Example:** User changes profile photo
```
UI: User picks new profile photo
  ↓
StorageService.uploadProfilePhoto(imageFile, userId)
  → Uploads image to Firebase Storage
  → Firebase Storage saves file
  → Returns download URL: "https://firebasestorage.../photo.jpg"
  ↓
StorageService: Returns URL
  → URL is saved to backend via ApiService
  → Profile photo updated
```

#### **`deleteProfilePhoto()`**
**Example:** User removes profile photo
```
UI: User clicks "Remove Photo"
  ↓
StorageService.deleteProfilePhoto(photoUrl)
  → Deletes file from Firebase Storage
  → Returns success
  ↓
Backend is updated via ApiService
  → Profile photo removed
```

### **Remember:**
**StorageService = File Uploader**
- Uploads files to Firebase Storage
- Gets download URLs
- Deletes files
- Used in Profile Photo Widget

---

## 🎯 **6. OnboardingService (`lib/services/onboarding_service.dart`)**

### **Purpose:**
The **memory keeper** that remembers if user has seen the welcome tour.

### **What It Does:**
- Saves onboarding completion status locally
- Checks if user has seen tour before
- Uses SharedPreferences (local storage)

### **Key Methods with Examples:**

#### **`isOnboardingCompleted()`**
**Example:** App starts
```
App starts
  ↓
OnboardingService.isOnboardingCompleted()
  → Checks local storage: "Has user seen tour?"
  → Returns: true (seen) or false (not seen)
  ↓
If false: Show Onboarding Screen
If true: Skip to Login Screen
```

#### **`completeOnboarding()`**
**Example:** User finishes tour
```
UI: User clicks "Get Started" or "Skip"
  ↓
OnboardingService.completeOnboarding()
  → Saves to local storage: "onboarding_completed = true"
  → App remembers forever (until app deleted)
```

### **Remember:**
**OnboardingService = Memory Keeper**
- Remembers if tour was seen
- Uses local storage only
- No backend communication
- Used in Onboarding Screen

---

## 🌐 **7. LanguageDetector (`lib/services/language_detector.dart`)**

### **Purpose:**
The **language identifier** that detects what language text is in.

### **What It Does:**
- Detects if text is Arabic, Urdu, or English
- Helps choose correct OCR method
- Used for better text processing

### **Key Methods with Examples:**

#### **`detectLanguage()`**
**Example:** User uploads image with text
```
OCRService extracts text: "صلاة"
  ↓
LanguageDetector.detectLanguage("صلاة")
  → Detects: Arabic
  ↓
App knows to use Arabic OCR settings
```

### **Remember:**
**LanguageDetector = Language Identifier**
- Detects text language
- Helps with OCR processing
- Used internally by OCRService

---

# 📦 **PART 2: MODELS FOLDER**
## What They Do Between UI and Backend

Models are like **boxes** that hold data in a structured way. They convert JSON (from backend) to Dart objects (for UI).

---

## 👤 **1. UserModel (`lib/models/user_model.dart`)**

### **Purpose:**
A **box** that holds user information.

### **What It Contains:**
- `userId` - User's unique ID number
- `username` - User's name
- `email` - User's email (optional)
- `profilePhotoUrl` - Profile photo link (optional)
- `createdAt` - When user joined

### **Key Methods:**

#### **`fromJson()`**
**Example:** Backend sends user data
```
Backend sends JSON:
  {"user_id": 1, "username": "John", "created_at": "2024-01-15"}
  ↓
UserModel.fromJson(json)
  → Converts to: UserModel(userId: 1, username: "John", createdAt: DateTime(...))
  ↓
UI can use: userModel.username to show "John"
```

#### **`toJson()`**
**Example:** Need to send user data to backend
```
UserModel object: UserModel(userId: 1, username: "John")
  ↓
UserModel.toJson()
  → Converts to: {"user_id": 1, "username": "John"}
  ↓
Can send to backend
```

### **Where It's Used:**
- Login Screen (receives after login/signup)
- Home Screen (displays user info)
- Profile updates (when photo changes)

### **Remember:**
**UserModel = User Info Box**
- Holds user data
- Converts JSON ↔ Object
- Used everywhere user data is needed

---

## 📖 **2. HadithModels (`lib/models/hadith_models.dart`)**

### **Purpose:**
**Boxes** that hold hadith information in different formats.

### **What They Contain:**

#### **`HadithSummary`**
**Purpose:** Short hadith info (for lists)
- `hadithId` - Hadith ID
- `bookName` - Which book (Bukhari, Tirmizi)
- `hadithNumber` - Hadith number
- `chapterNumber` - Chapter number
- `grade` - Classification (Sahih, Hasan, Daif)

**Example:**
```
Backend sends JSON:
  {"hadith_id": 123, "book": "Bukhari", "number": "1", "grade": "Sahih"}
  ↓
HadithSummary.fromJson()
  → HadithSummary(hadithId: 123, bookName: "Bukhari", grade: "Sahih")
  ↓
UI shows in result list
```

#### **`HadithDetail`**
**Purpose:** Complete hadith info (for detail page)
- All fields from HadithSummary PLUS:
- `chapterName` - Chapter name
- `narrator` - Who narrated it
- `arabicText` - Arabic text
- `englishText` - English translation
- `urduText` - Urdu translation

**Example:**
```
Backend sends JSON:
  {"hadith_id": 123, "arabic_text": "صلاة...", "english_text": "Prayer...", ...}
  ↓
HadithDetail.fromJson()
  → HadithDetail with all text in 3 languages
  ↓
UI shows full hadith details
```

#### **`HistoryEntry`**
**Purpose:** Search history entry
- `historyId` - History entry ID
- `queryText` - What user searched
- `createdAt` - When searched

**Example:**
```
Backend sends JSON:
  {"history_id": 10, "query": "prayer", "created_at": "2024-01-15"}
  ↓
HistoryEntry.fromJson()
  → HistoryEntry(historyId: 10, queryText: "prayer", createdAt: DateTime(...))
  ↓
UI shows in history list
```

#### **`BookmarkEntry`**
**Purpose:** Bookmarked hadith
- `bookmarkId` - Bookmark ID
- `hadithId` - Hadith ID
- `summary` - HadithSummary object
- `createdAt` - When bookmarked

**Example:**
```
Backend sends JSON:
  {"bookmark_id": 5, "hadith_id": 123, "hadith": {...}, "created_at": "2024-01-15"}
  ↓
BookmarkEntry.fromJson()
  → BookmarkEntry with hadith summary
  ↓
UI shows in bookmark list
```

### **Where They're Used:**
- **HadithSummary**: Result Page (list of results)
- **HadithDetail**: Result Detail Page (full info)
- **HistoryEntry**: History Page (past searches)
- **BookmarkEntry**: Bookmark Page (saved hadiths)

### **Remember:**
**HadithModels = Hadith Info Boxes**
- HadithSummary = Short info (for lists)
- HadithDetail = Full info (for details)
- HistoryEntry = Past searches
- BookmarkEntry = Saved hadiths

---

# 🔄 **PART 3: HOW SERVICES & MODELS CONNECT UI TO BACKEND**

## **The Complete Flow:**

```
UI (Screen)
  ↓
Service (does the work)
  ↓
Backend (Python server)
  ↓
Service (receives response)
  ↓
Model (converts JSON to object)
  ↓
UI (shows data)
```

## **Real Example: User Searches for Hadith**

```
1. UI: User types "prayer" in Home Screen
   ↓
2. HomeScreen._searchHadith() calls:
   ApiService.searchHadith(query: "prayer", userId: 1)
   ↓
3. ApiService sends HTTP POST:
   POST http://backend:5000/api/search
   Body: {"query": "prayer", "user_id": 1}
   ↓
4. Backend (Python):
   - Receives request
   - Searches database using FAISS
   - Finds matching hadiths
   - Returns JSON: {"results": [{"hadith_id": 123, ...}, ...]}
   ↓
5. ApiService receives JSON:
   - Converts JSON to List<HadithSummary>
   - Returns List<HadithSummary> to UI
   ↓
6. HomeScreen receives List<HadithSummary>:
   - Navigates to Result Page
   - Passes results to Result Page
   ↓
7. Result Page shows list of hadiths
```

---

# 📱 **PART 4: ALL SCREENS WITH METHODS & COMMUNICATION**

---

## 🎯 **SCREEN 1: ONBOARDING SCREEN**

### **Purpose:** Welcome tour for first-time users

### **Files Used:**
1. `lib/screens/onboarding_screen.dart` - The screen itself
2. `lib/services/onboarding_service.dart` - Remembers if tour seen
3. `lib/widgets/custom_button.dart` - Reusable button

### **Key Methods:**

#### **`_onPageChanged(int page)`**
**What it does:** Updates current page when user swipes
```
User swipes to page 2
  → _onPageChanged(2) called
  → Updates _currentPage = 2
  → UI shows page 2, updates dots indicator
```

#### **`_nextPage()`**
**What it does:** Moves to next page or completes
```
User clicks "Next" button
  → _nextPage() called
  → If not last page: Moves to next page
  → If last page: Calls _completeOnboarding()
```

#### **`_completeOnboarding()`**
**What it does:** Saves completion and navigates
```
User clicks "Get Started"
  → OnboardingService.completeOnboarding()
    → Saves to local storage: "seen = true"
  → Navigates to Login Screen
```

### **Communication Flow:**
```
Onboarding Screen
  ↓ (user completes)
OnboardingService.completeOnboarding()
  ↓ (saves locally)
Local Storage (SharedPreferences)
  ↓ (no backend communication)
Login Screen
```

**No Backend Communication** - Only local storage!

---

## 🔐 **SCREEN 2: LOGIN SCREEN**

### **Purpose:** User login and signup

### **Files Used:**
1. `lib/screens/login_screen.dart` - The form
2. `lib/services/auth_service.dart` - Authentication
3. `lib/services/api_service.dart` - Backend communication
4. `lib/models/user_model.dart` - User data

### **Key Methods:**

#### **`_handleSubmit()`**
**What it does:** Validates form and calls auth
```
User clicks "Login" or "Sign Up"
  → Validates form (email format, password length)
  → If valid: Calls AuthService.signUp() or signIn()
  → Shows loading spinner
  → On success: Navigates to Home Screen
  → On error: Shows error message
```

#### **`_toggleMode()`**
**What it does:** Switches between Login and Sign Up
```
User clicks "Sign Up" tab
  → _toggleMode() called
  → Sets _isLogin = false
  → Shows name field
  → Resets animation
```

### **Communication Flow (Sign Up):**
```
Login Screen
  ↓ (user fills form, clicks "Sign Up")
AuthService.signUp()
  ↓
Firebase.createUserWithEmailAndPassword()
  ↓ (creates account, returns UID)
ApiService.registerUser(firebaseUid, username, email)
  ↓ (HTTP POST to backend)
Backend /api/auth/register
  ↓ (saves to database, returns JSON)
ApiService converts JSON to UserModel
  ↓
AuthService returns UserModel
  ↓
Login Screen receives UserModel
  ↓ (shows success, navigates)
Home Screen (with user data)
```

### **Communication Flow (Login):**
```
Login Screen
  ↓ (user enters email/password, clicks "Login")
AuthService.signIn()
  ↓
Firebase.signInWithEmailAndPassword()
  ↓ (checks credentials, returns UID)
ApiService.loginUser(firebaseUid)
  ↓ (HTTP POST to backend)
Backend /api/auth/login
  ↓ (finds user, returns JSON)
ApiService converts JSON to UserModel
  ↓
AuthService returns UserModel
  ↓
Login Screen receives UserModel
  ↓ (shows success, navigates)
Home Screen (with user data)
```

---

## 🏠 **SCREEN 3: HOME SCREEN**

### **Purpose:** Main screen with 3 input methods

### **Files Used:**
1. `lib/screens/home_screen.dart` - Main screen
2. `lib/services/api_service.dart` - Hadith search
3. `lib/services/ocr_service.dart` - Image text extraction
4. `lib/services/transcription_service.dart` - Audio to text
5. `lib/services/storage_service.dart` - Profile photo upload
6. `lib/models/hadith_models.dart` - Hadith data
7. `lib/widgets/profile_photo_widget.dart` - Profile photo

### **Key Methods:**

#### **`_searchHadith()`**
**What it does:** Searches hadith with text input
```
User types "prayer" and clicks search
  → _searchHadith() called
  → ApiService.searchHadith(query: "prayer", userId: 1)
    → Sends to backend /api/search
    → Backend searches, returns results
  → Receives List<HadithSummary>
  → Saves to history via ApiService.saveSearchHistory()
  → Navigates to Result Page with results
```

#### **`_pickImage()`**
**What it does:** Opens image picker
```
User clicks "Upload Image" button
  → _pickImage() called
  → Opens image picker (gallery/camera)
  → User selects image
  → Navigates to Crop Image Page
```

#### **`_processImage()`**
**What it does:** Extracts text from image and searches
```
User crops image
  → _processImage() called with image file
  → OCRService.extractTextFromImage(imageFile)
    → Tries Tesseract OCR (local)
    → If fails: Tries EasyOCR (backend)
    → Returns extracted text
  → Uses text to call _searchHadith()
  → Shows results
```

#### **`_pickAudio()`**
**What it does:** Opens audio file picker
```
User clicks "Upload Audio" button
  → _pickAudio() called
  → Opens file picker
  → User selects audio file
  → TranscriptionService.transcribeAudio(audioFile)
    → Sends to backend /api/transcribe
    → Backend converts to text
    → Returns transcribed text
  → Uses text to call _searchHadith()
```

#### **`_startListening()` / `_stopListening()`**
**What it does:** Voice input for search
```
User clicks mic button
  → _startListening() called
  → Starts speech recognition
  → User speaks: "What is prayer?"
  → Speech converted to text
  → User clicks stop
  → _stopListening() called
  → Uses text to call _searchHadith()
```

#### **`_navigateToChatbot()`**
**What it does:** Opens AI chatbot
```
User clicks chatbot button
  → _navigateToChatbot() called
  → Navigates to Chatbot Screen
```

### **Communication Flow (Text Search):**
```
Home Screen
  ↓ (user types "prayer", clicks search)
ApiService.searchHadith(query: "prayer")
  ↓ (HTTP POST)
Backend /api/search
  ↓ (searches database, returns JSON)
ApiService converts to List<HadithSummary>
  ↓
ApiService.saveSearchHistory()
  ↓ (saves search to history)
Backend /api/history
  ↓
Home Screen receives results
  ↓ (navigates)
Result Page (with hadith list)
```

### **Communication Flow (Image Search):**
```
Home Screen
  ↓ (user uploads image)
Crop Image Page
  ↓ (user crops image)
OCRService.extractTextFromImage()
  ↓ (Tesseract or EasyOCR)
Extracted text: "prayer"
  ↓
ApiService.searchHadith(query: "prayer")
  ↓ (same as text search)
Result Page
```

### **Communication Flow (Voice Search):**
```
Home Screen
  ↓ (user clicks mic, speaks)
Speech Recognition
  ↓ (converts to text)
Text: "What is prayer?"
  ↓
ApiService.searchHadith(query: "What is prayer?")
  ↓ (same as text search)
Result Page
```

---

## 📄 **SCREEN 4: RESULT PAGE**

### **Purpose:** Shows list of search results

### **Files Used:**
1. `lib/screens/result_page.dart` - Results list
2. `lib/models/hadith_models.dart` - HadithSummary

### **Key Methods:**

#### **`build()`**
**What it does:** Displays list of hadith cards
```
Receives List<HadithSummary> from Home Screen
  → Shows each hadith as a card
  → Card shows: Book name, Hadith number, Grade
  → User can click card to see details
```

### **Communication Flow:**
```
Result Page
  ↓ (receives List<HadithSummary>)
Displays cards
  ↓ (user clicks one)
Navigates to Result Detail Page
  ↓ (passes hadithId)
Result Detail Page
```

**No Backend Communication** - Just displays received data!

---

## 📖 **SCREEN 5: RESULT DETAIL PAGE**

### **Purpose:** Shows full hadith details

### **Files Used:**
1. `lib/screens/result_detail_page.dart` - Detail screen
2. `lib/services/api_service.dart` - Gets details and bookmarks
3. `lib/models/hadith_models.dart` - HadithDetail

### **Key Methods:**

#### **`_loadHadithDetail()`**
**What it does:** Gets full hadith information
```
Page loads with hadithId
  → _loadHadithDetail() called
  → ApiService.getHadithDetail(hadithId: 123)
    → Sends GET /api/hadith/123
    → Backend returns full hadith data
  → Converts to HadithDetail
  → Shows: Arabic text, English, Urdu, narrator, etc.
```

#### **`_bookmarkHadith()`**
**What it does:** Saves hadith to bookmarks
```
User clicks bookmark button
  → _bookmarkHadith() called
  → ApiService.addBookmark(userId: 1, hadithId: 123)
    → Sends POST /api/bookmarks
    → Backend saves bookmark
  → Updates UI (bookmark icon filled)
```

#### **`_unbookmarkHadith()`**
**What it does:** Removes from bookmarks
```
User clicks bookmark button again
  → _unbookmarkHadith() called
  → ApiService.removeBookmark(userId: 1, hadithId: 123)
    → Sends DELETE /api/bookmarks
    → Backend removes bookmark
  → Updates UI (bookmark icon empty)
```

### **Communication Flow:**
```
Result Detail Page
  ↓ (loads with hadithId)
ApiService.getHadithDetail(hadithId: 123)
  ↓ (HTTP GET)
Backend /api/hadith/123
  ↓ (returns full hadith JSON)
ApiService converts to HadithDetail
  ↓
Result Detail Page shows all details
  ↓ (user bookmarks)
ApiService.addBookmark()
  ↓ (HTTP POST)
Backend /api/bookmarks
  ↓ (saves bookmark)
Bookmark saved
```

---

## 📚 **SCREEN 6: HISTORY PAGE**

### **Purpose:** Shows past searches

### **Files Used:**
1. `lib/screens/history_page.dart` - History list
2. `lib/services/api_service.dart` - Gets and deletes history
3. `lib/models/hadith_models.dart` - HistoryEntry

### **Key Methods:**

#### **`_loadHistory()`**
**What it does:** Gets all past searches
```
Page loads
  → _loadHistory() called
  → ApiService.getHistory(userId: 1)
    → Sends GET /api/history?user_id=1
    → Backend returns all history entries
  → Converts to List<HistoryEntry>
  → Shows list: Query, Date, Results count
```

#### **`_deleteHistory()`**
**What it does:** Deletes one history entry
```
User clicks delete button
  → _deleteHistory(historyId: 10) called
  → ApiService.deleteSearchHistory(historyId: 10)
    → Sends DELETE /api/history/10
    → Backend deletes entry
  → Refreshes list
```

### **Communication Flow:**
```
History Page
  ↓ (loads)
ApiService.getHistory(userId: 1)
  ↓ (HTTP GET)
Backend /api/history?user_id=1
  ↓ (returns JSON list)
ApiService converts to List<HistoryEntry>
  ↓
History Page shows list
  ↓ (user clicks one)
Navigates to History Detail Page
```

---

## 🔖 **SCREEN 7: BOOKMARK PAGE**

### **Purpose:** Shows saved hadiths

### **Files Used:**
1. `lib/screens/bookmark_page.dart` - Bookmark list
2. `lib/services/api_service.dart` - Gets and deletes bookmarks
3. `lib/models/hadith_models.dart` - BookmarkEntry

### **Key Methods:**

#### **`_loadBookmarks()`**
**What it does:** Gets all bookmarked hadiths
```
Page loads
  → _loadBookmarks() called
  → ApiService.getBookmarks(userId: 1)
    → Sends GET /api/bookmarks?user_id=1
    → Backend returns all bookmarks
  → Converts to List<BookmarkEntry>
  → Shows list of saved hadiths
```

#### **`_deleteBookmark()`**
**What it does:** Removes bookmark
```
User clicks remove button
  → _deleteBookmark(bookmarkId: 5) called
  → ApiService.removeBookmark(bookmarkId: 5)
    → Sends DELETE /api/bookmarks/5
    → Backend removes bookmark
  → Refreshes list
```

### **Communication Flow:**
```
Bookmark Page
  ↓ (loads)
ApiService.getBookmarks(userId: 1)
  ↓ (HTTP GET)
Backend /api/bookmarks?user_id=1
  ↓ (returns JSON list)
ApiService converts to List<BookmarkEntry>
  ↓
Bookmark Page shows list
  ↓ (user clicks one)
Navigates to Bookmark Detail Page
```

---

## 🤖 **SCREEN 8: CHATBOT SCREEN**

### **Purpose:** AI chatbot for Islamic questions

### **Files Used:**
1. `lib/screens/chatbot_screen.dart` - Chat interface
2. `lib/services/api_service.dart` - Sends messages to AI

### **Key Methods:**

#### **`_sendMessage()`**
**What it does:** Sends user message to AI
```
User types "What is prayer?" and sends
  → _sendMessage() called
  → ApiService.sendChatMessage(message: "What is prayer?", userId: 1)
    → Sends POST /api/chat
    → Backend uses OpenAI to generate answer
    → Returns AI response
  → Shows AI response in chat
```

#### **`_loadChatHistory()`**
**What it does:** Gets past conversations
```
Page loads
  → _loadChatHistory() called
  → ApiService.getChatHistory(userId: 1)
    → Sends GET /api/chat/history
    → Backend returns past messages
  → Shows chat history
```

### **Communication Flow:**
```
Chatbot Screen
  ↓ (user sends message)
ApiService.sendChatMessage(message: "What is prayer?")
  ↓ (HTTP POST)
Backend /api/chat
  ↓ (uses OpenAI)
Backend returns AI response
  ↓
Chatbot Screen shows response
```

---

## 🖼️ **SCREEN 9: CROP IMAGE PAGE**

### **Purpose:** Allows user to crop uploaded image

### **Files Used:**
1. `lib/screens/crop_image_page.dart` - Cropping interface

### **Key Methods:**

#### **`_cropImage()`**
**What it does:** Crops the image
```
User adjusts crop area
  → _cropImage() called
  → Crops image to selected area
  → Returns cropped image
```

### **Communication Flow:**
```
Crop Image Page
  ↓ (user crops image)
Returns cropped image
  ↓ (to Home Screen)
Home Screen processes image
  ↓ (OCRService extracts text)
Text search
```

**No Backend Communication** - Just image processing!

---

## 🎤 **SCREEN 10: VOICE INPUT PAGE**

### **Purpose:** Voice recording for search

### **Files Used:**
1. `lib/screens/voice_input_page.dart` - Voice recorder
2. `lib/services/transcription_service.dart` - Audio to text

### **Key Methods:**

#### **`_startRecording()`**
**What it does:** Starts voice recording
```
User clicks record button
  → _startRecording() called
  → Starts audio recording
  → Shows recording indicator
```

#### **`_stopRecording()`**
**What it does:** Stops and processes audio
```
User clicks stop
  → _stopRecording() called
  → TranscriptionService.transcribeAudio(audioFile)
    → Sends to backend /api/transcribe
    → Backend converts to text
  → Uses text for search
```

### **Communication Flow:**
```
Voice Input Page
  ↓ (user records voice)
TranscriptionService.transcribeAudio()
  ↓ (HTTP POST)
Backend /api/transcribe
  ↓ (speech-to-text)
Backend returns text
  ↓
Text used for search
```

---

## 🔑 **SCREEN 11: RESET PASSWORD SCREEN**

### **Purpose:** Reset forgotten password

### **Files Used:**
1. `lib/screens/reset_password_screen.dart` - Reset form
2. `lib/services/auth_service.dart` - Password reset

### **Key Methods:**

#### **`_resetPassword()`**
**What it does:** Resets password with Firebase
```
User enters new password
  → _resetPassword() called
  → AuthService.confirmPasswordReset(code: "abc", newPassword: "new123")
    → Firebase updates password
  → Shows success message
  → Navigates to Login Screen
```

### **Communication Flow:**
```
User clicks "Forgot Password?" in Login Screen
  ↓
AuthService.sendPasswordResetEmail(email)
  ↓ (Firebase sends email)
User receives email with reset link
  ↓
User clicks link → Opens in browser (Firebase's default handler)
  ↓
User resets password directly in the browser
  ↓
After reset, user can login with new password
```

**Note:** By default, password reset links open in the browser where users can reset their password directly. The Reset Password Screen in the app is available if deep linking is configured in the future.

**No Backend Communication** - Only Firebase!

---

# 📊 **COMPLETE SUMMARY**

## **Services (Workers):**
- **ApiService** = Backend Messenger (talks to Python server)
- **AuthService** = Authentication Manager (Firebase + Backend)
- **OCRService** = Image Text Reader (reads text from images)
- **TranscriptionService** = Audio to Text (converts speech)
- **StorageService** = File Uploader (uploads to Firebase)
- **OnboardingService** = Memory Keeper (local storage)

## **Models (Boxes):**
- **UserModel** = User Info Box
- **HadithSummary** = Short Hadith Info
- **HadithDetail** = Full Hadith Info
- **HistoryEntry** = Past Search
- **BookmarkEntry** = Saved Hadith

## **Flow Pattern:**
```
UI → Service → Backend → Service → Model → UI
```

---

That's the complete project explanation! Easy to understand and remember! 🎉

