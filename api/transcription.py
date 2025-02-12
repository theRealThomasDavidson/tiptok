from deepgram import Deepgram
import os
from dotenv import load_dotenv
import asyncio
import traceback
from typing import Optional, Dict, Any, List
from dataclasses import dataclass
from math import ceil

# Load environment variables
load_dotenv()

# Get Deepgram API key
DEEPGRAM_API_KEY = os.getenv('DEEPGRAM_API_KEY')
if not DEEPGRAM_API_KEY:
    raise ValueError("DEEPGRAM_API_KEY not found in .env file")

@dataclass
class Chapter:
    """Represents a chapter in the video"""
    start: float
    end: float
    text: str
    sentences: List[Dict[str, Any]]

def generate_chapters(transcript_data: Dict[str, Any], target_duration: float = 30.0) -> List[Chapter]:
    """
    Generate chapters from transcript data with a target duration
    Args:
        transcript_data: Processed transcript data from extract_transcript
        target_duration: Target duration for each chapter in seconds (default 30s)
    Returns:
        List[Chapter]: List of generated chapters
    """
    if not transcript_data or not transcript_data.get('paragraphs'):
        return []

    chapters = []
    current_chapter = []
    current_duration = 0
    chapter_start = None

    # Helper function to create a chapter from collected sentences
    def create_chapter(sentences: List[Dict[str, Any]], start: float, end: float) -> Chapter:
        return Chapter(
            start=start,
            end=end,
            text=" ".join(sent['text'] for sent in sentences),
            sentences=sentences
        )

    # Process each paragraph
    for para in transcript_data['paragraphs']:
        if not para.get('sentences'):
            continue

        for sentence in para['sentences']:
            sentence_duration = sentence['end'] - sentence['start']
            
            # If this is the first sentence of a new chapter
            if not current_chapter:
                chapter_start = sentence['start']
            
            # Add sentence to current chapter
            current_chapter.append(sentence)
            current_duration += sentence_duration
            
            # Check if we should close this chapter
            if current_duration >= target_duration:
                chapters.append(create_chapter(
                    current_chapter,
                    chapter_start,
                    sentence['end']
                ))
                current_chapter = []
                current_duration = 0
                chapter_start = None

    # Handle any remaining sentences
    if current_chapter:
        chapters.append(create_chapter(
            current_chapter,
            chapter_start,
            current_chapter[-1]['end']
        ))

    return chapters

def format_timestamp(seconds: float) -> str:
    """Convert seconds to HH:MM:SS format"""
    hours = int(seconds // 3600)
    minutes = int((seconds % 3600) // 60)
    seconds = int(seconds % 60)
    return f"{hours:02d}:{minutes:02d}:{seconds:02d}"

def format_chapters_for_display(chapters: List[Chapter]) -> str:
    """
    Format chapters into a readable string with timestamps
    Args:
        chapters: List of Chapter objects
    Returns:
        str: Formatted chapter list
    """
    output = []
    for i, chapter in enumerate(chapters, 1):
        start_time = format_timestamp(chapter.start)
        end_time = format_timestamp(chapter.end)
        duration = ceil(chapter.end - chapter.start)
        
        output.append(f"Chapter {i} ({start_time} - {end_time}, Duration: {duration}s)")
        output.append(f"Text: {chapter.text}")
        output.append("Sentences:")
        for sent in chapter.sentences:
            sent_start = format_timestamp(sent['start'])
            output.append(f"- [{sent_start}] {sent['text']}")
        output.append("")
    
    return "\n".join(output)

async def transcribe_video(url: str) -> Optional[Dict[str, Any]]:
    """
    Transcribe video using Deepgram API
    Args:
        url: URL of the video to transcribe
    Returns:
        Optional[Dict[str, Any]]: Transcription result from Deepgram or None if failed
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
        print(f"Traceback: {traceback.format_exc()}")
        return None

def extract_transcript(result: Dict[str, Any]) -> Optional[Dict[str, Any]]:
    """
    Extract readable transcript information from Deepgram response
    Args:
        result: Raw Deepgram response
    Returns:
        Optional[Dict[str, Any]]: Structured transcript data or None if invalid
    """
    try:
        if not result or 'results' not in result:
            return None
            
        transcript_data = {
            'full_text': '',
            'paragraphs': [],
            'metadata': result.get('metadata', {})
        }
        
        results = result['results']
        if 'channels' not in results:
            return None
            
        channel = results['channels'][0]  # Get first channel
        if 'alternatives' not in channel:
            return None
            
        alt = channel['alternatives'][0]  # Get first alternative
        transcript_data['full_text'] = alt.get('transcript', '')
        
        if 'paragraphs' in alt:
            for para in alt['paragraphs']['paragraphs']:
                paragraph = {
                    'start': para.get('start', 0),
                    'end': para.get('end', 0),
                    'text': para.get('text', ''),
                    'sentences': []
                }
                
                if 'sentences' in para:
                    for sent in para['sentences']:
                        paragraph['sentences'].append({
                            'text': sent.get('text', ''),
                            'start': sent.get('start', 0),
                            'end': sent.get('end', 0)
                        })
                        
                transcript_data['paragraphs'].append(paragraph)
        
        return transcript_data
        
    except Exception as e:
        print(f"Error extracting transcript: {str(e)}")
        return None

async def process_video_url(url: str, chapter_duration: float = 30.0) -> Optional[Dict[str, Any]]:
    """
    Process a video URL to get transcription and chapters
    Args:
        url: URL of the video to process
        chapter_duration: Target duration for each chapter in seconds
    Returns:
        Optional[Dict[str, Any]]: Processed transcript data with chapters or None if failed
    """
    result = await transcribe_video(url)
    if result:
        transcript_data = extract_transcript(result)
        if transcript_data:
            chapters = generate_chapters(transcript_data, chapter_duration)
            transcript_data['chapters'] = [
                {
                    'start': chapter.start,
                    'end': chapter.end,
                    'text': chapter.text,
                    'sentences': chapter.sentences
                }
                for chapter in chapters
            ]
            transcript_data['formatted_chapters'] = format_chapters_for_display(chapters)
        return transcript_data
    return None 