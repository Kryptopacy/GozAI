import os
import numpy as np  # type: ignore
import google.genai as genai  # type: ignore

# Try to initialize Firebase for dynamic RAG fetching from Cloud Firestore
try:
    import firebase_admin  # type: ignore
    from firebase_admin import credentials, firestore as fb_firestore  # type: ignore

    if not firebase_admin._apps:
        # On Cloud Run: uses Application Default Credentials automatically.
        firebase_admin.initialize_app()

    fir_db = fb_firestore.client()
    FIREBASE_AVAILABLE = True
except Exception as _firebase_init_err:
    fir_db = None
    FIREBASE_AVAILABLE = False

# Comprehensive datasets generated from clinical guidelines (AAO, AOA, WHO) and peer-reviewed literature
OPTOMETRY_DATA = {
    "light sensitivity": {
        "answer": (
            "Light sensitivity (photophobia) is common with many eye conditions "
            "including glaucoma, macular degeneration, cataracts, and uveitis. "
            "Recommendations: Use polarized sunglasses with 100% UV protection outdoors. "
            "FL-41 or amber-tinted lenses can significantly reduce fluorescent glare. "
            "Adjust screen brightness and use dark or high-contrast modes on digital devices."
        ),
        "source": "American Academy of Ophthalmology",
        "action": "Schedule an appointment with your eye care professional if sensitivity worsens or is accompanied by pain.",
    },
    "eye pain": {
        "answer": (
            "Eye pain can range from mild surface irritation to a sign of serious intraocular conditions. "
            "Surface causes include dry eyes, eye strain, foreign bodies, or conjunctivitis. "
            "URGENT signs requiring immediate care: sudden severe pain, "
            "vision changes, pain with redness and nausea (possible acute angle-closure glaucoma), or halo vision."
        ),
        "source": "American Optometric Association",
        "action": "If pain is severe, sudden, or accompanied by vision loss or nausea, seek immediate emergency eye care.",
    },
    "dry eyes": {
        "answer": (
            "Dry eye disease (keratoconjunctivitis sicca) is highly prevalent, especially with prolonged screen use. "
            "Tips: Follow the 20-20-20 rule (every 20 minutes, look 20 feet away for 20 seconds). "
            "Use preservative-free artificial tears (e.g., celluvisc, hyaluronate) 4-6 times daily. "
            "Use warm compresses for 5-10 minutes twice daily to improve meibomian gland function. Stay hydrated."
        ),
        "source": "American Academy of Ophthalmology Preferred Practice Pattern",
        "action": "Consult your optometrist if symptoms persist; you may need punctal plugs or prescription drops like Cyclosporine.",
    },
    "floaters": {
        "answer": (
            "Floaters are small spots, cobwebs, or lines in your vision caused by vitreous syneresis (age-related changes). "
            "They are usually benign. However, a sudden shower of new floaters, "
            "especially when accompanied by flashes of light (photopsia) or a dark shadow/curtain over your peripheral vision, "
            "strongly indicates a retinal tear or detachment."
        ),
        "source": "National Eye Institute (NEI)",
        "action": "See your eye doctor URGENTLY (within 24 hours) if you notice a sudden increase in floaters or flashes.",
    },
    "macular degeneration": {
        "answer": (
            "Age-related Macular Degeneration (AMD) affects the macula, degrading central high-resolution vision. "
            "It makes reading, recognizing faces, and driving difficult, while peripheral vision usually remains intact. "
            "Dry AMD is managed with AREDS2 vitamins to slow progression. Wet AMD is treated with anti-VEGF injections. "
            "Use strong task lighting, magnification devices, and high-contrast settings to maximize remaining vision."
        ),
        "source": "National Eye Institute (NEI) & AREDS2 Guidelines",
        "action": "Use an Amsler grid daily to check for central vision distortion. Schedule regular dilated exams."
    },
    "diabetic retinopathy": {
        "answer": (
            "Diabetic retinopathy is a microvascular complication of diabetes causing patchy vision loss, floaters, and blindness. "
            "It occurs when high blood glucose damages retinal blood vessels, leading to leakage or abnormal vessel growth. "
            "Strict glycemic (HbA1c) and blood pressure control are the most critical preventative measures. "
            "Treatments include laser photocoagulation and anti-VEGF therapy."
        ),
        "source": "American Academy of Ophthalmology",
        "action": "Consult your endocrinologist and ensure you receive an annual comprehensive dilated eye exam."
    },
    "glaucoma": {
         "answer": (
            "Glaucoma is a group of optic neuropathies usually associated with elevated intraocular pressure (IOP). "
            "It typically causes asymptomatic, progressive loss of peripheral vision (tunnel vision) before affecting central vision. "
            "It is the leading cause of irreversible blindness globally. Treatment involves daily IOP-lowering eye drops, laser trabeculoplasty, or surgery."
         ),
         "source": "World Glaucoma Association",
         "action": "Adhere strictly to your prescribed eye drop regimen and attend regular visual field testing."
    },
    "cataracts": {
         "answer": (
            "A cataract is the clouding of the eye's naturally clear lens, leading to blurred, dim, or yellowed vision, and severe glare from lights. "
            "It is highly treatable through routine outpatient surgery where the cloudy lens is replaced with a clear artificial intraocular lens (IOL). "
            "Early stages can be managed with updated eyeglasses and brighter lighting."
         ),
         "source": "American Academy of Ophthalmology",
         "action": "Discuss surgical options with your ophthalmologist when cataracts begin interfering with your daily activities."
    },
    "retinitis pigmentosa": {
         "answer": (
            "Retinitis Pigmentosa (RP) is a group of rare, genetic disorders that involve a breakdown and loss of cells in the retina. "
            "Common early symptoms include difficulty seeing at night (nyctalopia) and a loss of side (peripheral) vision. "
            "Currently, there is no standardized cure, though gene therapies (like Luxturna for RPE65 mutations) are emerging."
         ),
         "source": "Foundation Fighting Blindness",
         "action": "Consider genetic testing to identify your specific mutation, and utilize orientation and mobility (O&M) training."
    },
    "optic neuritis": {
         "answer": (
            "Optic neuritis is inflammation of the optic nerve, causing rapid central vision loss, reduced color vision, and eye pain that worsens with movement. "
            "It is often associated with demyelinating conditions like Multiple Sclerosis (MS). "
            "It may be treated with high-dose intravenous corticosteroids to accelerate recovery."
         ),
         "source": "American Academy of Neurology",
         "action": "Seek immediate evaluation; a brain MRI and neurological consultation are often required."
    }
}

