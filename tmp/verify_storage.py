import os
import json
import firebase_admin
from firebase_admin import credentials, storage
from dotenv import load_dotenv

# Load env from TutorAgent
load_dotenv('C:/Users/Veldrine/Projects/TutorAgent/.env')

cred_json = os.getenv('FIREBASE_CREDENTIALS_JSON')
if not cred_json:
    print("Error: FIREBASE_CREDENTIALS_JSON not found")
    exit(1)

try:
    cred = credentials.Certificate(json.loads(cred_json))
    firebase_admin.initialize_app(cred, {
        'storageBucket': 'elimisha-90787.firebasestorage.app'
    })
    
    bucket = storage.bucket()
    print("--- Listing files in resources/IGCSE/ ---")
    blobs = bucket.list_blobs(prefix='resources/IGCSE')
    
    for blob in blobs:
        if blob.name.lower().endswith('.pdf'):
            print(blob.name)
            
except Exception as e:
    print(f"Error: {e}")
