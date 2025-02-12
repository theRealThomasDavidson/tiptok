import os
import hashlib
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

def check_api_key():
    api_key = os.getenv('DEEPGRAM_API_KEY', 'not_found')
    key_hash = hashlib.sha256(api_key.encode()).hexdigest()[:10]
    print(f"\nExpected hash: d89812a1c2")
    print(f"Local hash:    {key_hash}")
    print(f"\nMatch: {key_hash == 'd89812a1c2'}")
    print(f"API key found: {'not_found' not in api_key}")

if __name__ == '__main__':
    check_api_key() 