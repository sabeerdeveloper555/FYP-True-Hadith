# Comprehensive Use Case: True Hadith Application

## **Actor**
- **User**: The only actor in the system who can perform all operations

---

## **Use Case: Complete Hadith Search and Learning Experience**

### **Overview**
A user interacts with the True Hadith mobile application to search, explore, bookmark, and learn about Islamic hadiths (sayings of Prophet Muhammad) through multiple input methods, with AI assistance and personal history tracking.

---

## **Detailed Use Case Flow**

### **1. Initial Setup & Authentication**

#### **1.1 First-Time User Onboarding**
- **Precondition**: User installs the app for the first time
- **Main Flow**:
  1. User opens the application
  2. System displays onboarding screens (3 pages)
  3. User views welcome tour with app features introduction
  4. User can swipe through pages or click "Next"
  5. User can skip onboarding at any time
  6. System saves onboarding completion status
  7. User proceeds to login screen

#### **1.2 User Registration**
- **Precondition**: User is new and hasn't registered
- **Main Flow**:
  1. User selects "Sign Up" on login screen
  2. User enters email and password
  3. System validates email format and password strength
  4. System creates Firebase authentication account
  5. System sends verification email (if configured)
  6. System calls backend API to register user profile
  7. Backend creates user record with:
     - Firebase UID
     - Username
     - Email
     - Profile creation timestamp
  8. System receives user data and creates UserModel
  9. System navigates to Home Screen
  10. User is now authenticated and logged in

#### **1.3 User Login**
- **Precondition**: User has existing account
- **Main Flow**:
  1. User enters email and password
  2. System authenticates with Firebase
  3. System calls backend API with Firebase UID
  4. Backend retrieves user profile
  5. System receives user data
  6. System navigates to Home Screen
  7. User can now access all features

#### **1.4 Password Reset**
- **Precondition**: User forgot password
- **Main Flow**:
  1. User clicks "Forgot Password" on login screen
  2. User enters email address
  3. System sends password reset email via Firebase
  4. User receives email with reset link
  5. User clicks link (opens in browser or app via deep link)
  6. System validates reset token
  7. User enters new password
  8. System updates password in Firebase
  9. User can now login with new password

---

### **2. Profile Management**

#### **2.1 View Profile**
- **Precondition**: User is logged in
- **Main Flow**:
  1. User opens drawer menu from Home Screen
  2. System displays profile section with:
     - Profile photo (or placeholder)
     - Username
     - Member since date
  3. User can view profile information

#### **2.2 Upload/Update Profile Photo**
- **Precondition**: User is logged in
- **Main Flow**:
  1. User taps on profile photo in drawer
  2. System shows options: "Take Photo", "Choose from Gallery", "Delete Photo"
  3. User selects "Take Photo" or "Choose from Gallery"
  4. System opens camera or gallery
  5. User selects/captures image
  6. System uploads image to Firebase Storage
  7. System receives image URL
  8. System calls backend API to update profile photo
  9. Backend updates user record with new photo URL
  10. System updates UI with new photo
  11. Profile photo is now updated

#### **2.3 Delete Profile Photo**
- **Precondition**: User has profile photo
- **Main Flow**:
  1. User taps on profile photo
  2. User selects "Delete Photo"
  3. System confirms deletion
  4. System calls backend API to remove photo
  5. Backend updates user record (sets photo URL to null)
  6. System updates UI to show placeholder
  7. Profile photo is removed

---

### **3. Hadith Search - Multiple Input Methods**

#### **3.1 Search by Text Input**
- **Precondition**: User is on Home Screen
- **Main Flow**:
  1. User types query in search bar
  2. User presses search/enter
  3. System shows loading indicator
  4. System calls backend API with:
     - User ID
     - Search query text
  5. Backend performs semantic search on hadith database
  6. Backend returns list of matching hadith summaries
  7. System saves search to history
  8. System navigates to Results Page
  9. User sees list of matching hadiths with:
     - Book name
     - Hadith number
     - Chapter number
     - Authenticity grade

#### **3.2 Search by Voice Input**
- **Precondition**: User is on Home Screen, microphone permissions granted
- **Main Flow**:
  1. User taps microphone icon in search bar
  2. System starts speech recognition
  3. System shows pulsing animation on mic button
  4. User speaks query (supports Arabic, Urdu, English)
  5. System displays real-time transcription in search bar
  6. User taps mic again to stop
  7. System finalizes transcription
  8. System uses transcribed text as search query
  9. System proceeds with search (same as 3.1, steps 3-9)

