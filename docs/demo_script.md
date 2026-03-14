# GozAI — Demo Script
### Gemini Live Agent Challenge | 3 Minutes

> Practice until the words disappear and only the story remains.

---

## Before You Walk On Stage

| Item | Check |
|---|---|
| Physical device — haptics don't work on simulators | [ ] |
| Medication bottle within arm's reach | [ ] |
| Low obstacle ready for hazard demo | [ ] |
| Caregiver Dashboard live on a second screen | [ ] |
| Doctor Dashboard tabbed, pre-seeded data visible | [ ] |
| Cloud Run backend URL tested within last 10 minutes | [ ] |
| Phone on **your hotspot**, not conference WiFi | [ ] |
| **Fallback screen recording queued** — 60s of the app working perfectly | [ ] |

> Seed demo data before presenting: `python backend/seed_demo_data.py`

---

## The Script

### 0:00–0:20 — Don't introduce yourself. Introduce Maria.

> *[No slide. No "good morning." Camera already pointing at a medication bottle label.
> GozAI is live. The room doesn't know it yet.]*

**"Her name is Maria. She's 71 years old, she has macular degeneration, and she lives alone.**

**Every morning she faces the same label. The same fog. The same fear that today might be the day she gets it wrong."**

> *[GozAI speaks — reads the label aloud:
> "Metoprolol Succinate, 50 milligrams. Take one tablet daily with or without food. No allergens detected."]*

**"She didn't search for that. She didn't type it. She didn't ask.**

**GozAI watched. Understood. And spoke.**

**That is the paradigm we eliminated."**

> *FALLBACK if GozAI doesn't speak: Say "What does this label say?" aloud. It responds. Keep moving.*

---

### 0:20–0:55 — Three Moments That Cannot Be Faked

**MOMENT 1 — It Speaks Before She Falls (0:20–0:33)**

> *[Walk slowly toward a low object. Don't announce it. Just walk.]*
> *[GozAI, unprompted: "Step carefully — obstacle at ground level, about two feet ahead."]*
> *[Phone buzzes. Three short pulses.]*

**"No prompt. 1 frame per second, streamed directly to the Gemini Multimodal Live API. It saw the danger before she did. The haptic told her without words."**

> *FALLBACK if hazard isn't detected: Say "What's in front of me?" — Gemini describes it. Say: "In production, this runs proactively. It doesn't wait."*

---

**MOMENT 2 — She Can Interrupt (0:33–0:43)**

> *[Trigger a long response. Say "Stop—" mid-sentence. GozAI cuts off instantly.]*

**"True barge-in. No button. Gemini's bidirectional stream detects her voice and drops its own audio in real time. For a low-vision user, the ability to interrupt is a safety requirement — not a convenience."**

---

**MOMENT 3 — Her Caregiver Knows (0:43–0:55)**

> *[Say: "I'm lost. I need help."]*
> *[GozAI: "Alerting your caregiver now. Stay where you are — I'll keep watching."]*
> *[Switch to Caregiver Dashboard — the alert appears live on screen.]*

**"The ADK backend agent wrote that event to Firestore in under a second. Her daughter didn't need to be called. The alert was already on her screen."**

---

### 0:55–1:30 — Three Users. One System.

**"GozAI isn't built for one user. It's built for a relationship.**

The patient: voice-first, no text, no typing. Designed for 20/200 vision.
The caregiver: live alerts, real-time safety monitoring.
The doctor: clinical telemetry — reading stamina, navigation independence, SOS frequency. Data they can act on between appointments.

**No other solution in this space connects all three in real time."**

---

### 1:30–2:00 — Architecture: Google Tech, Not Google Branding

> *[One clean diagram — talk to it, don't read from it]*

**"Mobile connects directly to the Gemini Multimodal Live API — bidirectional WebSocket, real-time audio and video, simultaneously. No transcription delay. On the backend: a Google ADK agent on Cloud Run with four registered tools — optometry guidelines, medication lookups, live SOS to Firestore, clinical statistics from WHO and peer-reviewed journals.**

**The Firebase MCP toolset runs inside the ADK agent itself. Firebase isn't just our database — it's an agent-native data interface."**

---

### 2:00–2:30 — The Research

**"Every design decision maps to verified outcomes:**

AI assistive tools produce significantly higher ADL task completion rates — especially for text tasks like medication labels.
*(Seiple et al., Translational Vision Science & Technology, 2025)*

Haptic feedback improves navigation confidence and reduces cognitive load.
*(MDPI / JMIR Rehabilitation, 2024)*

2.2 billion people have vision impairment. 1 billion of those cases are preventable or unaddressed.
*(WHO World Report on Vision, 2019)*

Only 1 in 10 people who need assistive technology can access it.
*(WHO & UNICEF Global Report on Assistive Technology, 2022)*

**This is a clinical intervention that happens to run on a phone."**

---

### 2:30–2:50 — What It Would Take to Deploy

**"Cloud Run is live right now. The app is deployable today. What we'd need for production: ethics review, a pilot cohort, and a partnership — the AFB or the Lighthouse Guild. The architecture already handles it. We didn't build a prototype. We built the first version."**

---

### 2:50–3:00 — The Close

> *[Hold the phone. Let GozAI run. Don't fill the silence.]*

**"The judges asked for projects that feel alive.**

**Maria doesn't know what Gemini is. She doesn't know what an LLM is.**

**She just knows that every morning, something is watching over her.
Reading to her. Warning her. Telling her she's safe.**

**That's what we built."**

---

## If a Judge Asks...

| Question | Answer |
|---|---|
| "No text box?" | *"Maria has never typed a single character."* |
| "Context-aware how?" | *"1 frame per second. Persistent spatial history. It knows where she was three steps ago."* |
| "ADK usage?" | *"Cloud Run. Four registered tools. Firebase MCP running inside the agent. Full stack."* |
| "Hallucinations?" | *"Every tool returns a structured fallback. A DB outage returns the WHO baseline — she never gets silence."* |
| "Why would this win?" | *"No other submission connects patient, caregiver, and doctor live over a streaming AI session."* |

---

## Bonus Points Outstanding

| Action | Points |
|---|---|
| Publish Dev.to / Medium technical article | **+0.6** |
| `cloudbuild.yaml` in repo (✅ done) | **+0.2** |
| GDG membership linked in submission | **+0.2** |
