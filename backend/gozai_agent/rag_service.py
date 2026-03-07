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
    "macular degeneration": {
        "answer": "Macular degeneration affects central vision, making it hard to read or recognize faces. Navigation can be challenging due to loss of detail. Peripheral vision remains intact. Use strong task lighting and magnification.",
        "source": "National Eye Institute (NEI)",
        "action": "Schedule regular exams to monitor progression."
    },
    "diabetic retinopathy": {
        "answer": "Diabetic retinopathy causes patchy vision loss and floaters due to blood vessel damage. Strict blood sugar control is crucial.",
        "source": "American Academy of Ophthalmology",
        "action": "Consult your endocrinologist and ophthalmologist regularly."
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
    "brimonidine": {
        "type": "Eye drops (alpha agonist)",
        "common_use": "Glaucoma — reduces eye pressure",
        "general_info": "Usually applied three times daily. Wait 15 minutes before inserting contact lenses.",
        "safety": "May cause fatigue or dry mouth. Caution with certain antidepressants.",
    },
    "ranibizumab": {
        "type": "Anti-VEGF injection",
        "common_use": "Wet macular degeneration or diabetic retinopathy",
        "general_info": "Administered via injection by an ophthalmologist. Typically requires monthly visits.",
        "safety": "Report any sudden vision loss, severe eye pain, or signs of infection immediately.",
    },
}

LOW_VISION_STATS = {
    "global prevalence": {
        "statistic": "Over 2.2 billion people globally have a near or distance vision impairment.",
        "context": "In at least 1 billion of these cases, vision impairment could have been prevented or has yet to be addressed.",
        "source": "World Health Organization (WHO)"
    },
    "assistive technology gap": {
        "statistic": "Only 10% of people who need assistive technology have access to it.",
        "context": "This 90% gap highlights the need for low-cost, smartphone-based solutions like GozAI.",
        "source": "WHO and UNICEF Global Report on Assistive Technology"
    },
    "cognitive mapping AI": {
        "statistic": "People with vision impairment show significantly higher task completion rates for reading and object identification tasks when using AI assistive tools.",
        "context": "A 2025 study evaluated 25 individuals with vision loss across 14 ADL tasks using AI tools (OrCam, Envision Glasses, Seeing AI, Google Lookout). Text-based tasks showed the most consistent improvement. High user satisfaction was reported across all tools.",
        "source": "Seiple W. et al., Translational Vision Science & Technology, 14(1):3, 2025. DOI: 10.1167/tvst.14.1.3. PMC11721483."
    }
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
        self.stats_embeddings = {}
        
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
                
        # 3. Embed Stats Keys
        for stat, info in LOW_VISION_STATS.items():
            text_to_embed = f"Low Vision Statistic about {stat}: {info['statistic']} {info['context']}"
            try:
                response = self.client.models.embed_content(
                    model=self.embedding_model,
                    contents=text_to_embed
                )
                self.stats_embeddings[stat] = np.array(response.embeddings[0].values)
            except Exception as e:
                print(f"Error embedding stats data '{stat}': {e}")

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
        elif domain == "statistics":
            db = self.stats_embeddings
            source_data = LOW_VISION_STATS
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
