"""
GozAI Firebase RAG Seeding Script

This script uploads the hardcoded clinical datasets into Firestore so 
the GozAI agent can execute dynamic RAG queries against a live, cloud-hosted 
database rather than relying strictly on local dicts. Run this once 
to populate the `gozai_rag_data` collection in your Firebase project.
"""

import os
import firebase_admin
from firebase_admin import credentials, firestore

from gozai_agent.rag_service import OPTOMETRY_DATA, MEDICATION_DATA, LOW_VISION_STATS

def seed_firestore():
    # Attempt to initialize Firebase Admin
    if not firebase_admin._apps:
        # Relies on GOOGLE_APPLICATION_CREDENTIALS being set, or runs via Cloud Shell
        try:
            firebase_admin.initialize_app()
        except Exception as e:
            print(f"Failed to initialize Firebase Admin SDK: {e}")
            print("Make sure you have run 'gcloud auth application-default login'")
            return

    db = firestore.client()
    batch = db.batch()
    
    collection_ref = db.collection("gozai_rag_data")
    print("Seeding GozAI Clinical RAG documents to Firestore...")
    
    doc_count = 0
    
    # 1. Optometry Guidelines
    for key, data in OPTOMETRY_DATA.items():
        doc_ref = collection_ref.document(f"optometry_{key.replace(' ', '_')}")
        batch.set(doc_ref, {
            "domain": "optometry",
            "key": key,
            "data": data,
            "version": "1.0"
        })
        doc_count += 1

    # 2. Medication Data
    for key, data in MEDICATION_DATA.items():
        doc_ref = collection_ref.document(f"medication_{key.replace(' ', '_')}")
        batch.set(doc_ref, {
            "domain": "medication",
            "key": key,
            "data": data,
            "version": "1.0"
        })
        doc_count += 1
        
    # 3. Clinical Statistics
    for key, data in LOW_VISION_STATS.items():
        doc_ref = collection_ref.document(f"stats_{key.replace(' ', '_')}")
        batch.set(doc_ref, {
            "domain": "statistics",
            "key": key,
            "data": data,
            "version": "1.0"
        })
        doc_count += 1

    try:
        batch.commit()
        print(f"Successfully committed {doc_count} dynamic RAG documents to Firestore!")
    except Exception as e:
        print(f"Error writing to Firestore: {e}")

if __name__ == "__main__":
    seed_firestore()
