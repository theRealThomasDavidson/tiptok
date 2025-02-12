from flask import Blueprint, request, jsonify
from .services.chapter_service import process_video
from .services.transcription_service import generate_transcription, get_video_chapters
import traceback

chapters_bp = Blueprint('chapters', __name__)

@chapters_bp.route('/generate_chapters', methods=['POST'])
def generate_chapters():
    """Generate chapters for a video
    Request body:
    {
        "videoPath": "videos/user_id/video_id.mp4",
        "chapterDuration": 30  # optional, defaults to 30 seconds
    }
    """
    data = request.get_json()
    
    if not data or 'videoPath' not in data:
        return jsonify({'error': 'Missing videoPath in request body'}), 400

    video_path = data['videoPath']
    if not video_path.startswith('videos/'):
        return jsonify({'error': 'Invalid video path format'}), 400
        
    chapter_duration = data.get('chapterDuration', 30.0)
    if not isinstance(chapter_duration, (int, float)) or chapter_duration <= 0:
        return jsonify({'error': 'Invalid chapter duration'}), 400

    # Process the video
    result = process_video(video_path, chapter_duration)
    
    # Return only the essential data
    response = {
        'video_id': result['video_id'],
        'chapters': [{
            'start': chapter['start'],
            'end': chapter['end'],
            'text': chapter['text']
        } for chapter in result['chapters']]
    }
    
    return jsonify(response), 200


@chapters_bp.route('/get_chapters/<video_id>', methods=['GET'])
def get_chapters(video_id):
    """Get existing chapters for a video"""
    try:
        chapters = get_video_chapters(video_id)
        if chapters:
            return jsonify(chapters), 200
        return jsonify({'error': 'No chapters found for this video'}), 404
    except Exception as e:
        return jsonify({
            'error': str(e),
            'error_type': type(e).__name__
        }), 500

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