import firebase_admin
from firebase_admin import credentials, storage, firestore
import os
import json
from datetime import datetime
import subprocess
import tempfile
import time

def generate_thumbnail(video_url, output_path):
    """Generate a thumbnail from a video using FFmpeg"""
    temp_video = None
    try:
        # Download video to temp file
        temp_video = tempfile.NamedTemporaryFile(suffix='.mp4', delete=False)
        temp_video.close()  # Close the file handle immediately
        
        # Download the video
        subprocess.run(['curl', '-L', '-o', temp_video.name, video_url], check=True)
        time.sleep(1)  # Give Windows time to release the file handle
        
        # Generate thumbnail using FFmpeg
        subprocess.run([
            'ffmpeg', '-i', temp_video.name,
            '-ss', '0.0', '-vframes', '1',
            '-y',  # Overwrite output file if exists
            output_path
        ], check=True)
        
        return True
    except Exception as e:
        print(f"Error generating thumbnail: {e}")
        return False
    finally:
        # Clean up temp video file
        if temp_video and os.path.exists(temp_video.name):
            try:
                os.unlink(temp_video.name)
            except Exception as e:
                print(f"Warning: Could not delete temp video file: {e}")

def migrate_videos():
    # Initialize Firebase Admin
    # Look for service account key in the root directory
    root_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    key_path = os.path.join(root_dir, 'service-account-key.json')
    
    cred = credentials.Certificate(key_path)
    firebase_admin.initialize_app(cred, {
        'storageBucket': 'tiptok-f2819.firebasestorage.app'  # Storage bucket from firebase_options.dart
    })

    # Get Storage and Firestore clients
    bucket = storage.bucket()
    db = firestore.client()

    # Get all video files from Storage
    print("Fetching videos from Storage...")
    blobs = bucket.list_blobs(prefix='videos/')
    
    # Track migration progress
    total_videos = 0
    processed_videos = 0
    errors = []

    # First pass to count total videos
    for _ in bucket.list_blobs(prefix='videos/'):
        total_videos += 1

    print(f"Found {total_videos} videos to process")
    print("\nVideo Data:")
    print("-" * 50)

    # Process each video
    for blob in blobs:
        try:
            # Skip non-video files
            if not blob.name.endswith('.mp4'):
                continue

            # Extract user ID and video name from path
            # Expected format: videos/userId/timestamp.mp4
            parts = blob.name.split('/')
            if len(parts) != 3:
                print(f"Skipping {blob.name} - invalid path format")
                continue

            user_id = parts[1]
            video_id = os.path.splitext(parts[2])[0]  # Remove .mp4 extension

            # Get video URL
            video_url = blob.public_url

            # Try to get or generate thumbnail
            thumbnail_path = f'thumbnails/{user_id}/{video_id}_thumb.jpg'
            thumbnail_url = None
            
            # Check if thumbnail exists
            thumbnail_blob = bucket.blob(thumbnail_path)
            if thumbnail_blob.exists():
                thumbnail_url = thumbnail_blob.public_url
            else:
                # Generate and upload thumbnail
                with tempfile.NamedTemporaryFile(suffix='.jpg', delete=False) as temp_thumb:
                    temp_thumb.close()  # Close file handle immediately
                    if generate_thumbnail(video_url, temp_thumb.name):
                        try:
                            time.sleep(1)  # Give Windows time to release the file handle
                            thumbnail_blob.upload_from_filename(temp_thumb.name)
                            thumbnail_url = thumbnail_blob.public_url
                            print(f"Generated and uploaded thumbnail for {blob.name}")
                        except Exception as e:
                            print(f"Error uploading thumbnail: {e}")
                        finally:
                            try:
                                os.unlink(temp_thumb.name)
                            except Exception as e:
                                print(f"Warning: Could not delete temp thumbnail file: {e}")

            # Create video data dictionary
            video_data = {
                'userId': user_id,
                'url': video_url,
                'thumbnailUrl': thumbnail_url,
                'timestamp': blob.time_created,  # Use native timestamp for Firestore
                'path': blob.name  # Store the path for uniqueness
            }

            # Check if document exists with this path
            existing_videos = db.collection('videos').where('path', '==', blob.name).limit(1).get()
            
            if existing_videos:
                # Update existing document
                doc = existing_videos[0]
                doc.reference.update(video_data)
                print(f"Updated existing document for {blob.name}")
            else:
                # Create new document
                db.collection('videos').add(video_data)
                print(f"Created new document for {blob.name}")

            # Print video data in a readable format
            print(json.dumps({
                **video_data,
                'timestamp': video_data['timestamp'].isoformat(),
                'videoId': video_id,
            }, indent=2))
            print("-" * 50)
            
            processed_videos += 1

        except Exception as e:
            error_msg = f"Error processing {blob.name}: {str(e)}"
            print(error_msg)
            errors.append(error_msg)

    # Print summary
    print("\nProcessing Summary:")
    print(f"Total videos found: {total_videos}")
    print(f"Successfully processed: {processed_videos}")
    print(f"Errors: {len(errors)}")
    
    if errors:
        print("\nErrors encountered:")
        for error in errors:
            print(f"- {error}")

if __name__ == '__main__':
    migrate_videos() 