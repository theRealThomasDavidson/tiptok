from deepgram import Deepgram
import asyncio
import os
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

async def main():
    # Initialize the Deepgram SDK
    dg_client = Deepgram(os.getenv('DEEPGRAM_API_KEY'))
    
    # The URL to transcribe - should be set in .env as TEST_VIDEO_URL
    url = os.getenv('TEST_VIDEO_URL')
    if not url:
        print("Error: TEST_VIDEO_URL not set in .env file")
        return
    
    try:
        source = {'url': url}
        options = {
            'punctuate': True,
            'paragraphs': True,
            'summarize': True,
            'detect_topics': True
        }
        
        print("Sending to Deepgram...")
        response = await dg_client.transcription.prerecorded(source, options)
        print("Response received!")
        print(response)
        
    except Exception as e:
        print(f"Error during transcription: {str(e)}")

if __name__ == '__main__':
    asyncio.run(main()) 