MEDICATION_DATA = {
    "timolol": {
        "type": "Eye drops (beta-blocker)",
        "common_use": "Glaucoma — reduces intraocular pressure by decreasing aqueous humor production.",
        "general_info": "Usually applied once or twice daily. Store at room temperature.",
        "safety": "Contraindicated in patients with asthma, severe COPD, bradycardia, or heart block. Can cause bronchospasm and fatigue.",
    },
    "latanoprost": {
        "type": "Eye drops (prostaglandin analog)",
        "common_use": "Glaucoma — reduces intraocular pressure by increasing uveoscleral outflow.",
        "general_info": "Applied once daily in the evening. Highly effective first-line treatment.",
        "safety": "May cause lengthening/thickening of eyelashes, orbital fat loss, hyperemia (redness), and permanent darkening of light-colored irises.",
    },
    "prednisolone": {
        "type": "Eye drops (corticosteroid)",
        "common_use": "Severe eye inflammation (uveitis, post-surgical).",
        "general_info": "Suspension formulation requires vigorous shaking before use. Dosage is tapered off, not stopped abruptly.",
        "safety": "Prolonged use (>2 weeks) can cause steroid-induced glaucoma (elevated IOP), accelerate cataract formation, and increase infection risk.",
    },
    "brimonidine": {
        "type": "Eye drops (alpha-2 adrenergic agonist)",
        "common_use": "Glaucoma — reduces aqueous production and increases uveoscleral outflow.",
        "general_info": "Usually applied two to three times daily. Wait 15 minutes before inserting contact lenses.",
        "safety": "May cause allergic conjunctivitis, fatigue, dry mouth, and drowsiness. Contraindicated with MAO inhibitors.",
    },
    "ranibizumab": {
        "type": "Anti-VEGF intravitreal injection (Lucentis)",
        "common_use": "Wet macular degeneration, diabetic macular edema, or retinal vein occlusion.",
        "general_info": "Administered via injection inside the eye by a retina specialist. Typically requires monthly or bi-monthly regimens.",
        "safety": "Risk of endophthalmitis (severe internal infection) or retinal detachment. Report sudden pain, extreme redness, or vision drop immediately.",
    },
    "aflibercept": {
        "type": "Anti-VEGF intravitreal injection (Eylea)",
        "common_use": "Wet macular degeneration, diabetic macular edema.",
        "general_info": "Binds to VEGF to prevent abnormal blood vessel growth and leakage. Often allows for longer intervals between injections compared to older drugs.",
        "safety": "Same risks as other injections: extremely low but severe risk of infection or detachment. Transient IOP spikes post-injection may occur.",
    },
    "dorzolamide": {
        "type": "Eye drops (carbonic anhydrase inhibitor)",
        "common_use": "Glaucoma — reduces aqueous humor production.",
        "general_info": "Given two or three times daily. Often combined with Timolol (Cosopt).",
        "safety": "Can cause a bitter, metallic taste in the mouth and local stinging upon instillation. Caution in patients with severe sulfa allergies.",
    },
    "cyclosporine": {
        "type": "Eye drops (calcineurin inhibitor immunosuppressant) (Restasis)",
        "common_use": "Chronic dry eye disease.",
        "general_info": "Used twice daily to increase natural tear production by reducing lacrimal gland inflammation. Takes weeks to months to reach full effect.",
        "safety": "Frequently causes temporary burning or stinging when applied. Safe for long-term use.",
    },
    "atropine": {
        "type": "Eye drops (anticholinergic/cycloplegic)",
        "common_use": "Severe uveitis, amblyopia penalization, or myopia control in children (very low dose).",
        "general_info": "Dilates the pupil and paralyzes the focusing muscle for a prolonged period (up to 1-2 weeks in 1% formulations).",
        "safety": "Causes extreme light sensitivity and inability to focus on near objects while active. Can cause systemic flushing or tachycardia in small children.",
    }
}

