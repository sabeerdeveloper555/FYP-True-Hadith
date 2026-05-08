# Profile Photo Drawer Fix

## Issue
Profile photo was not visible or unclickable in the home drawer menu.

## Fixes Applied

### 1. Improved ProfilePhotoWidget Visibility
- ✅ Changed `GestureDetector` to `InkWell` for better visual feedback (ripple effect)
- ✅ Added shadow to profile photo container for better visibility
- ✅ Increased camera icon size and made it more prominent
- ✅ Added proper sizing constraints to placeholder
- ✅ Improved loading indicator visibility

### 2. Enhanced HomeDrawer Layout
- ✅ Increased profile photo size from 72 to 80 pixels
- ✅ Changed layout to show photo and username side by side (better use of space)
- ✅ Added hint text: "Tap photo to view, update, or delete"
- ✅ Improved spacing and visual hierarchy

### 3. Visual Improvements
- ✅ Added box shadow to profile photo for depth
- ✅ Made camera icon overlay larger and more visible
- ✅ Added border and shadow to camera icon
- ✅ Better placeholder icon sizing

## Changes Made

### `lib/widgets/profile_photo_widget.dart`
- Replaced `GestureDetector` with `InkWell` for tap feedback
- Added `boxShadow` to profile photo container
- Increased camera icon size from 15% to 18% of widget size
- Added shadow to camera icon overlay
- Fixed placeholder sizing

### `lib/screens/home_screen.dart`
- Increased profile photo size from 72 to 80
- Changed layout from vertical to horizontal (photo + username side by side)
- Added hint text below profile section
- Improved spacing

## Result

Now when users open the drawer:
1. ✅ Profile photo is **clearly visible** (larger size, better styling)
2. ✅ Photo is **obviously clickable** (camera icon, hint text, ripple effect)
3. ✅ Better visual hierarchy (photo and username side by side)
4. ✅ Clear indication that photo can be tapped

## Testing

To verify the fix:
1. Open the app drawer
2. You should see:
   - Large, visible profile photo (or placeholder)
   - Camera icon in bottom-right corner
   - Username and "Member since" text next to photo
   - Hint text: "Tap photo to view, update, or delete"
3. Tap on the profile photo
4. Menu should appear with options:
   - View Photo (if exists)
   - Update Photo
   - Delete Photo (if exists)
   - Cancel

## Visual Feedback

- **Tap Effect**: InkWell provides ripple effect when tapped
- **Camera Icon**: Always visible to indicate clickability
- **Hint Text**: Clear instruction for users
- **Shadow**: Makes photo stand out from background

