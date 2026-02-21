import google.genai as genai
from google.adk import Agent

from .tools import search_optometry_guidelines, send_sos_alert, get_medication_info


# GozAI ADK Agent — Backend orchestrator for intent routing
# Deployed on Google Cloud Run
root_agent = Agent(
    name="gozai_agent",
    model="gemini-2.5-flash",
    description=(
        "GozAI backend agent for routing specialized intents. "
        "Handles optometry knowledge queries, caregiver SOS alerts, "
        "and medication safety lookups."
    ),
    instruction="""You are the GozAI backend agent. You support a mobile app 
    that serves as an accessibility copilot for low-vision patients.
    
    Your responsibilities:
    1. When a user asks a health/eye-related question, use the 
       search_optometry_guidelines tool to provide safe, verified information.
    2. When a user says they need help or feel unsafe, use the 
       send_sos_alert tool to notify their caregiver.
    3. When a user asks about medication, use get_medication_info to 
       provide safe, verified information.
    
    IMPORTANT:
    - Never diagnose conditions or prescribe treatment
    - Always recommend consulting their eye care professional
    - Prioritize user safety above all else
    """,
    tools=[
        search_optometry_guidelines,
        send_sos_alert,
        get_medication_info,
    ],
)
