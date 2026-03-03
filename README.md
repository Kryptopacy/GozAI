# GozAI — AI Accessibility Copilot for Low-Vision Patients

![Flutter](https://img.shields.io/badge/Flutter-3.41-blue?logo=flutter)
![Gemini](https://img.shields.io/badge/Gemini_Live_API-2.0-green?logo=google)
![ADK](https://img.shields.io/badge/Google_ADK-Agent-orange)
![Cloud Run](https://img.shields.io/badge/Cloud_Run-Deployed-blue?logo=googlecloud)
![Firebase](https://img.shields.io/badge/Firebase-Configured-yellow?logo=firebase)

> *"GozAI isn't just an app that looks at things — it's a continuously aware, privacy-respecting copilot that restores independence."*

**GozAI** is a real-time voice + vision AI assistant built for people with low vision or blindness. It uses the **Gemini Multimodal Live API** for continuous, interruptible conversation with simultaneous camera and audio streaming — acting as the user's eyes in the real world and on their phone screen.

Built for the **Gemini Live Agent Challenge** | Tracks: **Live Agents** + **UI Navigator**

---

## 🎯 What Problem Does GozAI Solve?

Low vision affects over **2.2 billion people globally** (WHO). Existing assistive tech (VoiceOver, TalkBack) handles labeled UI elements but fails at:

| Gap | Example | GozAI Solution |
|-----|---------|----------------|
| **Medication safety** | Can't read pill bottles or distinguish similar pills | *"This is Timolol eye drops, 0.5%. Take twice daily. Expires June 2026."* |
| **Visual-only content** | CAPTCHAs, color-coded info, image-based UIs | Gemini vision reads what screen readers can't |
| **Hazard detection** | Wet floors, stairs, overhanging obstacles | Real-time 1 FPS scene analysis with haptic alerts |
| **Context loss from magnification** | Zooming in = losing page layout | Conversational querying: *"What's the third item on this menu?"* |
| **Cooking & grocery** | Can't assess food doneness or read nutrition labels | *"The chicken is golden brown, looks fully cooked"* |
| **Lighting orientation** | Walking from bright street into dim hallway | Offline light-meter with rising audio tone toward light |

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────┐
│           Flutter App (iOS / Android / Web)       │
│                                                   │
│  ┌──────────┐ ┌──────────┐ ┌──────────────────┐  │
│  │ Camera    │ │ Audio    │ │ Accessibility UI │  │
│  │ 1 FPS    │ │ 16kHz    │ │ High-Contrast    │  │
│  │ JPEG     │ │ PCM Mono │ │ Large Touch      │  │
│  └────┬─────┘ └────┬─────┘ └──────────────────┘  │
│       │             │                              │
│  ┌────▼─────────────▼─────┐  ┌────────────────┐  │
│  │  WebSocket (Gemini      │  │ Google ML Kit  │  │
│  │  Multimodal Live API)   │  │ (Offline OCR)  │  │
│  └────────────┬────────────┘  └────────────────┘  │
└───────────────┼────────────────────────────────────┘
                │
    ┌───────────▼───────────┐
    │  Gemini 2.0 Flash     │
    │  Multimodal Live      │
    │  (Voice + Vision)     │
    └───────────┬───────────┘
                │ Function Calls
    ┌───────────▼───────────┐
    │  ADK Backend          │
    │  (Cloud Run)          │
    │  ┌─────────────────┐  │
    │  │ Optometry RAG   │  │
    │  │ Caregiver SOS   │  │
    │  │ Medication Info  │  │
    │  └─────────────────┘  │
    └───────────────────────┘
```

---

## 🚀 Quick Start

### Prerequisites
- Flutter SDK 3.41+
- Gemini API key from [Google AI Studio](https://aistudio.google.com/apikey)
- Python 3.11+ with [uv](https://astral.sh/uv) (for backend)

### Setup

```bash
# Clone the repository
git clone https://github.com/Kryptopacy/GozAI.git
cd GozAI

# Configure environment
cp .env.example .env
# Edit .env and add your GEMINI_API_KEY

# Install Flutter dependencies
flutter pub get

# Run on device/simulator
flutter run

# --- Backend (optional) ---
cd backend
uv venv && uv pip install .
adk web  # Opens interactive agent UI at localhost:8000
```

### Cloud Deployment

```bash
# Automated deployment to Google Cloud Run
chmod +x deploy.sh
./deploy.sh gozai-app us-central1
```

---

## 📱 Features

### Mode 1: Scene (Live Agents Track)
Real-time environmental awareness via continuous camera streaming.
- Hazard detection within 10-foot radius
- Spatial audio descriptions: *"Door on your left, stairs ahead"*
- Haptic feedback patterns (triple buzz = hazard, double tap = person)
- Barge-in: interrupt GozAI mid-sentence

### Mode 2: Read
Conversational document reading powered by Gemini vision + offline ML Kit OCR.
- *"What's the dosage on this bottle?"* → reads and explains
- Currency identification
- Nutrition label structured reading

### Mode 3: Screen (UI Navigator Track)
AI-powered Digital Accessibility Bridge — where VoiceOver/TalkBack fail.
- Full semantic understanding of any screen
- Visual CAPTCHA solving
- Color-coded element interpretation
- Error message and form field identification

### Mode 4: Light
Offline ambient light orientation using phone sensors.
- Rising audio tone toward light sources
- Helps navigate dark/unfamiliar rooms
- Zero internet required

---

## 🛡️ Safety & Privacy

- **No images stored** — camera frames are processed in real-time and discarded
- **Never diagnoses** — always recommends consulting healthcare professionals
- **Curated medical info only** — optometry RAG uses verified AAO/AOA guidelines
- **On-device processing** — ML Kit OCR and light meter work fully offline

---

## 🔧 Tech Stack

| Layer | Technology |
|-------|-----------|
| **Frontend** | Flutter (Dart) — iOS, Android, Web |
| **AI Core** | Gemini 2.0 Flash Multimodal Live API (WebSocket) |
| **Backend** | Google ADK on Cloud Run |
| **Edge AI** | Google ML Kit (offline OCR) |
| **Database** | Firebase Firestore |
| **Auth** | Firebase Auth |
| **Deployment** | Automated via `deploy.sh` → Cloud Run |

---

## 📁 Project Structure

```
GozAI/
├── lib/
│   ├── core/
│   │   ├── app_config.dart       # Environment configuration
│   │   ├── system_prompt.dart    # Gemini persona & behavior
│   │   └── theme.dart            # Accessibility-first design system
│   ├── services/
│   │   ├── gemini_live_service.dart   # WebSocket ↔ Gemini Live API
│   │   ├── camera_service.dart        # Camera frame capture
│   │   ├── audio_service.dart         # Mic + speaker (PCM)
│   │   └── haptic_service.dart        # Vibration patterns
│   ├── screens/
│   │   └── home_screen.dart      # Main accessibility interface
│   └── main.dart                 # App entry point
├── backend/
│   ├── gozai_agent/
│   │   ├── agent.py              # ADK agent definition
│   │   └── tools.py              # RAG, SOS, medication tools
│   ├── Dockerfile                # Cloud Run container
│   └── pyproject.toml            # Python dependencies (uv)
├── deploy.sh                     # Automated Cloud Run deployment
├── pubspec.yaml                  # Flutter dependencies
└── .env.example                  # Environment template
```

---

## 👨‍⚕️ Designed by an Optometrist

GozAI's features are grounded in clinical research on Activities of Daily Living (ADLs) for low-vision patients. Every feature addresses a specific, documented challenge — not hypothetical use cases.

**Research sources:** NIH, University of Washington, American Academy of Ophthalmology, American Optometric Association, National Eye Institute.

---

## 📜 License

MIT License. See [LICENSE](LICENSE) for details.
