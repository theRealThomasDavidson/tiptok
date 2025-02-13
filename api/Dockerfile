FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    python3-dev \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY app/ app/

# Copy Firebase credentials
COPY firebase-credentials.json .

# Set environment variables
ENV FIREBASE_CREDENTIALS=firebase-credentials.json
ENV PYTHONUNBUFFERED=1

# Run the application
CMD ["gunicorn", "--bind", "0.0.0.0:8080", "--workers", "2", "--timeout", "300", "app:create_app()"] 