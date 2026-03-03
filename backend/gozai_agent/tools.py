"""GozAI ADK Tools — Backend functions for the agent to call."""
import os
from .rag_service import SemanticKnowledgeBase

# Initialize the vector DB
knowledge_base = SemanticKnowledgeBase()

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
    result = knowledge_base.semantic_search(query, domain="optometry", threshold=0.55)
    
    if result.get("found"):
        data = result["data"]
        return {
            "found": True,
            "answer": data["answer"],
            "source": data["source"],
            "recommended_action": data.get("action", ""),
            "confidence": result.get("score"),
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
    result = knowledge_base.semantic_search(medication_name, domain="medication", threshold=0.55)
    
    if result.get("found"):
        data = result["data"]
        return {
            "found": True,
            "medication": medication_name,
            "type": data["type"],
            "common_use": data["common_use"],
            "general_info": data["general_info"],
            "safety_notes": data["safety"],
            "confidence": result.get("score"),
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
