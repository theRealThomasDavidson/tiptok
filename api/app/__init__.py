from flask import Flask
from flask_cors import CORS

def create_app():
    app = Flask(__name__)
    CORS(app)  # Enable CORS for all routes
    
    # Import and register blueprints
    from .routes import chapters_bp
    app.register_blueprint(chapters_bp)
    
    return app 