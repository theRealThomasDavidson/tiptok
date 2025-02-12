from firebase_admin import storage, initialize_app, credentials
import os
from deepgram import Deepgram
import asyncio
from typing import Dict, Any, List
from datetime import timedelta
import aiohttp
from openai import OpenAI

# Initialize Firebase Admin
cred = credentials.Certificate('/app/firebase-credentials.json')
initialize_app(cred, {
    'storageBucket': os.environ.get('FIREBASE_STORAGE_BUCKET')
})

# Initialize OpenAI client
client = OpenAI(api_key=os.environ.get('OPENAI_API_KEY'))

def get_video_url(video_path: str) -> str:
    """Get a signed URL for the video"""
    bucket = storage.bucket()
    blob = bucket.blob(video_path)
    return blob.generate_signed_url(
        version="v4",
        expiration=timedelta(minutes=15),
        method="GET"
    )

async def transcribe_with_deepgram(url: str) -> Dict[str, Any]:
    """Get video transcription with more granular segmentation"""
    dg_client = Deepgram(os.environ.get('DEEPGRAM_API_KEY'))
    
    source = {'url': url}
    options = {
        'punctuate': True,
        'paragraphs': True,
        'utterances': True,
        'tier': 'enhanced',
        'smart_format': True,
        'diarize': True,
        'numerals': True,
        'utt_split': 0.8  # Split utterances more frequently
    }
    
    timeout = aiohttp.ClientTimeout(total=60)
    async with aiohttp.ClientSession(timeout=timeout) as session:
        dg_client._session = session
        response = await dg_client.transcription.prerecorded(source, options)
        
        if not response or 'results' not in response:
            raise ValueError("Invalid response from Deepgram")
            
        return response

def group_blocks_with_gpt(blocks: List[Dict]) -> List[List[int]]:
    """Use GPT to group blocks into logical chapters based on topics"""
    # Debug print full structure
    print("\nBlock structure example:")
    print(blocks[0] if blocks else "No blocks")
    
    # Prepare the blocks for GPT
    formatted_blocks = []
    for i, block in enumerate(blocks):
        text = block.get('text', '')
        formatted_blocks.append(f"Block {i}: {text}")
        print(f"Block {i} text: {text}")  # Debug print
    
    blocks_text = "\n".join(formatted_blocks)
    
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

    # Get GPT's response
    response = client.chat.completions.create(
        model="gpt-4",
        messages=[
            {"role": "system", "content": "You are a helpful assistant that understands how training videos are structured, with introductions, main topics, and conclusions."},
            {"role": "user", "content": prompt}
        ],
        temperature=0
    )
    
    # Parse GPT's response into list of block groups
    try:
        # Clean up the response and evaluate it as a Python list
        response_text = response.choices[0].message.content.strip()
        print("GPT Response:", response_text)  # Debug print
        block_groups = eval(response_text)
        return block_groups
    except Exception as e:
        print(f"Error parsing GPT response: {str(e)}")
        raise ValueError("Failed to parse GPT response for block grouping")

def summarize_chapter_with_gpt(blocks: List[Dict]) -> str:
    """Use GPT to generate a concise summary of a chapter"""
    # For sentence blocks, text is directly in the block
    chapter_text = " ".join(block.get('text', '') for block in blocks)
    
    prompt = f"""Summarize this section of a video transcript in one or two concise sentences:

{chapter_text}

Return only the summary, no other text."""

    # Get GPT's response
    response = client.chat.completions.create(
        model="gpt-3.5-turbo",  # Using 3.5 for summaries to save cost
        messages=[
            {"role": "system", "content": "You are a helpful assistant that creates concise summaries."},
            {"role": "user", "content": prompt}
        ],
        temperature=0.3
    )
    
    return response.choices[0].message.content.strip()

def create_chapter_from_blocks(blocks: List[Dict], summary: str) -> Dict:
    """Create a chapter object from a list of blocks"""
    # For sentence blocks, text is directly in the block
    texts = [block.get('text', '') for block in blocks]
    
    return {
        'start': float(blocks[0]['start']),
        'end': float(blocks[-1]['end']),
        'text': ' '.join(texts),
        'summary': summary
    }

def process_video(video_path: str, chapter_duration: float = 30.0) -> Dict[str, Any]:
    """Process video into semantically coherent chapters"""
    # Get video URL
    url = get_video_url(video_path)
    video_id = video_path.split('/')[-1].split('.')[0]
    
    # Get transcription
    response = asyncio.run(transcribe_with_deepgram(url))
    transcript = response['results']['channels'][0]['alternatives'][0]
    
    # Generate chapters
    chapters = []
    
    # Extract sentences from paragraphs
    blocks = []
    if 'paragraphs' in transcript:
        paragraphs = transcript['paragraphs'].get('paragraphs', [])
        for para in paragraphs:
            if 'sentences' in para:
                blocks.extend(para['sentences'])
    
    if not blocks:
        raise ValueError("No sentence blocks found in transcript")
        
    print(f"\nProcessing {len(blocks)} sentence blocks...")
    
    # Group blocks by topic using GPT
    block_groups = group_blocks_with_gpt(blocks)
    print(f"\nFound {len(block_groups)} topic groups")
    
    # Process each group into a chapter
    for i, group_indices in enumerate(block_groups):
        print(f"\nProcessing Chapter {i+1}:")
        # Get the blocks for this group
        group_blocks = [blocks[i] for i in group_indices]
        
        # Get a summary for this group
        summary = summarize_chapter_with_gpt(group_blocks)
        
        # Create the chapter
        chapter = create_chapter_from_blocks(group_blocks, summary)
        chapters.append(chapter)
        
        print(f"Chapter {i+1} ({chapter['start']:.1f}s - {chapter['end']:.1f}s)")
        print(f"Summary: {chapter['summary']}")
        print("-" * 50)
    
    if not chapters:
        raise ValueError("No chapters could be generated")
    
    return {
        'video_id': video_id,
        'chapters': chapters
    } 