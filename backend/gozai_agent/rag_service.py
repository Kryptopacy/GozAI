import os
import numpy as np
import google.genai as genai

# Hardcoded datasets extracted from the old tools.py
OPTOMETRY_DATA = {
    "light sensitivity": {
        "answer": (
            "Light sensitivity (photophobia) is common with many eye conditions "
            "including glaucoma, macular degeneration, and cataracts. "
            "Recommendations: Use sunglasses with UV protection outdoors. "
            "Amber or yellow-tinted lenses can reduce glare. "
            "Adjust screen brightness and use dark mode on devices."
        ),
        "source": "American Academy of Ophthalmology",
        "action": "Schedule an appointment with your eye care professional if sensitivity worsens.",
    },
    "eye pain": {
        "answer": (
            "Eye pain can range from mild irritation to a sign of serious conditions. "
            "Common causes include dry eyes, eye strain, or infection. "
            "Urgent signs requiring immediate care: sudden severe pain, "
            "vision changes, pain with redness and nausea."
        ),
        "source": "American Optometric Association",
        "action": "If pain is severe or sudden, seek immediate eye care.",
    },
    "dry eyes": {
        "answer": (
            "Dry eye disease is common, especially with screen use. "
            "Tips: Follow the 20-20-20 rule (every 20 minutes, look 20 feet away "
            "for 20 seconds). Use preservative-free artificial tears. "
            "Stay hydrated and consider a humidifier."
        ),
        "source": "American Academy of Ophthalmology",
        "action": "Consult your optometrist if symptoms persist for personalized treatment.",
    },
    "floaters": {
        "answer": (
            "Floaters are small spots or lines in your vision. They are usually "
            "harmless age-related changes. URGENT: A sudden increase in floaters, "
            "especially with flashes of light or a shadow over your vision, "
            "could indicate retinal detachment — seek immediate care."
        ),
        "source": "National Eye Institute (NEI)",
        "action": "See your eye doctor urgently if you notice a sudden increase in floaters.",
    },
}

MEDICATION_DATA = {
    "timolol": {
        "type": "Eye drops (beta-blocker)",
        "common_use": "Glaucoma — reduces eye pressure",
        "general_info": "Usually applied once or twice daily. Store at room temperature.",
        "safety": "Do not use if you have asthma or certain heart conditions without doctor approval.",
    },
    "latanoprost": {
        "type": "Eye drops (prostaglandin analog)",
        "common_use": "Glaucoma — reduces eye pressure",
        "general_info": "Usually applied once daily in the evening. May darken iris color over time.",
        "safety": "Store in refrigerator before opening. Room temperature after opening.",
    },
    "prednisolone": {
        "type": "Eye drops (corticosteroid)",
        "common_use": "Eye inflammation",
        "general_info": "Shake well before use. Do not stop suddenly — taper as directed.",
        "safety": "Long-term use can increase eye pressure. Regular monitoring required.",
    },
}

def cosine_similarity(v1, v2):
    """Compute cosine similarity between two 1D normalized vectors."""
    return np.dot(v1, v2) / (np.linalg.norm(v1) * np.linalg.norm(v2))


class SemanticKnowledgeBase:
    """In-memory RAG database using Gemini embeddings."""
    
    _instance = None

    def __new__(cls):
        if cls._instance is None:
            cls._instance = super(SemanticKnowledgeBase, cls).__new__(cls)
            cls._instance._initialized = False
        return cls._instance

    def __init__(self):
        if self._initialized:
            return
            
        # Try to initialize the client (uses GEMINI_API_KEY from env)
        try:
            self.client = genai.Client()
        except Exception as e:
            print(f"Warning: Failed to initialize genai Client: {e}")
            self.client = None
            
        self.embedding_model = "text-embedding-004"
        
        # Store dicts of {key: embedding}
        self.optometry_embeddings = {}
        self.medication_embeddings = {}
        
        # Build index if client allows. In a real app we would cache these vectors.
        self._build_index()
        self._initialized = True

    def _build_index(self):
        if not self.client:
            return
            
        print("Building SemanticKnowledgeBase index...")
        
        # 1. Embed Optometry Keys
        for condition, info in OPTOMETRY_DATA.items():
            # Embed a rich description so similarity is high for synonymous queries
            text_to_embed = f"Condition: {condition}. Effects: {info['answer']}"
            try:
                response = self.client.models.embed_content(
                    model=self.embedding_model,
                    contents=text_to_embed
                )
                self.optometry_embeddings[condition] = np.array(response.embeddings[0].values)
            except Exception as e:
                print(f"Error embedding optometry data '{condition}': {e}")
                
        # 2. Embed Medication Keys
        for med, info in MEDICATION_DATA.items():
            text_to_embed = f"Medication: {med}. Use: {info['common_use']}. Type: {info['type']}."
            try:
                response = self.client.models.embed_content(
                    model=self.embedding_model,
                    contents=text_to_embed
                )
                self.medication_embeddings[med] = np.array(response.embeddings[0].values)
            except Exception as e:
                print(f"Error embedding medication data '{med}': {e}")

    def semantic_search(self, query: str, domain: str, threshold: float = 0.55):
        """
        Embeds the query and returns the top matching item if above the confidence threshold.
        """
        if not self.client:
            return {"found": False, "error": "GenAI Client not initialized."}
            
        # Get query embedding
        try:
            response = self.client.models.embed_content(
                model=self.embedding_model,
                contents=query
            )
            query_vector = np.array(response.embeddings[0].values)
        except Exception as e:
            print(f"Error embedding search query: {e}")
            return {"found": False, "error": str(e)}

        # Choose domain
        if domain == "optometry":
            db = self.optometry_embeddings
            source_data = OPTOMETRY_DATA
        elif domain == "medication":
            db = self.medication_embeddings
            source_data = MEDICATION_DATA
        else:
            return {"found": False, "error": "Invalid domain."}

        # Find best match
        best_match = None
        best_score = -1.0

        for key, vector in db.items():
            score = cosine_similarity(query_vector, vector)
            if score > best_score:
                best_score = score
                best_match = key

        if best_match and best_score >= threshold:
            print(f"RAG Hit: '{query}' -> '{best_match}' (Score: {best_score:.2f})")
            return {
                "found": True,
                "key": best_match,
                "score": best_score,
                "data": source_data[best_match]
            }
        else:
            print(f"RAG Miss: '{query}' highest match was '{best_match}' (Score: {best_score:.2f})")
            return {"found": False}
