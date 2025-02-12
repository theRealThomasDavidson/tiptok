from firebase_admin import credentials, initialize_app, storage
from urllib.parse import urlparse, parse_qs
from datetime import timedelta
from google.cloud.storage.bucket import Bucket
from deepgram import Deepgram
import asyncio
import os
from dotenv import load_dotenv

# Load environment variables from current directory
load_dotenv()

# Verify Deepgram API key is loaded
DEEPGRAM_API_KEY = os.getenv('DEEPGRAM_API_KEY')
if not DEEPGRAM_API_KEY:
    raise ValueError("DEEPGRAM_API_KEY not found in .env file")

def init_firebase():
    """Initialize Firebase with service account"""
    print("Loading credentials...")
    cred = credentials.Certificate('firebase-credentials.json')
    print("Credentials loaded")
    
    # Initialize Firebase
    app = initialize_app(cred)
    print("Firebase initialized")
    
    # Get bucket with explicit name
    bucket = storage.bucket('trainup-51d3c.firebasestorage.app')
    print(f"Got bucket: {bucket.name}")
    print(f"Bucket type: {type(bucket)}")
    print(f"Bucket module: {bucket.__module__}")
    return bucket

def list_videos(bucket:Bucket):
    """List all videos in the videos directory"""
    print("\nListing all videos:")
    try:
        print(f"\nAttempting to list videos in bucket: {bucket.name}")
        print("Getting blob iterator...")
        blobs = bucket.list_blobs(prefix='videos/')
        print("Converting to list...")
        blob_list = list(blobs)
        
        if not blob_list:
            print("No videos found")
            return
            
        for blob in blob_list:
            print(f"\nFound video: {blob.name}")
            print(f"Size: {blob.size} bytes")
            print(f"Created: {blob.time_created}")
            print("---")
    except Exception as e:
        print(f"Error listing videos: {str(e)}")
        raise

def get_video_url(bucket:Bucket, video_path: str)-> str:
    """
    Get a signed URL for a video
    Args:
        bucket: storage.bucket.Bucket - the bucket object from firebase app
        video_path: str - path to the video in the bucket
    Returns:
        str - the signed url for the video
    """
    blob = bucket.blob(video_path)
    return blob.generate_signed_url(version="v4", expiration=timedelta(minutes=15), method="GET")

async def transcribe_video(url: str):
    """
    Transcribe video using Deepgram API
    Args:
        url: URL of the video to transcribe
    Returns:
        Transcription result from Deepgram
    """
    try:
        print(f"\nInitializing Deepgram with API key: {DEEPGRAM_API_KEY[:8]}...")
        dg_client = Deepgram(DEEPGRAM_API_KEY)
        
        print(f"Processing URL: {url[:100]}...")
        source = {'url': url}
        options = {
            'punctuate': True,
            'paragraphs': True,
            'summarize': True,
            'detect_topics': True,
            'tier': 'enhanced'  # Use enhanced model for better accuracy
        }
        
        print("\nSending to Deepgram for transcription...")
        try:
            response = await dg_client.transcription.prerecorded(source, options)
            print("Transcription complete!")
            return response
        except Exception as api_error:
            print(f"Deepgram API error: {str(api_error)}")
            if hasattr(api_error, 'response'):
                print(f"Response status: {api_error.response.status}")
                print(f"Response text: {await api_error.response.text()}")
            return None
        
    except Exception as e:
        print(f"Error during transcription setup: {str(e)}")
        print(f"Error type: {type(e).__name__}")
        import traceback
        print(f"Traceback: {traceback.format_exc()}")
        return None

async def process_video():
    print("\n=== Starting Video Processing ===")
    
    print("\n1. Initializing Firebase...")
    bucket = init_firebase()
    
    # Try to get URL for a specific video
    test_path = 'videos/IH2Zp2bAPJOhriFakZswjFC96xH3/1738983961894.mp4'
    print(f"\n2. Getting URL for {test_path}:")
    url = get_video_url(bucket, test_path)
    print(f"Generated URL (first 100 chars): {url[:100]}...")
    
    # Process with Deepgram
    if url:
        print("\n3. Starting Deepgram Processing...")
        print(f"Using Deepgram API Key: {DEEPGRAM_API_KEY[:8]}...")
        
        result = await transcribe_video(url)
        print("\n4. Checking Results...")
        
        if result:
            print("Got response from Deepgram")
            print(f"Response type: {type(result)}")
            print(f"Response keys: {result.keys() if isinstance(result, dict) else 'Not a dict'}")
            
            if isinstance(result, dict) and 'results' in result:
                print("\nTranscription Results:")
                results = result['results']
                print(f"Results keys: {results.keys()}")
                
                if 'paragraphs' in results:
                    for para in results['paragraphs']:
                        print(f"\nParagraph ({para['start']} - {para['end']}):")
                        print(f"Text: {para.get('text', 'No text')}")
                        print(f"Summary: {para.get('summary', 'No summary')}")
                        print(f"Topics: {para.get('topics', [])}")
                else:
                    print("No paragraphs found in transcription")
                    print("Available keys in results:", results.keys())
            else:
                print("No 'results' key in response")
                print(f"Full response: {result}")
        else:
            print("Failed to get transcription results")
    else:
        print("Failed to generate URL for video")

if __name__ == "__main__":
    asyncio.run(process_video()) 