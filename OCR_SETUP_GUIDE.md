# OCR Setup Guide - Tesseract + EasyOCR

## Overview
The app now uses **Tesseract OCR** (local) with **EasyOCR** (backend API) fallback for text extraction from images.

## Architecture

### 1. Tesseract OCR (Local - Primary)
- **Package**: `tesseract_ocr: ^0.4.1`
- **Location**: Flutter app (client-side)
- **Language Support**: 
  - English (`eng`) - Also handles Roman Urdu
  - Arabic (`ara`)
  - Urdu (`urd`)
  - Combined: `eng+ara+urd`
- **Advantages**: Fast, offline, no network required
- **When Used**: First attempt for all OCR requests

### 2. EasyOCR (Backend API - Fallback)
- **Package**: `easyocr` (Python)
- **Location**: Flask backend (`backend_api_example.py`)
- **Language Support**: 
  - English (`en`) - Also handles Roman Urdu
  - Arabic (`ar`)
  - Urdu (`ur`)
  - Combined: `['en', 'ar', 'ur']`
- **Advantages**: More accurate for complex images, better with noisy images
- **When Used**: Fallback when Tesseract returns empty or fails
- **Endpoint**: `POST /api/ocr/easyocr`

## Setup Instructions

### Flutter App (Tesseract)

1. **Dependencies Installed** ✅
   - `tesseract_ocr: ^0.4.1` is already in `pubspec.yaml`

2. **Language Data Files (Required)**
   - Tesseract needs trained data files (`.traineddata`)
   - Download from: https://github.com/tesseract-ocr/tessdata
   - Required files:
     - `eng.traineddata` (English - also handles Roman Urdu)
     - `ara.traineddata` (Arabic)
     - `urd.traineddata` (Urdu)
   
3. **Add to Assets**
   - Create folder: `assets/tessdata/`
   - Place `.traineddata` files in this folder
   - Update `pubspec.yaml`:
   ```yaml
   flutter:
     assets:
       - assets/tessdata/eng.traineddata
       - assets/tessdata/ara.traineddata
       - assets/tessdata/urd.traineddata
   ```

4. **Android Configuration**
   - Tesseract should work automatically on Android
   - No additional setup needed

5. **iOS Configuration**
   - May require additional setup
   - Check `tesseract_ocr` package documentation for iOS requirements

### Backend (EasyOCR)

1. **Install EasyOCR**
   ```bash
   pip install easyocr
   ```

2. **Install Additional Dependencies**
   ```bash
   pip install pillow numpy
   ```

3. **Backend Endpoint**
   - Already added to `backend_api_example.py`
   - Endpoint: `POST /api/ocr/easyocr`
   - Accepts: Base64 encoded image
   - Returns: Extracted text

4. **First Run**
   - EasyOCR will download models on first use (~500MB)
   - This happens automatically
   - Subsequent runs are faster

## Usage Flow

```
User uploads image
    ↓
Crop/Skip image
    ↓
Click "Extract Text"
    ↓
Try Tesseract OCR (local)
    ↓
Success? → Return text
    ↓
Failed/Empty? → Try EasyOCR (backend API)
    ↓
Return text or error
```

## Testing

### Test Tesseract Only
- Disconnect from internet
- Upload image with text
- Should extract text using Tesseract

### Test EasyOCR Only
- Comment out Tesseract call in `ocr_service.dart`
- Upload complex/noisy image
- Should use EasyOCR backend

### Test Both
- Upload clear image → Should use Tesseract
- Upload complex image → Should fallback to EasyOCR

## Troubleshooting

### Tesseract Issues

**Problem**: "Language data not found"
- **Solution**: Download `.traineddata` files and add to `assets/tessdata/`

**Problem**: "No text extracted"
- **Solution**: 
  - Check image quality
  - Try different language codes
  - Verify `.traineddata` files are correct

### EasyOCR Issues

**Problem**: "EasyOCR is not installed"
- **Solution**: `pip install easyocr`

**Problem**: "API timeout"
- **Solution**: 
  - First run downloads models (slow)
  - Subsequent runs are faster
  - Increase timeout in `ocr_service.dart`

**Problem**: "No text detected"
- **Solution**:
  - Check image quality
  - Verify image is properly encoded
  - Check backend logs for errors

## Configuration

### Change Languages

**Tesseract** (in `ocr_service.dart`):
```dart
// Default: All supported languages
extractTextFromImage(imagePath, language: 'eng+ara+urd') // English + Arabic + Urdu

// Or specify individual languages:
extractTextFromImage(imagePath, language: 'eng') // English only (includes Roman Urdu)
extractTextFromImage(imagePath, language: 'ara') // Arabic only
extractTextFromImage(imagePath, language: 'urd') // Urdu only
```

**EasyOCR** (in `backend_api_example.py`):
```python
# Default: All supported languages
easyocr.Reader(['en', 'ar', 'ur'], gpu=False)  # English + Arabic + Urdu

# English ('en') also handles Roman Urdu since it uses Latin script
```

### Language Support Details

- **English (`eng`/`en`)**: Handles English text and Roman Urdu (Urdu written in Latin script)
- **Arabic (`ara`/`ar`)**: Handles Arabic text
- **Urdu (`urd`/`ur`)**: Handles Urdu text written in Urdu script
- **Roman Urdu**: Uses English language model since it's written in Latin script

### Change Backend URL

**Flutter** (in `ocr_service.dart`):
```dart
const apiBaseUrl = 'http://YOUR_IP:5000/api';
```

**Backend** (in `backend_api_example.py`):
- Already configured to run on `0.0.0.0:5000`
- Accessible from network

## Performance Notes

- **Tesseract**: Fast (~1-2 seconds), works offline
- **EasyOCR**: Slower (~3-10 seconds), requires network, more accurate
- **First EasyOCR run**: Very slow (~30-60 seconds) due to model download
- **Subsequent EasyOCR runs**: Much faster (~3-10 seconds)

## Next Steps

1. ✅ Tesseract OCR integrated
2. ✅ EasyOCR backend endpoint added
3. ⏳ Add language data files to Flutter assets
4. ⏳ Test both OCR engines
5. ⏳ Install EasyOCR on backend server

