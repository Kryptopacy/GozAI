"""GozAI ADK Tools — Backend functions for the agent to call."""


def search_optometry_guidelines(query: str) -> dict:
    """Search curated optometry guidelines for safe, verified medical information.
    
    This tool searches a curated database of optometric guidelines from 
    authoritative sources (AAO, AOA, WHO) to provide verified eye health 
    information. It never diagnoses or prescribes.
    
    Args:
        query: The user's eye health question.
    
    Returns:
        A dictionary with the answer and source reference.
    """
    # Curated knowledge base of common low-vision questions
    # In production, this would be a vector DB or RAG pipeline
    guidelines = {
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
    
    # Simple keyword matching (in production, use embeddings/RAG)
    query_lower = query.lower()
    for keyword, info in guidelines.items():
        if keyword in query_lower:
            return {
                "found": True,
                "answer": info["answer"],
                "source": info["source"],
                "recommended_action": info["action"],
                "disclaimer": "This is general information, not a diagnosis. Please consult your eye care professional.",
            }
    
    return {
        "found": False,
        "answer": (
            "I don't have specific guidelines on that topic in my database. "
            "For eye health questions, I recommend consulting your optometrist "
            "or ophthalmologist who can examine your eyes and provide personalized advice."
        ),
        "disclaimer": "Always consult a qualified eye care professional for medical concerns.",
    }


def send_sos_alert(
    message: str = "User needs assistance",
    include_location: bool = True,
) -> dict:
    """Send an SOS alert to the user's designated caregiver.
    
    Triggered when the user feels lost, disoriented, or needs help.
    Sends their current location and a message to their emergency contact.
    
    Args:
        message: Description of the situation.
        include_location: Whether to include GPS coordinates.
    
    Returns:
        Confirmation of alert delivery.
    """
    # In production: integrate with FCM (Firebase Cloud Messaging) 
    # to push notifications to caregiver's device
    return {
        "status": "sent",
        "message": f"SOS alert sent to caregiver: {message}",
        "location_included": include_location,
        "next_steps": (
            "Your caregiver has been notified. "
            "Stay where you are if it's safe. "
            "I'll keep monitoring your surroundings."
        ),
    }


def get_medication_info(medication_name: str) -> dict:
    """Look up safe, verified medication information.
    
    Provides basic medication details from a curated database.
    Never provides dosing recommendations — always defers to prescriber.
    
    Args:
        medication_name: The name of the medication to look up.
    
    Returns:
        Basic medication information and safety notes.
    """
    # Curated common medication database
    # In production, this would connect to a verified drug database API
    medications = {
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
    
    med_lower = medication_name.lower().strip()
    for name, info in medications.items():
        if name in med_lower or med_lower in name:
            return {
                "found": True,
                "medication": medication_name,
                "type": info["type"],
                "common_use": info["common_use"],
                "general_info": info["general_info"],
                "safety_notes": info["safety"],
                "disclaimer": (
                    "This is general information only. Always follow your doctor's "
                    "specific instructions for dosage and frequency."
                ),
            }
    
    return {
        "found": False,
        "medication": medication_name,
        "message": (
            f"I don't have {medication_name} in my database. "
            "Please check with your pharmacist or prescribing doctor "
            "for accurate medication information."
        ),
    }
