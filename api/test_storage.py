from firebase_admin import credentials, initialize_app, storage
from urllib.parse import urlparse, parse_qs
from datetime import timedelta
from google.cloud.storage.bucket import Bucket
from typing import List
import asyncio
from transcription import process_video_url
import os

# Verify Deepgram API key is in environment
api_key = os.environ.get('DEEPGRAM_API_KEY')
if not api_key:
    raise ValueError("DEEPGRAM_API_KEY environment variable not found")

def init_firebase()->Bucket:
    """
    Initialize Firebase with service account
    input: None
    output: Bucket
            this is the bucket object from the firebase app
    """
    cred = credentials.Certificate('firebase-credentials.json')
    # Initialize Firebase
    app = initialize_app(cred)
    print("Firebase initialized")
    
    # Get bucket with explicit name
    bucket = storage.bucket('trainup-51d3c.firebasestorage.app')
    return bucket

def list_videos(bucket:Bucket)->List:
    """List all videos in the videos directory
    input: bucket: Bucket
            this is the bucket object from the firebase app
    output: List[Blob]
            this is the list of blobs in the videos directory
    """
    print("\nListing all videos:")
    try:
        print(f"\nAttempting to list videos in bucket: {bucket.name}")
        print("Getting blob iterator...")
        blobs = bucket.list_blobs(prefix='videos/')
        print("Converting to list...")
        blob_list = list(blobs)
        return blob_list
    except Exception as e:
        print(f"Error listing videos: {str(e)}")
        raise

def get_video_url(bucket:Bucket, video_path: str)-> str:
    """
    Get a Url for a video in the bucket
    input: bucket: storage.bucket.Bucket
            this is the bucket object from the firebase app
           video_path: str
            this is the path to the video in the bucket
    output: str
            this is the signed url for the video
    """
    blob = bucket.blob(video_path)
    return blob.generate_signed_url(version="v4", expiration=timedelta(minutes=15), method="GET")

async def process_video():
    print("\n=== Starting Video Processing ===")
    
    print("\n1. Initializing Firebase...")
    bucket = init_firebase()
    
    # List available videos
    print("\n2. Listing available videos...")
    list_videos(bucket)
    
    # Try to get URL for a specific video
    test_path = 'videos/IH2Zp2bAPJOhriFakZswjFC96xH3/1739034967371.mp4'  # Let's try a different video
    print(f"\n3. Getting URL for {test_path}:")
    url = get_video_url(bucket, test_path)
    print(f"Generated URL (first 100 chars): {url[:100]}...")
    
    # Process with Deepgram
    if url:
        print("\n4. Starting Deepgram Processing...")
        # Set chapter duration to 15 seconds
        transcript_data = await process_video_url(url, chapter_duration=15.0)
        
        if transcript_data:
            print("\n5. Transcription Results:")
            print(f"\nFull Text: {transcript_data['full_text']}")
            
            print("\n6. Generated Chapters:")
            print(transcript_data['formatted_chapters'])
        else:
            print("Failed to get transcription results")
    else:
        print("Failed to generate URL for video")

if __name__ == "__main__":
    asyncio.run(process_video())