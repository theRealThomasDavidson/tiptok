from firebase_admin import initialize_app, credentials, get_app, storage
from openai import OpenAI
from deepgram import Deepgram
import os
import asyncio
from typing import Dict, Any, List, Optional
from datetime import timedelta

# Initialize Firebase Admin
try:
    cred = credentials.Certificate('firebase-credentials.json')
    initialize_app(cred, {
        'storageBucket': 'trainup-51d3c.firebasestorage.app'
    })
except ValueError:
    # If the app is already initialized, get the existing app
    app = get_app()

# Initialize OpenAI client
client = OpenAI(api_key=os.environ.get('OPENAI_API_KEY'))

def get_video_url(video_path: str) -> str:
    """Generate a signed URL for accessing the video"""
    bucket = storage.bucket()
    blob = bucket.blob(video_path)
    return blob.generate_signed_url(
        version="v4",
        expiration=timedelta(minutes=15),
        method="GET"
    )

async def transcribe_with_deepgram(url: str, options: Dict[str, bool]) -> Optional[Dict[str, Any]]:
    """Transcribe video using Deepgram with specified options
    
    Returns:
        The first alternative from the first channel, or None if no voice content
    """
    dg_client = Deepgram(os.getenv('DEEPGRAM_API_KEY'))
    
    source = {'url': url}
    dg_options = {
        'punctuate': True,
        'paragraphs': True,
        'utterances': True,
        'tier': 'enhanced'
    }
    
    if options.get('summarize'):
        dg_options['summarize'] = True
    if options.get('detectTopics'):
        dg_options['detect_topics'] = True
    if options.get('sentiment'):
        dg_options['detect_sentiment'] = True
    
    response = await dg_client.transcription.prerecorded(source, dg_options)
    
    # Extract just the transcript data we need
    try:
        return response['results']['channels'][0]['alternatives'][0]
    except (KeyError, IndexError):
        return None

def group_blocks_with_gpt(blocks: List[Dict]) -> List[List[int]]:
    """Use GPT to group blocks into logical chapters based on topics"""
    blocks_text = "\n".join(f"Block {i}: {block.get('text', '')}" for i, block in enumerate(blocks))
    
    # Create the prompt with better guidance
    prompt = f"""You are analyzing a training video transcript that may contain:
1. A brief introduction/overview section
2. Several main topics or sections
3. A brief conclusion

Guidelines for grouping:
- The introduction (if present) should be its own chapter, usually not too many blocks propbably not more than 7
- Each distinct topic or concept should be its own chapter
- Keep related instructions or explanations together
- The conclusion (if present) should be its own chapter
- If someone were to get a single chapter that is relevant it should offer a good refresher on the topic
- Aim for logical breaks between different concepts or steps
- Chapters should have 2-6 blocks unless it's a detailed technical explanation

Here are the transcript blocks:

{blocks_text}

Group these blocks into logical chapters based on topic changes and natural breaks in content.
Return your answer as a list of chapters, where each chapter is a list of consecutive block numbers.
Format: Return a list of lists, where each inner list contains consecutive block numbers that form a chapter.
Example: If blocks 0-2 form the intro, blocks 3-5 form a topic, etc., return: [[0,1,2], [3,4,5], ...]
Only return the list, no other text.

keep in mind that we want these to be easily consumable for training videos that are not much longer than a minute
"""

    response = client.chat.completions.create(
        model="gpt-4",
        messages=[
            {"role": "system", "content": "You are a helpful assistant that understands how training videos are structured, with introductions, main topics, and conclusions."},
            {"role": "user", "content": prompt}
        ],
        temperature=0
    )
    
    try:
        return eval(response.choices[0].message.content.strip())
    except Exception as e:
        raise ValueError("Failed to parse GPT response for block grouping")

def summarize_chapter_with_gpt(blocks: List[Dict]) -> str:
    """Use GPT to generate a concise summary of a chapter"""
    chapter_text = " ".join(block.get('text', '') for block in blocks)
    
    prompt = f"""Summarize this section of a video transcript in one or two sentences:

{chapter_text}

Return only the summary, no other text."""

    response = client.chat.completions.create(
        model="gpt-3.5-turbo",  # Using 3.5 for summaries to save cost
        messages=[
            {"role": "system", "content": "You are a helpful assistant that creates concise summaries."},
            {"role": "user", "content": prompt}
        ],
        temperature=0.3
    )
    
    return response.choices[0].message.content.strip()

def create_chapter_from_blocks(blocks: List[Dict]) -> Dict:
    """Create a chapter object from a list of blocks"""
    texts = [block.get('text', '') for block in blocks]
    
    return {
        'start': float(blocks[0]['start']),
        'end': float(blocks[-1]['end']),
        'text': ' '.join(texts),
    }

def generate_semantic_chapters(video_url: str) -> Dict[str, Any]:
    """Generate semantically coherent chapters from a video using AI transcription and analysis.
    
    Args:
        video_url: The signed URL to access the video
        
    Returns:
        Dict containing list of chapters. Returns empty chapters list if:
        - No audio/voice content detected
        - No paragraphs/sentences found in transcript
        - Unable to generate meaningful chapters
    """
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)
    try:
        transcript = loop.run_until_complete(transcribe_with_deepgram(video_url, {}))
    finally:
        loop.close()

    if not transcript:
        return {'chapters': []}
    
    blocks = []
    if 'paragraphs' in transcript:
        for para in transcript['paragraphs'].get('paragraphs', []):
            if 'sentences' in para:
                blocks.extend(para['sentences'])
    
    if not blocks:
        return {'chapters': []}
        
    try:
        block_groups = group_blocks_with_gpt(blocks)
        return {
            'chapters': [
                create_chapter_from_blocks([blocks[i] for i in group])
                for group in block_groups
            ]
        }
    except Exception:
        return {'chapters': []} 