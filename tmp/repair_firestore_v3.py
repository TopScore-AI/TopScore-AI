import os
import json
import firebase_admin
from firebase_admin import credentials, firestore
from google import genai
from dotenv import load_dotenv
import time

# Load env from TutorAgent
load_dotenv('C:/Users/Veldrine/Projects/TutorAgent/.env')

cred_json = os.getenv('FIREBASE_CREDENTIALS_JSON')
api_key = os.getenv('GEMINI_API_KEY')
if not cred_json or not api_key:
    print("Error: Credentials or Gemini API Key not found")
    exit(1)

# Initialize GenAI
client = genai.Client(api_key=api_key)
MODEL_ID = "gemini-2.0-flash-thinking-exp-01-21"

def generate_short_title(filename: str) -> str:
    """Uses Gemini to generate a concise, professional display title."""
    prompt = f"Given this educational resource filename, generate a concise, professional display title (max 60 chars). Remove redundant codes like '0452', 'IGCSE', 'Past Papers', and repeated years. Example: 'Accounting 0452 IGCSE Past Papers - 0452_7110_accounting_teacher_guide_2014.pdf' -> 'Accounting Teacher Guide'. Respond ONLY with the title.\n\nFilename: {filename}"
    try:
        response = client.models.generate_content(
            model=MODEL_ID,
            contents=prompt
        )
        return response.text.strip().replace('"', '')[:70]
    except Exception as e:
        print(f"      AI Error: {e}")
        return filename[:60]

try:
    cred = credentials.Certificate(json.loads(cred_json))
    if not firebase_admin._apps:
        firebase_admin.initialize_app(cred)
    db = firestore.client()
    
    collections = ['igcse_files', 'cbc_files', '844_files']
    total_shortened = 0
    
    for coll_name in collections:
        print(f"Scanning {coll_name} for long names...")
        docs = db.collection(coll_name).stream()
        
        for doc in docs:
            data = doc.to_dict()
            name = data.get('name', '')
            
            if len(name) > 40:
                print(f"  Shortening: {name[:40]}...")
                new_name = generate_short_title(name)
                
                if new_name and new_name != name:
                    db.collection(coll_name).document(doc.id).update({
                        'name': new_name,
                        'fileNameLower': new_name.lower()
                    })
                    print(f"    -> Done: {new_name}")
                    total_shortened += 1
                    # Rate limiting protection
                    time.sleep(1)
                
    print(f"\n--- SUCCESS: Total titles shortened: {total_shortened} ---")
            
except Exception as e:
    print(f"Error: {e}")
