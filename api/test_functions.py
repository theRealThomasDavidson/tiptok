import firebase_admin
from firebase_admin import credentials
import requests
import json
import os
from pathlib import Path
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Initialize Firebase Admin
firebase_admin.initialize_app()

# Function URLs - using the correct project ID
FUNCTION_BASE_URL = "https://us-central1-trainup-51d3c.cloudfunctions.net"

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
    # Test video path - replace with your actual video path
    test_video = "videos/test-video.mp4"
    
    # Test both functions
    test_generate_chapters(test_video)
    test_get_summary(test_video)

if __name__ == "__main__":
    main() 