#### **3.3 Search by Image (Camera)**
- **Precondition**: User is on Home Screen, camera permissions granted
- **Main Flow**:
  1. User taps "+" button in search bar
  2. System shows input options sheet
  3. User selects "Open Camera"
  4. System opens device camera
  5. User captures photo of hadith text
  6. System navigates to Crop Image Page
  7. User adjusts crop area to focus on text
  8. User selects language (Arabic/Urdu/English) if needed
  9. User confirms crop
  10. System shows loading dialog ("Extracting text...")
  11. System runs OCR (Optical Character Recognition):
     - Uses Tesseract OCR locally
     - Or sends to backend OCR service
     - Processes image with selected language
  12. System extracts text from image
  13. System displays extracted text in search bar
  14. User can edit text if needed
  15. User submits search
  16. System proceeds with search (same as 3.1, steps 3-9)

#### **3.4 Search by Image (Gallery)**
- **Precondition**: User is on Home Screen, storage permissions granted
- **Main Flow**:
  1. User taps "+" button
  2. User selects "Upload Image"
  3. System opens device gallery
  4. User selects image containing hadith text
  5. System navigates to Crop Image Page
  6. (Same as 3.3, steps 7-16)

#### **3.5 Search by Audio File**
- **Precondition**: User is on Home Screen
- **Main Flow**:
  1. User taps "+" button
  2. User selects "Upload MP3/WAV File"
  3. System opens file picker
  4. User selects audio file
  5. System navigates to Audio Trimming Page
  6. System loads audio file
  7. User plays audio to preview
  8. User selects start and end points (optional trimming)
  9. User confirms selection
  10. System shows loading indicator
  11. System uploads audio to backend
  12. Backend performs speech-to-text transcription
  13. Backend returns transcribed text
  14. System displays transcribed text in search bar
  15. User can edit text if needed
  16. User submits search
  17. System proceeds with search (same as 3.1, steps 3-9)

---

### **4. Viewing Search Results**

#### **4.1 Browse Search Results**
- **Precondition**: Search completed successfully
- **Main Flow**:
  1. System displays Results Page with list of hadith summaries
  2. Each result shows:
     - Book name (e.g., "Sahih Bukhari")
     - Hadith number
     - Chapter number
     - Authenticity grade (e.g., "Sahih", "Hasan")
  3. User scrolls through results
  4. User can tap any result to view details

#### **4.2 View Hadith Details**
- **Precondition**: User is on Results Page
- **Main Flow**:
  1. User taps on a hadith result
  2. System shows loading indicator
  3. System calls backend API with hadith ID and user ID
  4. Backend retrieves full hadith details
  5. Backend checks if hadith is bookmarked by user
  6. System displays Hadith Detail Page with:
     - **Arabic Text**: Original Arabic narration
     - **English Translation**: English version
     - **Urdu Translation**: Urdu version
     - **Grade**: Authenticity rating
     - **Narrator**: Chain of narrators
     - **Chapter Name**: Full chapter title
     - **Book Reference**: Complete citation
     - **Bookmark Status**: Whether it's saved
  7. User can read hadith in preferred language
  8. User can bookmark/unbookmark hadith
  9. User can navigate back to results

---

### **5. Bookmark Management**

#### **5.1 Bookmark a Hadith**
- **Precondition**: User is viewing hadith details
- **Main Flow**:
  1. User taps bookmark icon on Hadith Detail Page
  2. System calls backend API to create bookmark
  3. Backend creates bookmark record:
     - User ID
     - Hadith ID
     - Creation timestamp
  4. System updates UI to show bookmarked state
  5. Hadith is now saved to user's bookmarks

#### **5.2 View All Bookmarked Hadiths**
- **Precondition**: User is logged in
- **Main Flow**:
  1. User taps bookmark icon in app bar (or from drawer menu)
  2. System shows loading indicator
  3. System calls backend API with user ID
  4. Backend retrieves all bookmarked hadiths
  5. System displays Bookmark Page with list of:
     - Book name
     - Hadith number
     - Chapter number
     - Grade
     - Bookmarked date
  6. User can scroll through bookmarks
  7. User can tap any bookmark to view details

#### **5.3 View Bookmark Details**
- **Precondition**: User is on Bookmark Page
- **Main Flow**:
  1. User taps on a bookmarked hadith
  2. System navigates to Bookmark Detail Page
  3. System displays full hadith details (same as 4.2)
  4. System shows bookmark status as "bookmarked"
  5. User can read hadith
  6. User can remove bookmark

#### **5.4 Remove Bookmark**
- **Precondition**: User is viewing bookmarked hadith
- **Main Flow**:
  1. User taps bookmark icon (already bookmarked)
  2. System confirms removal
  3. System calls backend API to delete bookmark
  4. Backend removes bookmark record
  5. System updates UI to show unbookmarked state
  6. Bookmark is removed from user's list

---

### **6. Search History Management**

#### **6.1 View Search History**
- **Precondition**: User is logged in
- **Main Flow**:
  1. User opens drawer menu
  2. User taps "History"
  3. System shows loading indicator
  4. System calls backend API with user ID
  5. Backend retrieves all search history entries
  6. System displays History Page with list of:
     - Search query text
     - Search date/time
  7. Entries are sorted by most recent first
  8. User can scroll through history

