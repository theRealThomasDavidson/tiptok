from flask import Blueprint, request, jsonify
from .services.chapter_service import generate_semantic_chapters, summarize_chapter_with_gpt
from .services.transcription_service import generate_transcription, get_video_chapters, get_video_url, transcribe_with_deepgram
from werkzeug.exceptions import BadRequest
import asyncio

chapters_bp = Blueprint('chapters', __name__)

@chapters_bp.route('/get_summary', methods=['POST'])
def get_summary():
    """Get just the summary for a video
    Request body:
    {
        "videoPath": "videos/user_id/video_id.mp4"
    }
    """
    data = request.get_json()
    
    if not data or 'videoPath' not in data:
        return jsonify({'error': 'Missing videoPath in request body'}), 400

    video_path = data['videoPath']
    if not video_path.startswith('videos/'):
        return jsonify({'error': 'Invalid video path format'}), 400
        
    # First check if video exists and get URL
    try:
        url = get_video_url(video_path)
    except ValueError as e:
        return jsonify({'error': "howdy" + str(e)}), 404
    
    # Create new event loop for async operation
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)
    try:
        # Get transcription with summary option
        response = loop.run_until_complete(transcribe_with_deepgram(url, {}))
        if not response:
            return jsonify({
                'summary': 'No voice content detected in this video'
            }), 200

        # Get the transcript and generate summary
        transcript = response['results']['channels'][0]['alternatives'][0]['transcript']
        if not transcript:
            return jsonify({
                'summary': 'No transcription available for this video'
            }), 200

        # Generate summary from transcript
        summary = summarize_chapter_with_gpt([{'text': transcript}])
        return jsonify({
            'summary': summary
        }), 200
            
    finally:
        loop.close()


@chapters_bp.route('/generate_chapters', methods=['POST'])
def generate_chapters():
    """Generate chapters for a video
    Request body:
    {
        "videoPath": "videos/user_id/video_id.mp4"
    }
    """
    data = request.get_json()
    
    if not data or 'videoPath' not in data:
        return jsonify({'error': 'Missing videoPath in request body'}), 400

    video_path = data['videoPath']
    if not video_path.startswith('videos/'):
        return jsonify({'error': 'Invalid video path format'}), 400
        
    # First check if video exists and get URL
    try:
        url = get_video_url(video_path)
    except ValueError as e:
        return jsonify({'error': str(e)}), 404
        
    # Generate semantic chapters from the video
    result = generate_semantic_chapters(url)

    # Return only the essential data
    response = {
        'video_id': video_path,
        'chapters': [{
            'start': chapter['start'],
            'end': chapter['end'],
        } for chapter in result['chapters']]
    }
    
    return jsonify(response), 200
        


@chapters_bp.route('/transcribe', methods=['POST'])
def transcribe_video():
    """Generate full transcription with analysis
    Request body:
    {
        "videoPath": "videos/user_id/video_id.mp4",
        "options": {  # optional
            "summarize": true,
            "detectTopics": true,
            "extractKeywords": true,
            "sentiment": true
        }
    }
    """
    try:
        data = request.get_json()
        if not data or 'videoPath' not in data:
            return jsonify({'error': 'Missing videoPath in request body'}), 400

        video_path = data['videoPath']
        if not video_path.startswith('videos/'):
            return jsonify({'error': 'Video path must start with videos/'}), 400

        options = data.get('options', {
            'summarize': True,
            'detectTopics': True,
            'extractKeywords': True,
            'sentiment': True
        })

        result = generate_transcription(video_path, options)
        return jsonify(result), 200

    except Exception as e:
        return jsonify({
            'error': str(e),
            'error_type': type(e).__name__
        }), 500 