LOW_VISION_STATS = {
    "global prevalence": {
        "statistic": "Globally, at least 2.2 billion people have a near or distance vision impairment.",
        "context": "In at least 1 billion – or almost half – of these cases, vision impairment could have been prevented or has yet to be addressed.",
        "source": "World Health Organization (WHO) World Report on Vision, 2019"
    },
    "assistive technology gap": {
        "statistic": "Only 10% of people who need assistive technology have access to it.",
        "context": "This 90% gap disproportionately affects low- and middle-income regions, highlighting the urgent need for scalable, smartphone-based AI solutions like GozAI.",
        "source": "WHO and UNICEF Global Report on Assistive Technology, 2022"
    },
    "cognitive mapping AI": {
        "statistic": "People with vision impairment show significantly higher task completion rates for reading and object identification tasks when using AI assistive tools.",
        "context": "A 2025 study evaluated 25 individuals with vision loss across 14 ADL tasks using AI tools. Text-based tasks showed the most consistent improvement. High user satisfaction was reported across all tools, though spatial navigation remains a frontier.",
        "source": "Seiple W. et al., Translational Vision Science & Technology, 14(1):3, 2025. DOI: 10.1167/tvst.14.1.3."
    },
    "cognitive load fatigue": {
        "statistic": "High cognitive load from navigation and reading causes significant exhaustion for individuals with AMD and profound low vision.",
        "context": "Rehabilitation protocols increasingly recognize that reducing cognitive overhead—not just magnifying text—prevents cognitive decline and fatigue-induced visual phenomena (like Charles Bonnet hallucinations).",
        "source": "Wittich W. et al., JMIR Res Protoc, 2021. DOI: 10.2196/19931."
    },
    "synchronized vibro-acoustic feedback": {
        "statistic": "Combining vibrational feedback with escalating sound reduces obstacle collisions by up to 40% more effectively than either auditory or haptic mode alone.",
        "context": "A 2024 study tested a 10-motor wearable belt integrated with auditory beeps, finding that synced multisensory spatial cues drastically improved navigation safety and spatial rendering for the blind.",
        "source": "Ricci F.S. et al., JMIR Rehabilitation and Assistive Technology, Dec 2024. DOI: 10.2196/55776."
    },
    "intuitive directional haptics": {
        "statistic": "Shape-changing and state-based haptic interfaces are processed significantly faster and elicit less fatigue than continuous vibration alerts.",
        "context": "Research on 'Shape' morphing haptics showed that visually impaired users navigate as effectively as sighted people when haptic cues are intuitive (like a physical pull) rather than fatiguing auditory 'buzzes'.",
        "source": "Spiers A.J. et al., Nature Scientific Reports, Dec 2024. DOI: 10.1038/s41598-024-79845-7."
    },
    "assistive tech adoption": {
        "statistic": "Assistive technology abandonment occurs in roughly 30% of prescribed devices within the first year.",
        "context": "Abandonment is primarily driven by poor user-centered design, social stigma, and high cognitive friction. Participatory design and unifying ecosystems are critical for sustained adoption.",
        "source": "Ventura R.B., Hamilton-Fletcher G., Rizzo J-R., Frontiers in Digital Health, Jan 2026. DOI: 10.3389/fdgth.2025.1719746."
    },
    "economic impact of vision loss": {
        "statistic": "The annual global economic cost of productivity losses associated with vision impairment from uncorrected myopia and presbyopia alone is estimated at US$ 244 billion and US$ 25.4 billion, respectively.",
        "context": "Providing accessible refractive care and advanced assistive AI has a multi-trillion dollar ROI in restored global workforce productivity and reduced caregiver burden.",
        "source": "World Health Organization, 2020 Fact Sheets."
    },
    "falls and low vision": {
        "statistic": "Older adults with severe vision impairment are at least twice as likely to suffer from debilitating falls compared to matched sighted peers.",
        "context": "Fall prevention is the primary focus of Orientation & Mobility training. Visual field loss (as seen in glaucoma) correlates higher with fall risk than central acuity loss (as in AMD).",
        "source": "American Geriatrics Society, Falls Prevention Guidelines."
    },
    "mental health glaucoma mortality": {
        "statistic": "Glaucoma combined with severe vision impairment results in a 2.486x higher hazard ratio for suicide compared to healthy controls.",
        "context": "Vision loss carries a heavy psychological and systemic health toll. This underscores the necessity for medical AI assistants to utilize calm, reassuring, and empathetically grounded personas to mitigate depression and isolation.",
        "source": "Nature Scientific Reports, 2025. DOI: 10.1038/s41598-025-24123-3."
    },
    "amd low luminance contrast": {
        "statistic": "Intermediate Age-related Macular Degeneration (AMD) significantly impairs vision under low-luminance (dim) conditions, profoundly impacting quality of life before high-contrast acuity drops.",
        "context": "Patient independence drops sharply in dim environments. This validates the crucial need for AI computer vision apps to act as 'night vision' or active describers in poorly lit settings.",
        "source": "Nature Scientific Reports, 2025. DOI: 10.1038/s41598-025-21210-3."
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
            api_key = os.environ.get("GEMINI_API_KEY")
            if not api_key:
                print("CRITICAL: GEMINI_API_KEY environment variable is missing!")
                self.client = None
            else:
                self.client = genai.Client(api_key=api_key)
        except Exception as e:
            print(f"Warning: Failed to initialize genai Client: {e}")
            self.client = None
            
        self.embedding_model = "text-embedding-004"
        
        # Store dicts of {key: embedding}
        self.optometry_embeddings = {}
        self.medication_embeddings = {}
        self.stats_embeddings = {}
        
        # Store active data sources
        self.optometry_data = OPTOMETRY_DATA.copy()
        self.medication_data = MEDICATION_DATA.copy()
        self.stats_data = LOW_VISION_STATS.copy()
        
        # Build index if client allows. In a real app we would cache these vectors.
        self._build_index()
        self._initialized = True

    def _fetch_from_firestore(self):
        """Fetches dynamic RAG documents from Firestore (Cloud Architecture proof)."""
        if FIREBASE_AVAILABLE and fir_db is not None:
            try:
                # Fetch live RAG documents from Firestore
                docs = fir_db.collection("gozai_rag_data").stream()
                loaded_count = 0
                for doc in docs:
                    data = doc.to_dict()
                    domain = data.get("domain")
                    key = data.get("key")
                    payload = data.get("data")
                    if domain == "optometry" and key and payload:
                        self.optometry_data[key] = payload
                        loaded_count += 1
                    elif domain == "medication" and key and payload:
                        self.medication_data[key] = payload
                        loaded_count += 1
                    elif domain == "statistics" and key and payload:
                        self.stats_data[key] = payload
                        loaded_count += 1
                if loaded_count > 0:
                    print(f"Successfully loaded {loaded_count} dynamic RAG documents from Firestore.")
            except Exception as e:
                print(f"Failed to load dynamic RAG from Firestore, falling back to local clinical cache. Error: {e}")

    def _build_index(self):
        if not self.client:
            return
            
        assert self.client is not None
            
        print("Building SemanticKnowledgeBase index...")
        
        # Overwrite with any live data from Firestore before embedding
        self._fetch_from_firestore()
        
        # 1. Embed Optometry Keys
        for condition, info in self.optometry_data.items():
            # Embed a rich description so similarity is high for synonymous queries
            text_to_embed = f"Condition: {condition}. Effects: {info['answer']}"
            try:
                response = self.client.models.embed_content(  # type: ignore
                    model=self.embedding_model,
                    contents=text_to_embed
                )
                self.optometry_embeddings[condition] = np.array(response.embeddings[0].values)
            except Exception as e:
                print(f"Error embedding optometry data '{condition}': {e}")
                
        # 2. Embed Medication Keys
        for med, info in self.medication_data.items():
            text_to_embed = f"Medication: {med}. Use: {info['common_use']}. Type: {info['type']}."
            try:
                response = self.client.models.embed_content(  # type: ignore
                    model=self.embedding_model,
                    contents=text_to_embed
                )
                self.medication_embeddings[med] = np.array(response.embeddings[0].values)
            except Exception as e:
                print(f"Error embedding medication data '{med}': {e}")
                
        # 3. Embed Stats Keys
        for stat, info in self.stats_data.items():
            text_to_embed = f"Low Vision Statistic about {stat}: {info['statistic']} {info['context']}"
            try:
                response = self.client.models.embed_content(  # type: ignore
                    model=self.embedding_model,
                    contents=text_to_embed
                )
                self.stats_embeddings[stat] = np.array(response.embeddings[0].values)
            except Exception as e:
                print(f"Error embedding stats data '{stat}': {e}")

    def semantic_search(self, query: str, domain: str, threshold: float = 0.65):
        """
        Embeds the query and returns the top matching item if above the confidence threshold.
        If it's a 'near miss' (0.55-0.65), it returns a low-confidence flag.
        """
        if not self.client:
            return {"found": False, "error": "GenAI Client not initialized."}
            
        assert self.client is not None
            
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
            source_data = self.optometry_data
        elif domain == "medication":
            db = self.medication_embeddings
            source_data = self.medication_data
        elif domain == "statistics":
            db = self.stats_embeddings
            source_data = self.stats_data
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

        if best_match:
            if best_score >= threshold:
                print(f"RAG Hit: '{query}' -> '{best_match}' (Score: {best_score:.2f})")
                return {
                    "found": True,
                    "key": best_match,
                    "score": best_score,
                    "data": source_data[best_match]
                }
            elif best_score >= 0.55:
                # Near miss: we found something but it's not perfect.
                # Tell the agent to be cautious or ask for clarification.
                print(f"RAG Near-Miss: '{query}' -> '{best_match}' (Score: {best_score:.2f})")
                return {
                    "found": True,
                    "low_confidence": True,
                    "key": best_match,
                    "score": best_score,
                    "data": source_data[best_match]
                }

        print(f"RAG Miss: '{query}' highest match was '{best_match}' (Score: {best_score:.2f})")
        return {"found": False}
