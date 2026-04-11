# 🧠 AI Overlay Assistant (macOS) — Execution Plan

## 🎯 Goal
Build a native macOS AI assistant that:
- Captures screen content (selected region)
- Captures and transcribes audio
- Uses LLM APIs to generate answers
- Displays responses in a translucent floating overlay UI

---

## 🏗️ High-Level Architecture
[Screen Capture] → [Google Vision API]
[Audio Input]   → [Whisper STT]
↓
[LLM API Layer]
↓
[Overlay UI (macOS)]

---

## 🖥️ Platform Requirement

- Native macOS App (NOT web app)
- Tech Stack:
  - Swift + SwiftUI (UI + system integration)
  - Python (optional for Whisper service)
  - Node (optional for API orchestration)

---

## 📦 Core Modules

### 1. Screen Capture Module

**Tech:**
- ScreenCaptureKit (preferred)
- Fallback: CGDisplayStream

**Features:**
- Capture selected region only
- Triggered via global hotkey

---

### 2. Screen Understanding (Google Cloud Vision)

**API:**
- Google Cloud Vision API (OCR)

**Flow:**
1. Capture screenshot
2. Send to Vision API
3. Extract text + layout
4. Create "context summary" for LLM

---

**Setup Steps:**
1. Create Google Cloud project
2. Enable Vision API
3. Generate API key / service account
4. Store credentials securely

---

### 3. Audio Input + Transcription

**Capture:**
- AVAudioEngine (macOS native)

**Transcription:**
- Whisper (local or API)

**Flow:**
1. Capture audio stream
2. Stream to Whisper API
3. Get real-time transcription
4. Send to LLM as context

---

### 4. LLM Processing Layer

**Supported APIs (user provides key):**
- OpenAI
- Claude (Anthropic)
- Gemini

**Input:**
- Screen text
- Audio transcript
- Context memory

**Prompt Template:**
```
You are an AI assistant overlay for macOS.

CONTEXT:
- Screen content: [extracted text]
- Audio transcript: [audio transcript]
- Conversation history: [memory]

USER QUESTION: [user input]

INSTRUCTIONS:
1. Answer based ONLY on screen content + audio
2. Keep answers concise (2-3 sentences)
3. If answer not in screen, say: "I cannot see that in the current screen content."
4. Maintain helpful, neutral tone

OUTPUT FORMAT:
- Answer: [response]
```

---

### 5. Overlay UI

**Tech:**
- SwiftUI + NSWindow

**Window Properties:**
- Transparent
- Always on top
- Non-focus stealing

**Design:**
- Minimal UI
- Translucent background (blur)
- Streaming text display

---

## ⚙️ Feature Implementation

### 1. Hotkey Trigger

**Goal:**
Run assistant only when needed

**Implementation:**
- Global hotkey (e.g. Cmd + Shift + Space)
- Use NSEvent global monitor

---

### 2. Region Selection

**Goal:**
Capture only relevant part of screen

**Implementation:**
- Click and drag selection overlay
- Store bounding box coordinates
- Pass region to capture module

---

### 3. Streaming Responses

**Goal:**
Display output as it's generated

**Implementation:**
- Use streaming API responses
- Update UI incrementally

---

### 4. Context Memory

**Goal:**
Maintain recent conversation

**Implementation:**
- Store last 3–5 exchanges
- Append to prompt

**Structure:**
[
{ “user”: “…”, “assistant”: “…” }
]

---

### 5. Rate Limiting

**Goal:**
Prevent excessive API usage

**Implementation:**
- Cooldown between requests (2–3 sec)
- Debounce triggers
- Token limits per request

---

## 🔁 Execution Flow
[Hotkey Pressed]
↓
[Capture Screen Region]
↓
[Send to Vision API]
↓
[Capture Audio]
↓
[Transcribe via Whisper]
↓
[Send to LLM]
↓
[Stream Response]
↓
[Display in Overlay UI]

---

## 📁 Project Structure

ai-overlay-app/
│
├── mac-app/
│   ├── UI/
│   ├── OverlayWindow.swift
│   ├── HotkeyManager.swift
│   ├── ScreenCapture.swift
│
├── services/
│   ├── vision_service.py
│   ├── whisper_service.py
│   ├── llm_client.py
│
├── config/
│   ├── api_keys.env
│
├── docs/
│   └── plan.md
│
└── README.md

---

## 🔐 macOS Permissions Required

- Screen Recording
- Microphone Access
- Accessibility (for overlay + hotkeys)

---

## 🧪 Testing Strategy

- Test each module independently
- Mock API responses
- Validate latency
- Check UI responsiveness
- Test edge cases (no audio, empty screen, etc.)

---

## 🚧 Known Challenges

- OCR accuracy issues on complex UI
- Audio noise and mis-transcription
- API latency
- Window layering bugs
- macOS permission friction

---

## 🚀 Future Enhancements

- Replace OCR with Vision LLM
- Offline mode (local models)
- Voice output (TTS)
- Smarter summarization
- Multi-monitor support

---

## ⚠️ Ethical Use

This tool is intended as a productivity assistant.
Use responsibly and respect rules of environments where assistance tools may be restricted.

---

## ✅ Deliverables

- Functional macOS application
- Demo video
- Source code repository
- Documentation