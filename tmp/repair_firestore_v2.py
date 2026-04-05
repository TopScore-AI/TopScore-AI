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
    # Use explicit credential parsing to avoid path issues
    cred_dict = json.loads(cred_json)
    cred = credentials.Certificate(cred_dict)
    
    if not firebase_admin._apps:
        firebase_admin.initialize_app(cred)
        
    db = firestore.client()
    
    collections = ['igcse_files', 'cbc_files', '844_files']
    total_fixed = 0
    
    for coll_name in collections:
        print(f"Scanning {coll_name}...")
        coll_ref = db.collection(coll_name)
        docs = coll_ref.stream()
        
        # Batch updates for efficiency
        batch = db.batch()
        batch_count = 0
        
        for doc in docs:
            data = doc.to_dict()
            needs_update = False
            updates = {}
            
            # 1. Fix Path
            path = str(data.get('path', ''))
            if path.lower().endswith('.pdf.pdf'):
                # Correct it to end in single .pdf
                updates['path'] = path[:-4]
                needs_update = True
                
            # 2. Fix Name (Display Title) - handle .Pdf or .pdf
            name = str(data.get('name', ''))
            if name.lower().endswith('.pdf'):
                updates['name'] = name[:-4].strip()
                updates['fileNameLower'] = updates['name'].lower()
                needs_update = True
                
            # 3. Fix Download URL (remove double .pdf before the alt parameter)
            url = str(data.get('downloadUrl', ''))
            if url and '.pdf.pdf' in url.lower():
                # case-insensitive replace of .pdf.pdf with .pdf
                import re
                new_url = re.sub(r'\.[pP]df\.pdf', '.pdf', url)
                if new_url != url:
                    updates['downloadUrl'] = new_url
                    needs_update = True
                
            if needs_update:
                batch.update(doc.reference, updates)
                print(f"  Targeted for Fix: {name} ({doc.id})")
                batch_count += 1
                total_fixed += 1
                
                if batch_count >= 400: # Firestore batch limit is 500
                    batch.commit()
                    batch = db.batch()
                    batch_count = 0
        
        if batch_count > 0:
            batch.commit()
            
    print(f"\n--- SUCCESS: Total records fixed: {total_fixed} ---")
            
except Exception as e:
    import traceback
    print(f"Error: {e}")
    traceback.print_exc()
