# 👁️ GozAI — Your Voice-First Emotional & Accessibility Copilot

![Flutter](https://img.shields.io/badge/Flutter-3.41-blue?logo=flutter)
![Gemini](https://img.shields.io/badge/Gemini_Live_API-2.0_flash_exp-green?logo=google)

> **"GozAI isn't just an app that looks at things — it's an empathetic, continuously aware copilot that restores independence and psychological safety."**

Low vision affects over **2.2 billion people globally**. Standard screen readers fail when faced with unlabelled digital UIs, and traditional AI tools require you to manually snap photos like a robot, causing cognitive fatigue. The psychological toll—loneliness, frustration, and anxiety—is massive, yet entirely ignored by modern tech.

**GozAI fixes this.** We engineered a real-time, voice-first companion using the **Gemini Multimodal Live API**. Goz acts as your eyes, your hands on digital screens, and a supportive talk-partner when you need one.

---

## 🛠️ Real-world Solutions to Daily Problems (ADLs)

GozAI is built strictly around the five core Activities of Daily Living (ADLs) that dictate a low-vision patient's independence. It is designed to be your constant, hands-free companion.

### 1. The Challenge: "I'm lonely or frustrated about my vision loss."
**The GozAI Solution:** Goz is an empathetic talk partner. 
* **How it works:** Just say "Hey Siri, open Goz." The microphone opens instantly. If you need to vent, talk through frustration, or just chat, Goz is clinically prompted to be a warm, reassuring conversationalist—not just a utility tool. 

### 2. The Challenge: "I can't read the permission pop-up on my screen to use an app."
**The GozAI Solution:** The Universal UI Navigator.
* **How it works (Dual-Mode):** When you encounter an unlabelled button or OS pop-up, you don't need to try and touch it. 
    * **Efficiency Mode:** Just say, "Goz, click 'Allow'." Goz sees the screen, calculates the coordinates, and injects a synthetic tap *for* you.
    * **Companion Mode:** Say, "Goz, help me find the 'Next' button." Goz uses haptic sonar and warm audio cues ("A little down... stop, right there") to guide your finger to the exact pixel.

### 3. The Challenge: "I don't know if these stairs drop off sharply."
**The GozAI Solution:** Continuous Environmental Scanning with Semantic Haptics.
* **How it works:** Goz runs continuously in your pocket or on your lanyard, capturing frames at battery-optimized 1FPS. It prioritizes *immediate physical hazards* above everything else. Instead of shouting descriptions at you, it uses specific haptic pulses to warn of drop-offs or vehicles, keeping your audio space clear.

### 4. The Challenge: "I can't read this restaurant menu or medicine bottle."
**The GozAI Solution:** Offline & Cloud Reading Modes.
* **How it works:** Point your phone and ask Goz to read. For sensitive medical data or when you have no cell service, Goz falls back to on-device Google ML Kit OCR. For complex layouts like a busy restaurant menu, Gemini parses the entire visual hierarchy and reads it to you at a natural pace.

---

## 👨‍⚕️ Clinical Research Foundation (2025-2026)

Every feature in GozAI addresses a documented challenge—not a hypothetical use case. The system's behavior and constraints are grounded in peer-reviewed research and global health reports:

*   **Seiple W. et al. 2025 (TVST, PMC11721483)** — AI ADL performance for Peripheral Vision Loss.
*   **WHO World Report on Vision 2019** — Global prevalence (2.2B affected).
*   **WHO & UNICEF Global Report on Assistive Technology 2022** — 90% access gap for assistive tech.
*   **Imperial College 2024 (Nature Sci Rep)** — Intuitive directional haptics for navigation.
*   **NYU Tandon 2024 (JMIR Rehab)** — Synchronized vibro-acoustic feedback efficacy.
*   **Wittich W. et al. 2021 (JMIR Res Protoc)** — Cognitive load management in AMD rehabilitation.
*   **Ventura R.B. et al. Jan 2026 (Frontiers Digital Health)** — Factors in Assistive Tech adoption and abandonment.
*   **NaviGPT, ACM GROUP Jan 2025** — LLM multimodal navigation for People with Visual Impairment.
*   **Samavati & Abadi, Cureus Oct 2025** — 80-study systematic review of VI assistive technologies.

| Research Finding | The GozAI Implementation |
|---|---|
| Glaucoma/Vision Impairment carries a **2.486x higher suicide risk** due to the psychological toll. | **Clinical Empathy:** Goz is explicitly programmed as an anchor of psychological safety—calm, empathetic, and reassuring; prioritizing human connection. |
| Assistive Tech abandonment is caused by high cognitive load and tedious UI interactions. | **Zero-UI Activation & Barge-in:** Starts instantly via voice assistant. The mic is always hot; you can interrupt Goz by simply speaking over it. |
| Directional haptic feedback is more intuitive and less fatiguing for navigation than audio alone. | **Semantic Vibro-Acoustics:** Feedback is triggered only on state changes/threats to prevent sensory saturation. |

---

## 🏗️ Technical Architecture (PWA & Beyond)

GozAI is currently optimized as a Progressive Web App (PWA) to ensure maximum accessibility across any device immediately, without waiting for App Store approvals.

*   **Frontend:** Flutter Web (Brutalist-accessible, high-contrast UI).
*   **Cognitive Engine:** Gemini 2.0 Flash Multimodal (WebSockets).
*   **Execution Bridge:** In-App Synthetic Gestures (Flutter `GestureBinding`) and `getDisplayMedia` for screen capture.
*   **The Future (Native):** See `docs/NATIVE_ARCHITECTURE_BLUEPRINT.md` for our post-hackathon roadmap detailing how GozAI scales to Android `AccessibilityService` (for OS-wide Ghost Touch) and Smart Glasses (Bluetooth HID).

---

## 🚀 Quick Start (For Developers)

### Prerequisites
- Flutter SDK 3.41+
- Gemini API key from [Google AI Studio](https://aistudio.google.com/apikey)

### Setup
```bash
# Clone the repository
git clone https://github.com/Kryptopacy/GozAI.git
cd GozAI
cp .env.example .env

# Install dependencies and run
flutter pub get
flutter run -d chrome
```

## 🛡️ Trust & Safety
GozAI respects the vulnerability of its users. **Zero images are stored.** Processed frames are immediately discarded.

*Built for the Gemini Live Agent Challenge | Tracks: Live Agents + UI Navigator*
