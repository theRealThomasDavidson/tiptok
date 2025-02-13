from firebase_admin import initialize_app, storage, firestore, credentials
import os
from datetime import datetime
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

def init_firebase():
    """Initialize Firebase with service account"""
    cred = credentials.Certificate('firebase-credentials.json')
    initialize_app(cred, {
        'storageBucket': 'trainup-51d3c.firebasestorage.app'
    })
    return storage.bucket(), firestore.client()

def cleanup_orphaned_references():
    """Clean up orphaned references between Firestore and Storage"""
    print("\n=== Starting Storage Cleanup ===")
    bucket, db = init_firebase()
    
    # Get all videos from Firestore
    print("\nFetching Firestore references...")
    firestore_refs = {}
    videos_collection = db.collection('videos').get()
    for doc in videos_collection:
        data = doc.to_dict()
        firestore_refs[doc.id] = {
            'doc_ref': doc.reference,
            'url': data.get('url'),
            'thumbnailUrl': data.get('thumbnailUrl'),
            'userId': data.get('userId'),
        }
    print(f"Found {len(firestore_refs)} videos in Firestore")

    # Get all videos from Storage
    print("\nFetching Storage files...")
    storage_files = {}
    storage_blobs = bucket.list_blobs(prefix='videos/')
    for blob in storage_blobs:
        storage_files[blob.name] = blob
    print(f"Found {len(storage_files)} files in Storage")

    # Get all thumbnails from Storage
    thumbnail_files = {}
    thumbnail_blobs = bucket.list_blobs(prefix='thumbnails/')
    for blob in thumbnail_blobs:
        thumbnail_files[blob.name] = blob
    print(f"Found {len(thumbnail_files)} thumbnails in Storage")

    # Track cleanup statistics
    deleted_docs = 0
    orphaned_docs = []

    print("\nChecking for orphaned references...")
    
    # Check each Firestore document
    for doc_id, data in firestore_refs.items():
        if not data.get('url'):
            print(f"\nOrphaned document found (no URL): {doc_id}")
            orphaned_docs.append(data['doc_ref'])
            deleted_docs += 1
            continue

        # Extract the path from the URL
        try:
            url = data['url']
            # The URL format is like: https://firebasestorage.googleapis.com/v0/b/bucket/o/videos%2FuserId%2FvideoId.mp4
            video_path = url.split('/o/')[1].split('?')[0].replace('%2F', '/')
            if not video_path in storage_files:
                print(f"\nOrphaned document found (file missing): {doc_id}")
                print(f"Video file missing: {video_path}")
                orphaned_docs.append(data['doc_ref'])
                deleted_docs += 1

        except Exception as e:
            print(f"Error processing URL for document {doc_id}: {str(e)}")
            continue

    # Delete orphaned Firestore documents
    for doc_ref in orphaned_docs:
        print(f"Deleting Firestore document: {doc_ref.id}")
        doc_ref.delete()

    print("\n=== Cleanup Summary ===")
    print(f"Deleted Firestore documents: {deleted_docs}")
    print(f"Note: No storage files were deleted to prevent accidental data loss")
    print("\nCleanup completed!")

if __name__ == "__main__":
    cleanup_orphaned_references() 