import firebase_admin
from firebase_admin import credentials, storage, firestore
import requests
import time
from datetime import datetime

def cleanup_videos():
    # Initialize Firebase Admin
    # Look for service account key in the root directory
    try:
        cred = credentials.Certificate('service-account-key.json')
        firebase_admin.initialize_app(cred, {
            'storageBucket': 'tiptok-f2819.firebasestorage.app'
        })
    except ValueError:
        print("Firebase app already initialized")

    # Get Storage and Firestore clients
    bucket = storage.bucket()
    db = firestore.client()

    print("\nStarting video cleanup process...")
    print("-" * 50)

    # Get all video documents from Firestore
    videos_ref = db.collection('videos')
    videos = videos_ref.get()

    total_videos = len(videos)
    deleted_count = 0
    errors = []

    print(f"Found {total_videos} video records in Firestore")
    
    for video in videos:
        video_data = video.to_dict()
        video_url = video_data.get('url')
        
        if not video_url:
            print(f"No URL found for video {video.id}, deleting record...")
            video.reference.delete()
            deleted_count += 1
            continue

        print(f"\nChecking video: {video.id}")
        print(f"URL: {video_url}")

        try:
            # Try to fetch the video URL
            response = requests.head(video_url, timeout=5)
            
            if response.status_code != 200:
                print(f"Video not accessible (Status {response.status_code}), cleaning up...")
                
                # Delete from Storage if possible
                try:
                    if 'videos/' in video_url:
                        file_path = video_url.split('?')[0].split('videos/')[-1]
                        blob = bucket.blob(f'videos/{file_path}')
                        blob.delete()
                        print("Deleted from Storage")
                except Exception as e:
                    print(f"Error deleting from Storage: {e}")

                # Delete thumbnail if it exists
                if video_data.get('thumbnailUrl'):
                    try:
                        thumb_path = video_data['thumbnailUrl'].split('?')[0].split('thumbnails/')[-1]
                        thumb_blob = bucket.blob(f'thumbnails/{thumb_path}')
                        thumb_blob.delete()
                        print("Deleted thumbnail from Storage")
                    except Exception as e:
                        print(f"Error deleting thumbnail: {e}")

                # Delete from Firestore
                video.reference.delete()
                print("Deleted from Firestore")
                
                deleted_count += 1
            else:
                print("Video accessible ✓")

        except Exception as e:
            error_msg = f"Error processing video {video.id}: {str(e)}"
            print(error_msg)
            errors.append(error_msg)

        # Small delay to avoid rate limiting
        time.sleep(0.5)

    print("\nCleanup Summary:")
    print("-" * 50)
    print(f"Total videos checked: {total_videos}")
    print(f"Videos deleted: {deleted_count}")
    print(f"Errors encountered: {len(errors)}")
    
    if errors:
        print("\nErrors:")
        for error in errors:
            print(f"- {error}")

    print("\nCleanup process completed!")

if __name__ == '__main__':
    cleanup_videos() 