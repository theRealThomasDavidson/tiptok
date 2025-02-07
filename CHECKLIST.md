# TikTok Clone Development Checklist

## Authentication Enhancement
- [ ] Switch to branch: `feature/enhanced-auth`
  - [ ] Implement phone number authentication
    - [ ] Phone number input UI
    - [ ] Verification code handling
    - [ ] Error states and validation
  - [ ] Add Google authentication
    - [ ] Configure Google Sign-In
    - [ ] Implement sign-in flow
    - [ ] Handle auth state changes
  - [ ] Commit and merge to `develop`

## Playlist Feature
- [ ] Switch to branch: `feature/playlists`
  - [ ] Create playlist data model
  - [ ] Implement playlist creation UI
  - [ ] Add video selection/ordering interface
  - [ ] Develop playlist playback mode
  - [ ] Create playlist feed integration
  - [ ] Add playlist management features
  - [ ] Commit and merge to `develop`

## Enhanced Video Editor
- [ ] Switch to branch: `feature/advanced-editor`
  - [ ] Implement video splitting functionality
    - [ ] Add segment selection UI
    - [ ] Create split preview functionality
    - [ ] Implement segment-based playback
  - [ ] Enhance preview system
    - [ ] Add loop preview with spacers
    - [ ] Implement segment-start preview
    - [ ] Create visual timeline markers
  - [ ] Commit and merge to `develop`

## Testing & Quality Assurance
- [ ] Switch to branch: `feature/testing`
  - [ ] Write unit tests for new features
  - [ ] Implement integration tests
  - [ ] Performance testing for video playback
  - [ ] Authentication flow testing
  - [ ] Commit and merge to `develop`

## Documentation
- [ ] Switch to branch: `feature/documentation`
  - [ ] Update API documentation
  - [ ] Create user guides
  - [ ] Document authentication flows
  - [ ] Add playlist feature documentation
  - [ ] Commit and merge to `develop`

## Completed Milestones ✅
- [x] Initial Firebase deployment
- [x] Basic app structure
- [x] Firebase integration
- [x] Basic video upload
- [x] Initial video editing features
- [x] Register Android app (package: dev.thomasdavidson.trainup)
- [x] Add SHA-1 fingerprint
- [x] Download new google-services.json
- [x] Update app with new Firebase config

## Notes
- Each feature should include error handling and loading states
- Focus on mobile-first design principles
- Maintain consistent UI/UX across features
- Regular testing throughout development

# Firebase Project Setup Checklist

## Authentication
- [x] Enable Email/Password authentication
- [x] Enable Phone Number authentication
- [x] Enable Google Sign-in
- [x] Enable GitHub Sign-in
- [x] Configure GitHub OAuth (requires GitHub repository setup)

## App Check
- [x] Enable App Check
- [ ] Configure Debug Provider
- [ ] Add debug token when we get it

## Storage
- [ ] Enable Firebase Storage
- [ ] Set up storage rules for videos/images
- [ ] Configure storage permissions

## Cloud Firestore
- [ ] Enable Firestore
- [ ] Set up initial security rules
- [ ] Create necessary collections:
  - [ ] Users collection
  - [ ] Videos collection
  - [ ] Comments/Likes collections

## Project Settings
- [ ] Verify project ID and settings
- [ ] Set up default GCP resources
- [ ] Configure Android app settings

## Testing
- [ ] Test Email/Password sign in
- [ ] Test Phone authentication
- [ ] Test Google sign in
- [ ] Test GitHub sign in
- [ ] Test file uploads to Storage
- [ ] Verify App Check is working
- [ ] Test Firestore read/write operations 