#### **6.2 View History Entry Details**
- **Precondition**: User is on History Page
- **Main Flow**:
  1. User taps on a history entry
  2. System navigates to History Detail Page
  3. System displays:
     - Original search query
     - Search timestamp
     - Option to re-search
  4. User can tap "Search Again" to repeat the search

#### **6.3 Re-search from History**
- **Precondition**: User is viewing history entry
- **Main Flow**:
  1. User taps "Search Again" button
  2. System uses saved query text
  3. System performs new search (same as 3.1, steps 3-9)
  4. System shows new results

#### **6.4 Delete History Entry**
- **Precondition**: User is on History Page
- **Main Flow**:
  1. User swipes left on history entry (or taps delete)
  2. System confirms deletion
  3. System calls backend API to delete history entry
  4. Backend removes history record
  5. System updates UI to remove entry from list
  6. History entry is deleted

---

### **7. AI Chatbot Interaction**

#### **7.1 Open AI Chatbot**
- **Precondition**: User is on Home Screen
- **Main Flow**:
  1. User taps floating action button (AI icon)
  2. System navigates to Chatbot Screen
  3. System loads previous conversation messages
  4. System calls backend API to get all user messages
  5. Backend retrieves conversation history
  6. System displays chat interface with:
     - Previous messages (if any)
     - Empty state message (if no history)
     - Input field at bottom

#### **7.2 Send Message to AI**
- **Precondition**: User is on Chatbot Screen
- **Main Flow**:
  1. User types question in input field
  2. User taps send button
  3. System adds user message to chat UI (right side)
  4. System shows "Thinking..." message from AI (left side)
  5. System calls backend API with:
     - User ID
     - Conversation ID (if continuing conversation)
     - Question text
  6. Backend processes question using AI model
  7. Backend generates response based on hadith knowledge
  8. Backend saves message and response to database
  9. System receives AI response
  10. System replaces "Thinking..." with actual response
  11. AI message appears on left side of chat

#### **7.3 View Chat History**
- **Precondition**: User has previous conversations
- **Main Flow**:
  1. System automatically loads all messages when opening chatbot
  2. System displays conversation in chronological order
  3. User messages appear on right (blue)
  4. AI messages appear on left (gray)
  5. User can scroll through entire conversation history
  6. System maintains conversation context across sessions

#### **7.4 Ask Questions about Hadiths**
- **Precondition**: User is in chatbot
- **Main Flow**:
  1. User asks questions like:
     - "What is a hadith about prayer?"
     - "Explain the authenticity of hadith number 123"
     - "What did the Prophet say about charity?"
  2. AI analyzes question
  3. AI searches hadith database
  4. AI provides contextual answer with hadith references
  5. User can ask follow-up questions
  6. AI maintains conversation context
  7. User continues learning about hadiths

---

### **8. Logout**

#### **8.1 Logout from Application**
- **Precondition**: User is logged in
- **Main Flow**:
  1. User opens drawer menu
  2. User taps "Logout" button
  3. System shows confirmation dialog
  4. User confirms logout
  5. System signs out from Firebase
  6. System clears local user data
  7. System navigates to Login Screen
  8. User must login again to access app

---

## **Alternative Flows**

### **A1: Onboarding Skipped**
- User can skip onboarding at any time
- System still saves completion status
- User proceeds directly to login

### **A2: OCR Fails**
- If OCR cannot extract text from image:
  - System shows error message
  - User can try again with different image
  - User can manually type the text

### **A3: Audio Transcription Fails**
- If audio transcription fails:
  - System shows error message
  - User can upload different audio file
  - User can manually type the text

### **A4: No Search Results**
- If search returns no results:
  - System displays "No results found" message
  - User can modify search query
  - User can try different input method

### **A5: Network Error**
- If network connection fails:
  - System shows error message
  - User can retry the operation
  - System may cache data for offline access

### **A6: Permission Denied**
- If user denies camera/microphone permissions:
  - System shows permission request dialog
  - User can grant permissions in settings
  - User can use alternative input methods

---

## **Postconditions**

After completing any use case flow:
- User data is saved in backend database
- Search history is maintained
- Bookmarks are preserved
- Chat history is stored
- User can resume from where they left off

---

## **Summary**

This comprehensive use case demonstrates how a **single User actor** can:
1. **Authenticate** and manage profile
2. **Search hadiths** using 4 different input methods (text, voice, image, audio)
3. **View results** and detailed hadith information in multiple languages
4. **Bookmark** favorite hadiths for later reference
5. **Track history** of all searches
6. **Interact with AI** chatbot for learning and questions
7. **Manage account** and logout

All operations are performed by the **User** actor, making this a user-centric application where the user has full control over their hadith exploration and learning experience.



