from firebase_admin import storage, firestore
from deepgram import Deepgram
import os
import asyncio
from typing import Dict, Any, Optional, List
import json
from datetime import timedelta

def get_video_url(video_path: str) -> str:
    """Generate a signed URL for accessing the video"""
    bucket = storage.bucket()
    blob = bucket.blob(video_path)
    return blob.generate_signed_url(
        version="v4",
        expiration=timedelta(minutes=15),
        method="GET"
    )

def get_video_chapters(video_id: str) -> Optional[Dict[str, Any]]:
    """Get existing chapters for a video from Firestore"""
    db = firestore.client()
    doc = db.collection('videoprocessing').document(video_id).get()
    if doc.exists:
        data = doc.to_dict()
        if data.get('status') == 'completed':
            return {
                'chapters': data.get('chapters', []),
                'created_at': data.get('created_at'),
                'video_id': video_id
            }
    return None

async def transcribe_with_deepgram(url: str, options: Dict[str, bool]) -> Dict[str, Any]:
    """Transcribe video using Deepgram with specified options"""
    dg_client = Deepgram(os.getenv('DEEPGRAM_API_KEY'))
    
    source = {'url': url}
    dg_options = {
        'punctuate': True,
        'paragraphs': True,
        'utterances': True,
        'tier': 'enhanced'
    }
    
    # Add optional features
    if options.get('summarize'):
        dg_options['summarize'] = True
    if options.get('detectTopics'):
        dg_options['detect_topics'] = True
    if options.get('sentiment'):
        dg_options['detect_sentiment'] = True
    
    response = await dg_client.transcription.prerecorded(source, dg_options)
    return response

def extract_keywords(text: str, max_keywords: int = 10) -> List[str]:
    """Extract important keywords from text using basic frequency analysis"""
    # This is a simple implementation - could be enhanced with NLP libraries
    import re
    from collections import Counter
    
    # Remove common stop words
    stop_words = {'the', 'a', 'an', 'and', 'or', 'but', 'in', 'on', 'at', 'to', 'for', 'is', 'are', 'was', 'were'}
    
    # Split into words and clean
    words = re.findall(r'\b\w+\b', text.lower())
    words = [w for w in words if w not in stop_words and len(w) > 3]
    
    # Get most common words
    return [word for word, _ in Counter(words).most_common(max_keywords)]

def generate_transcription(video_path: str, options: Dict[str, bool]) -> Dict[str, Any]:
    """Generate full transcription with analysis"""
    try:
        # Get video URL
        url = get_video_url(video_path)
        
        # Process with Deepgram
        response = asyncio.run(transcribe_with_deepgram(url, options))
        
        if not response or 'results' not in response:
            raise ValueError("Failed to get valid response from Deepgram")
            
        results = response['results']
        transcript = results['channels'][0]['alternatives'][0]
        
        # Extract basic transcript info
        output = {
            'full_text': transcript.get('transcript', ''),
            'confidence': transcript.get('confidence', 0),
            'words': transcript.get('words', []),
            'paragraphs': []
        }
        
        # Add paragraphs if available
        if 'paragraphs' in transcript:
            output['paragraphs'] = transcript['paragraphs'].get('paragraphs', [])
        
        # Add summary if requested and available
        if options.get('summarize') and 'summary' in results:
            output['summary'] = results['summary']
            
        # Add topics if requested and available
        if options.get('detectTopics') and 'topics' in results:
            output['topics'] = results['topics']
            
        # Add keywords
        if options.get('extractKeywords'):
            output['keywords'] = extract_keywords(output['full_text'])
            
        # Add sentiment if requested and available
        if options.get('sentiment') and 'sentiment' in results:
            output['sentiment'] = results['sentiment']
            
        # Store results in Firestore
        video_id = video_path.split('/')[-1].split('.')[0]
        db = firestore.client()
        db.collection('transcriptions').document(video_id).set({
            'status': 'completed',
            'results': output,
            'created_at': firestore.SERVER_TIMESTAMP
        })
        
        return output
        
    except Exception as e:
        print(f"Error in generate_transcription: {str(e)}")
        raise 