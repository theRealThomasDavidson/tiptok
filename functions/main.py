# Initialize Firebase - no need for explicit credentials in Cloud Functions
from firebase_admin import initialize_app, storage, firestore
from firebase_functions import storage_fn
from flask import jsonify
import os
import json
from deepgram import Deepgram
import asyncio
import pathlib

app = initialize_app()

@storage_fn.on_object_finalized(max_instances=1)
def generate_chapters(event: storage_fn.CloudEvent) -> None:
    """Generates chapter markers when a video is uploaded."""
    file_path = pathlib.PurePath(event.data.name)
    
    # Check if this is a video in the videos collection
    if not str(file_path).startswith('videos/'):
        print(f"Ignoring file not in videos directory: {file_path}")
        return
        
    try:
        # Get video ID from path
        video_id = str(file_path).split('/')[-1].split('.')[0]
        
        # Get Firestore client inside the function
        db = firestore.client()
        processing_ref = db.collection('videoprocessing').document(video_id)
        
        # Update status to processing
        processing_ref.set({
            'status': 'processing',
            'path': str(file_path),
            'created_at': firestore.SERVER_TIMESTAMP
        })
        
        # Initialize Deepgram
        dg_client = Deepgram(os.getenv('DEEPGRAM_API_KEY'))
        
        # Get video from Firebase Storage
        bucket = storage.bucket()
        blob = bucket.blob(str(file_path))
        
        # Get blob metadata
        blob.reload()
        print(f"Processing video: {blob.name}")
        print(f"Content type: {blob.content_type}")
        
        # Generate signed URL for Deepgram
        url = blob.generate_signed_url(
            version="v4",
            expiration=600,  # 10 minutes
            method="GET"
        )
        
        # Send to Deepgram for transcription
        async def transcribe():
            source = {'url': url}
            options = {
                'punctuate': True,
                'paragraphs': True,
                'summarize': True,
                'detect_topics': True
            }
            return await dg_client.transcription.prerecorded(source, options)

        # Run the transcription
        transcription = asyncio.run(transcribe())
        
        # Extract chapters
        chapters = []
        if 'results' in transcription:
            paragraphs = transcription['results'].get('paragraphs', [])
            for para in paragraphs:
                chapters.append({
                    'start': para['start'],
                    'end': para['end'],
                    'summary': para.get('summary', ''),
                    'topics': para.get('topics', [])
                })
        
        # Add chapters as metadata to the original video
        blob.metadata = {
            'chapters': json.dumps(chapters),
            'processed_at': firestore.SERVER_TIMESTAMP.isoformat()
        }
        blob.patch()
        
        # Update status to completed
        processing_ref.update({
            'status': 'completed',
            'chapters': chapters,
            'completed_at': firestore.SERVER_TIMESTAMP
        })
        
        print(f"Successfully processed video: {blob.name}")
        
    except Exception as e:
        # Update status to error in Firestore
        if 'processing_ref' in locals():
            processing_ref.update({
                'status': 'error',
                'error': str(e),
                'error_type': type(e).__name__
            })
        print(f"Error processing video: {str(e)}")
        print(f"Error type: {type(e).__name__}")
        