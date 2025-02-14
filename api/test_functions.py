import firebase_admin
from firebase_admin import credentials, storage, firestore
import requests
import json
import os
from pathlib import Path
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Get the absolute path to the credentials file
current_dir = os.path.dirname(os.path.abspath(__file__))
cred_path = os.path.join(current_dir, 'firebase-credentials.json')

# Initialize Firebase Admin with credentials
cred = credentials.Certificate(cred_path)
firebase_admin.initialize_app(cred, {
    'storageBucket': 'trainup-51d3c.firebasestorage.app'
})

# Function URLs - using the correct project ID
FUNCTION_BASE_URL = "https://us-central1-trainup-51d3c.cloudfunctions.net"

def check_video_consistency():
    """Check consistency between videos in Storage and Firestore, and verify summaries"""
    print("\nChecking video consistency between Storage and Firestore...")
    
    try:
        # Get Firestore and Storage clients
        db = firestore.client()
        bucket = storage.bucket()
        
        # Test bucket access
        print("\nTesting Storage bucket access...")
        try:
            bucket_name = bucket.name
            print(f"Successfully connected to bucket: {bucket_name}")
        except Exception as e:
            print(f"Error accessing bucket: {str(e)}")
            return
        
        # Get all videos from Firestore
        print("\nFetching videos from Firestore...")
        firestore_videos = {}
        videos_ref = db.collection('videos').get()
        for doc in videos_ref:
            video_data = doc.to_dict()
            video_path = f"videos/{doc.id}"
            firestore_videos[video_path] = {
                'id': doc.id,
                'data': video_data
            }
        print(f"Found {len(firestore_videos)} videos in Firestore")

        # Get all videos from Storage
        print("\nFetching videos from Storage...")
        storage_videos = set()
        try:
            blobs = list(bucket.list_blobs(prefix='videos/'))
            for blob in blobs:
                if blob.name.endswith('.mp4'):
                    storage_videos.add(blob.name)
            print(f"Found {len(storage_videos)} videos in Storage")
        except Exception as e:
            print(f"Error listing blobs: {str(e)}")
            print("Storage bucket details:")
            print(f"- Bucket name: {bucket.name}")
            print(f"- Project: {bucket.project_number}")
            return

        # Check for inconsistencies
        print("\nChecking for inconsistencies...")
        
        # Videos in Storage but not in Firestore
        orphaned_videos = storage_videos - set(firestore_videos.keys())
        if orphaned_videos:
            print(f"\nFound {len(orphaned_videos)} videos in Storage but not in Firestore:")
            for video in orphaned_videos:
                print(f"- {video}")
        
        # Videos in Firestore but not in Storage
        missing_videos = set(firestore_videos.keys()) - storage_videos
        if missing_videos:
            print(f"\nFound {len(missing_videos)} videos in Firestore but not in Storage:")
            for video in missing_videos:
                print(f"- {video}")
                print(f"  Firestore ID: {firestore_videos[video]['id']}")
                print(f"  User ID: {firestore_videos[video]['data'].get('userId')}")

        # Check summaries for all videos in both Storage and Firestore
        consistent_videos = storage_videos.intersection(set(firestore_videos.keys()))
        if consistent_videos:
            print(f"\nChecking summaries for {len(consistent_videos)} consistent videos...")
            summary_failures = []
            summary_successes = []

            for video_path in consistent_videos:
                print(f"\nChecking summary for {video_path}")
                try:
                    response = requests.post(
                        "http://ec2-3-86-192-27.compute-1.amazonaws.com/api/get_summary",
                        json={"videoPath": video_path},
                        headers={'Content-Type': 'application/json'},
                        timeout=30
                    )
                    
                    if response.status_code == 200:
                        summary_data = response.json()
                        summary_successes.append({
                            'path': video_path,
                            'summary': summary_data.get('summary'),
                            'keywords': summary_data.get('keywords', []),
                            'suggested_title': summary_data.get('suggested_title')
                        })
                        print(f"✅ Successfully got summary")
                        print(f"  Title: {summary_data.get('suggested_title')}")
                except Exception as e:
                    summary_failures.append({'path': video_path, 'error': str(e)})
                    print(f"❌ Error getting summary: {e}")

            # Print summary results
            print("\nSummary Results:")
            print(f"- Successfully processed: {len(summary_successes)} videos")
            print(f"- Failed to process: {len(summary_failures)} videos")

            if summary_failures:
                print("\nFailed Videos:")
                for failure in summary_failures:
                    print(f"- {failure['path']}")
                    print(f"  Error: {failure['error']}")
        
        # Summary
        if not orphaned_videos and not missing_videos:
            print("\n✅ All videos are consistent between Storage and Firestore")
        else:
            print("\n⚠️ Inconsistencies found between Storage and Firestore")
            print(f"- {len(orphaned_videos)} orphaned videos in Storage")
            print(f"- {len(missing_videos)} missing videos in Storage")

    except Exception as e:
        print(f"\nError checking video consistency: {str(e)}")

def test_generate_chapters(video_path: str):
    """Test the generate_chapters function"""
    print(f"\nTesting generate_chapters with video: {video_path}")
    try:
        url = f"{FUNCTION_BASE_URL}/generate_chapters"
        headers = {
            'Content-Type': 'application/json'
        }
        body = {
            'videoPath': video_path
        }
        
        print(f"Making request to: {url}")
        print(f"Request body: {json.dumps(body, indent=2)}")
        response = requests.post(url, json=body, headers=headers)
        print(f"Response status: {response.status_code}")
        text = response.text
        print(f"Response text: {text}")
        try:
            result = json.loads(text)
            if response.status_code == 200:
                print("\nSuccess! Chapters generated:")
                print(json.dumps(result, indent=2))
                return result
            else:
                print(f"\nError: {result}")
                return None
        except json.JSONDecodeError:
            print(f"\nError: Could not parse JSON response")
            return None
            
    except Exception as e:
        print(f"\nError generating chapters: {str(e)}")
        return None

def test_get_summary(video_path: str):
    """Test the get_summary function"""
    print(f"\nTesting get_summary with video: {video_path}")
    try:
        url = f"{FUNCTION_BASE_URL}/get_summary"
        headers = {
            'Content-Type': 'application/json'
        }
        body = {
            'videoPath': video_path
        }
        
        print(f"Making request to: {url}")
        print(f"Request body: {json.dumps(body, indent=2)}")
        response = requests.post(url, json=body, headers=headers)
        print(f"Response status: {response.status_code}")
        text = response.text
        print(f"Response text: {text}")
        try:
            result = json.loads(text)
            if response.status_code == 200:
                print("\nSuccess! Summary generated:")
                print(json.dumps(result, indent=2))
                return result
            else:
                print(f"\nError: {result}")
                return None
        except json.JSONDecodeError:
            print(f"\nError: Could not parse JSON response")
            return None

    except Exception as e:
        print(f"\nError getting summary: {str(e)}")
        return None

def main():
    # First check video consistency
    check_video_consistency()
    
    # Get a real video path from Firestore for testing
    try:
        db = firestore.client()
        videos_ref = db.collection('videos').limit(1).get()
        if not videos_ref.empty:
            video_doc = videos_ref.docs[0]
            video_path = f"videos/{video_doc.id}"
            
            print(f"\nTesting API functions with video: {video_path}")
            test_generate_chapters(video_path)
            test_get_summary(video_path)
        else:
            print("\nNo videos found in Firestore to test API functions")
    except Exception as e:
        print(f"\nError getting test video: {e}")

if __name__ == "__main__":
    main() 