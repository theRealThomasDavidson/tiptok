from flask import Blueprint, request, jsonify
from firebase_admin import initialize_app, credentials, get_app, storage
from openai import OpenAI
from deepgram import Deepgram
import os
import asyncio
from typing import Dict, Any, List, Optional
from datetime import timedelta

chapters_bp = Blueprint('chapters', __name__, url_prefix='/api')

@chapters_bp.route('/test', methods=['GET'])
def test_route():
    return jsonify({'status': 'ok', 'message': 'API is working'}), 200

# Initialize Firebase Admin
// ... existing code ... 