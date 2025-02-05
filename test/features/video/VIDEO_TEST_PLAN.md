# Video Feature Test Plan

## 1. Unit Tests
### VideoStorageService
- [ ] Upload success scenario
  - File uploads correctly
  - Returns valid download URL
  - Progress callback works
- [ ] Error handling
  - Network errors
  - Invalid file
  - Unauthorized access

### VideoPlayerWidget
- [ ] Initialization
  - Loads video correctly
  - Maintains aspect ratio
- [ ] Controls
  - Play/pause works
  - Disposal cleanup

## 2. Widget Tests
### VideoPreviewScreen
- [ ] UI Elements
  - Video player displays
  - Upload button present
  - Cancel button present
- [ ] User Interactions
  - Upload triggers storage service
  - Cancel returns to previous screen
  - Progress indicator shows during upload

### VideoUploadScreen
- [ ] File Selection
  - Opens file picker
  - Handles selection cancellation
  - Validates video files
- [ ] Navigation
  - Moves to preview screen with file
  - Handles back navigation

## 3. Integration Tests
### Upload Flow
- [ ] End-to-end upload process
  - Select file
  - Preview video
  - Upload to Firebase
  - Verify in storage
- [ ] Error scenarios
  - Network disconnection
  - File too large
  - Invalid file type

## 4. Manual Testing Checklist
- [ ] Video aspect ratio maintained
- [ ] Progress updates are smooth
- [ ] Error messages are clear
- [ ] Upload cancellation works
- [ ] Large file handling 