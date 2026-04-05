import os
import json
import firebase_admin
from firebase_admin import credentials, firestore
from dotenv import load_dotenv

# Load env from TutorAgent
load_dotenv('C:/Users/Veldrine/Projects/TutorAgent/.env')

cred_json = os.getenv('FIREBASE_CREDENTIALS_JSON')
if not cred_json:
    print("Error: FIREBASE_CREDENTIALS_JSON not found")
    exit(1)

try:
    cred = credentials.Certificate(json.loads(cred_json))
    firebase_admin.initialize_app(cred)
    db = firestore.client()
    
    collections = ['igcse_files', 'cbc_files', '844_files']
    total_fixed = 0
    
    for coll_name in collections:
        print(f"Scanning {coll_name}...")
        docs = db.collection(coll_name).stream()
        
        for doc in docs:
            data = doc.to_dict()
            needs_update = False
            updates = {}
            
            # 1. Fix Path
            path = data.get('path', '')
            if path.lower().endswith('.pdf.pdf'):
                updates['path'] = path[:-4] # Remove the extra .pdf
                needs_update = True
                
            # 2. Fix Name (Display Title)
            name = data.get('name', '')
            if name.lower().endswith('.pdf'):
                # Also handles .Pdf due to previous title-casing bug
                updates['name'] = name[:-4].strip()
                updates['fileNameLower'] = updates['name'].lower()
                needs_update = True
                
            # 3. Fix Download URL
            url = data.get('downloadUrl', '')
            if url and '.pdf.pdf' in url.lower():
                updates['downloadUrl'] = url.replace('.pdf.pdf', '.pdf').replace('.Pdf.pdf', '.pdf')
                needs_update = True
                
            if needs_update:
                db.collection(coll_name).document(doc.id).update(updates)
                print(f"  Fixed: {name} -> {updates.get('name', name)}")
                total_fixed += 1
                
    print(f"\n--- SUCCESS: Total records fixed: {total_fixed} ---")
            
except Exception as e:
    print(f"Error: {e}")
