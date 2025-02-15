# Video Processing API Migration Checklist

## What We Have ✅
1. Working Flask API with:
   - `/get_summary`: Generates and stores video summaries with keywords ✅
   - `/generate_chapters`: Creates semantic chapters from video content with suggested titles ✅
2. Core functionality working:
   - Deepgram integration for transcription ✅
   - GPT-4 for chapter generation ✅
   - GPT-3.5 for summaries, keyword extraction, and title generation ✅
3. Firebase integration:
   - Video storage access ✅
   - Firestore for metadata ✅
   - Authentication working locally ✅

## Migration to EC2 Container 🔄

### Container Setup
- [x] Create Dockerfile for API
  - [x] Base Python image
  - [x] Install dependencies
  - [x] Copy service account credentials
  - [x] Set up environment variables
  - [x] Configure CORS and security headers
- [x] Set up docker-compose for local testing
  - [x] API service configuration
  - [x] Environment variables
  - [x] Volume mounts for credentials
- [x] Test container locally
  - [x] Verify Firebase access
  - [x] Test all endpoints
  - [x] Check logging

### AWS Infrastructure
- [x] Set up EC2 instance
  - [x] Choose instance type (t2.micro or similar)
  - [x] Configure security groups
    - [x] HTTP (port 80) inbound for API traffic
    - [x] SSH (port 22) inbound for remote access
    - [x] All outbound traffic allowed (for API calls to Firebase/Deepgram/OpenAI)
  - [x] Configure user data script
    - [x] Update system packages
    - [x] Install Docker and docker-compose
    - [x] Set up Docker permissions
    - [x] Create necessary directories
    - [x] Configure logging
    - [x] Add repository cloning and container setup
  - [x] Set up SSH access
    - [x] Generate RSA key pair using OpenSSH (ssh-keygen -t rsa -b 2048)
    - [x] Import public key to AWS EC2
    - [x] Save private key securely (.pem file)
    - [x] Set correct permissions (chmod 400) on private key
- [x] Install Docker on EC2
  - [x] Configure Docker daemon
  - [x] Set up Docker user permissions
- [x] Set up environment
  - [x] Copy service account credentials
  - [x] Configure environment variables
  - [x] Set up logging

### Deployment Pipeline
- [x] Create deployment script
  - [x] Build container
  - [x] Push to container registry
  - [x] Pull and run on EC2

### Frontend Updates
- [x] Update frontend API calls
  - [x] Point to new API endpoint
  - [x] Update request/response handling
  - [x] Add error handling
- [x] Test integration
  - [x] Video upload flow
  - [x] Chapter generation
  - [x] Summary generation
  - [x] Error scenarios

## Testing Requirements
- [x] API endpoint testing
  - [x] Test all endpoints with real data
    - [x] POST http://ec2-3-86-192-27.compute-1.amazonaws.com/api/get_summary
    - [x] POST http://ec2-3-86-192-27.compute-1.amazonaws.com/api/generate_chapters
  - [x] Verify Firebase integration
  - [x] Check error handling
  - [x] Video path handling
    - [x] Verify video paths are correctly stored in Firestore during upload
    - [x] Test path format consistency (videos/user_id/video_id.mp4)
    - [x] Validate path retrieval in API endpoints
    - [x] Test error cases for invalid paths
- [x] Load testing
  - [x] Test concurrent requests
  - [x] Verify performance
- [x] Integration testing
  - [x] Test with frontend
  - [x] Verify end-to-end flow

## Documentation
- [x] Update API documentation
  - [x] New endpoint URLs
  - [x] Request/response formats
  - [x] Error codes
- [x] Deployment documentation
  - [x] Container build instructions
  - [x] EC2 setup steps
  - [x] Environment configuration
- [x] Monitoring documentation
  - [x] Logging locations
  - [x] Monitoring dashboards
  - [x] Alert configurations

## Cost Considerations 💰
- EC2 instance: ~$10-20/month (t2.micro)
- Data transfer: Variable based on usage
- Storage: Minimal (using Firebase Storage)
- API calls remain the same:
  - Deepgram transcription
  - OpenAI API calls
  - Firebase operations 