# 🧠 AI Overlay Assistant (macOS) — Execution Plan v2.0

## 🎯 Goal
Build a native macOS AI assistant that:
- Captures screen content (selected region)
- Captures and transcribes audio
- Uses LLM APIs to generate answers
- Displays responses in a **translucent floating overlay UI**
- Remains **completely invisible during screen sharing / recording sessions**

---

## 🏗️ High-Level Architecture

```
[Screen Capture]      → [Google Vision API / Local Vision LLM]
[Audio Input]         → [Whisper STT]
[User Text Input]     →
         ↓
[Context Builder]
         ↓
[LLM API Layer]
         ↓
[Stream Parser]
         ↓
[Overlay UI (macOS)] ←→ [Stealth Layer (Screen Share Detection)]
```

---

## 🖥️ Platform Requirement

- Native macOS App (NOT web app)
- **Minimum macOS:** Ventura 13.0+ (required for ScreenCaptureKit + SCContentFilter)
- Tech Stack:
  - Swift + SwiftUI (UI + system integration)
  - Python (optional for Whisper service)
  - Node (optional for API orchestration)

---

## 📦 Core Modules

---

### 1. Screen Capture Module

**Tech:**
- `ScreenCaptureKit` (primary — macOS 12.3+)
- Fallback: `CGDisplayStream`

**Features:**
- Capture selected region only
- Triggered via global hotkey
- Automatically **excluded from its own capture stream** (prevents recursive capture)

---

### 2. 🕵️ Stealth / Screen-Share Invisibility Module *(NEW)*

This is the most critical new addition. The overlay window must be invisible to:
- Zoom, Google Meet, Teams, Webex (screen share)
- QuickTime screen recording
- macOS built-in screenshot tools (`Cmd+Shift+3/4/5`)
- Third-party capture tools (OBS, Loom, etc.)

#### Technique 1 — `NSWindow.sharingType` (Primary)
```swift
overlayWindow.sharingType = .none
// .none = window is EXCLUDED from all screen capture APIs
// This is the most reliable method on macOS 12+
```
> This is the **official Apple API** for this exact use case. Any window with `.sharingType = .none` is silently excluded from `ScreenCaptureKit`, `CGWindowListCreate`, and all sharing APIs.

#### Technique 2 — `CGWindowSharingType` (Legacy fallback)
```swift
// For older macOS compatibility
let windowRef = overlayWindow.windowRef
CGSSetWindowSharingState(CGSMainConnectionID(), windowRef, CGSWindowSharingType.none)
```

#### Technique 3 — Dynamic Visibility Toggle
```swift
// Monitor screen sharing state and hide/show based on active sharing session
func isScreenBeingShared() -> Bool {
    let windows = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID)
    // Detect if any known sharing app (Zoom, Teams, etc.) has an active capture session
}
```

#### Technique 4 — SCContentFilter Exclusion *(macOS 13+)*
```swift
// When using ScreenCaptureKit for our own capture,
// explicitly exclude the overlay window:
let filter = SCContentFilter(
    display: display,
    excludingWindows: [overlayWindowID]
)
```

#### Implementation Notes:
- `sharingType = .none` must be set **before** the window becomes key/visible
- Re-apply after `orderFront()` calls — macOS may reset it
- Test against: Zoom, QuickTime, `screencapture` CLI, and macOS screenshot shortcut
- The window will still be **visible to the user** on their physical display — only excluded from capture streams

#### Stealth Status Indicator:
- Show a small lock icon (🔒) in the overlay corner indicating stealth is active
- Log stealth state changes to console for debugging

---

### 3. Screen Understanding

**Primary:** Google Cloud Vision API (OCR)
**Fallback/Enhancement:** GPT-4o Vision or Claude 3 Vision (for complex UI understanding)

**Flow:**
1. Capture screenshot of selected region
2. Send to Vision API
3. Extract text + layout information
4. Build "context summary" string for LLM

**Setup Steps:**
1. Create Google Cloud project
2. Enable Vision API
3. Generate service account key
4. Store credentials in macOS Keychain (not `.env` file)

---

### 4. Audio Input + Transcription

**Capture:** `AVAudioEngine` (macOS native)

**Transcription Options:**
- Whisper API (OpenAI) — cloud, accurate
- `whisper.cpp` — local, private, no latency cost
- Apple `SFSpeechRecognizer` — fastest, offline capable

**Flow:**
1. Capture audio stream via `AVAudioEngine`
2. Chunk audio and stream to Whisper
3. Get real-time transcription
4. Feed into LLM context

**Privacy Note:** Prefer `whisper.cpp` for local transcription to avoid sending audio to external services.

---

### 5. LLM Processing Layer

**Supported APIs (user provides key):**
- OpenAI (GPT-4o, GPT-4 Turbo)
- Claude (Anthropic) — claude-sonnet-4-20250514
- Gemini (Google)

**Input Sources:**
- Screen OCR text
- Audio transcript
- User typed input
- Conversation memory (last 5 exchanges)

**Improved Prompt Template:**
```
You are a discreet AI assistant overlay running on macOS.

CONTEXT:
- Screen content: [extracted text / layout]
- Audio transcript: [real-time transcript]
- Conversation history: [last 5 exchanges]
- Current timestamp: [ISO time]

USER QUESTION: [user input]

INSTRUCTIONS:
1. Answer based primarily on screen content + audio
2. Keep answers concise — 2–3 sentences max
3. If the answer isn't visible on screen, say: "I cannot see that in the current screen."
4. Never repeat the user's question back to them
5. Do not mention that you are an AI unless directly asked
6. Format code or commands in backticks

OUTPUT FORMAT:
Answer: [response]
Confidence: [high / medium / low]
Source: [screen | audio | memory | general knowledge]
```

---

### 6. Overlay UI

**Tech:** SwiftUI + `NSPanel` (preferred over `NSWindow` for overlay behavior)

**Window Properties:**
```swift
panel.level = .floating          // Always on top
panel.isOpaque = false           // Transparent background
panel.backgroundColor = .clear
panel.styleMask = [.borderless, .nonactivatingPanel]
panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
panel.sharingType = .none        // 🔒 STEALTH: invisible to screen share
panel.ignoresMouseEvents = false // Allow interaction
```

**Design:**
- Glassmorphism style (SF Symbol icons, vibrancy effect)
- Adjustable opacity (0.6–1.0)
- Drag-to-reposition
- Collapse/expand toggle
- Streaming text with typewriter animation
- Corner status badge: 🔒 Stealth | 🎤 Listening | ⚡ Thinking

---

## ⚙️ Feature Implementation

### 1. Hotkey Trigger
- **Activation:** `Cmd + Shift + Space` (show/hide overlay)
- **Capture trigger:** `Cmd + Shift + C` (capture + analyze current region)
- Implementation: `NSEvent.addGlobalMonitorForEvents(matching: .keyDown)`

---

### 2. Region Selection
- Click-and-drag selection overlay (like macOS screenshot tool)
- Selection persists until user resets it
- Visual highlight of the captured region
- Pass bounding box to capture module

---

### 3. Streaming Responses
- Use SSE (Server-Sent Events) streaming from LLM API
- Render tokens incrementally with SwiftUI `@Published` state
- Auto-scroll to bottom as new tokens arrive

---

### 4. Context Memory
- Store last 5 exchanges in memory (not persisted to disk by default)
- Optional: encrypted persistence using macOS Keychain
- Structure:
```json
[
  { "role": "user", "content": "..." },
  { "role": "assistant", "content": "..." }
]
```

---

### 5. Rate Limiting
- 2.5 second cooldown between requests
- Visual debounce indicator in UI
- Token budget per session (configurable)
- Cost estimator display (optional)

---

### 6. Credential Management *(Improved)*
- Store all API keys in **macOS Keychain** via `Security.framework`
- Never write keys to `.env` files or UserDefaults
- First-run setup wizard to configure keys securely

---

## 🔁 Execution Flow

```
[Hotkey Pressed]
      ↓
[Stealth Check: Apply sharingType = .none]
      ↓
[Capture Screen Region]
      ↓
[Send to Vision API → Extract Text]
      ↓
[Capture Audio (parallel)]
      ↓
[Transcribe via Whisper]
      ↓
[Build Context: Screen + Audio + Memory]
      ↓
[Send to LLM (streaming)]
      ↓
[Stream tokens to Overlay UI]
      ↓
[Display in Overlay — invisible to screen capture tools]
```

---

## 📁 Project Structure

```
ai-overlay-app/
│
├── mac-app/
│   ├── App/
│   │   ├── AppDelegate.swift
│   │   └── EntryPoint.swift
│   ├── UI/
│   │   ├── OverlayPanel.swift         # NSPanel with sharingType = .none
│   │   ├── OverlayViewModel.swift
│   │   ├── RegionSelectorView.swift
│   │   └── SettingsView.swift
│   ├── Core/
│   │   ├── HotkeyManager.swift
│   │   ├── ScreenCaptureManager.swift
│   │   ├── StealthManager.swift       # 🔒 NEW: screen share invisibility
│   │   ├── AudioCaptureManager.swift
│   │   └── ContextBuilder.swift
│   └── Services/
│       ├── VisionService.swift
│       ├── WhisperService.swift
│       ├── LLMService.swift           # Supports OpenAI, Claude, Gemini
│       └── KeychainService.swift      # Secure credential storage
│
├── python-services/                   # Optional local services
│   ├── whisper_local.py               # whisper.cpp wrapper
│   └── vision_local.py               # Local OCR fallback
│
├── config/
│   └── default_settings.json          # Non-sensitive defaults only
│
├── docs/
│   ├── plan.md
│   ├── stealth_implementation.md      # 🔒 Stealth tech deep-dive
│   └── permissions_guide.md
│
└── README.md
```

---

## 🔐 macOS Permissions Required

| Permission | Purpose |
|---|---|
| Screen Recording | ScreenCaptureKit region capture |
| Microphone | AVAudioEngine audio input |
| Accessibility | Global hotkeys via NSEvent monitor |
| Network | LLM/Vision API calls |

**Permission Request Flow:**
- Request permissions lazily (only when feature first used)
- Show user-friendly explanation before each prompt
- Handle denial gracefully with fallback messaging

---

## 🧪 Testing Strategy

**Unit Tests:**
- StealthManager: verify `sharingType = .none` is set and re-applied correctly
- VisionService: mock API responses with known OCR fixtures
- LLMService: verify streaming parse logic

**Integration Tests:**
- Full pipeline: hotkey → capture → transcribe → LLM → display
- Stealth test: launch QuickTime + Zoom simultaneously, verify overlay does not appear

**Manual QA Checklist:**
- [ ] Overlay invisible in Zoom screen share
- [ ] Overlay invisible in QuickTime screen recording
- [ ] Overlay invisible in macOS `Cmd+Shift+4` screenshot
- [ ] Overlay invisible in OBS capture
- [ ] Overlay visible on user's physical display
- [ ] Stealth status badge shows 🔒 when active
- [ ] API keys stored in Keychain, not in files

---

## 🚧 Known Challenges

| Challenge | Mitigation |
|---|---|
| `sharingType = .none` reset after `orderFront()` | Re-apply in `windowDidBecomeKey` delegate |
| OCR accuracy on complex UI | Use Vision LLM as fallback for low-confidence OCR |
| Audio noise / mis-transcription | Voice activity detection before sending to Whisper |
| API latency | Show skeleton/loading state in UI immediately |
| macOS permission friction on first launch | Setup wizard with guided permission flow |
| Third-party tools bypassing `sharingType` | Cannot prevent hardware-level capture; focus on software-level tools |

---

## 🚀 Future Enhancements

- **Vision LLM mode:** Replace OCR + text pipeline with direct screenshot-to-LLM (GPT-4o Vision)
- **Offline mode:** whisper.cpp + local LLM (Ollama/LM Studio) for fully air-gapped use
- **Voice output:** TTS using macOS `AVSpeechSynthesizer` or ElevenLabs
- **Smarter context:** Semantic memory using embeddings (remember past sessions)
- **Multi-monitor:** Detect active display and render overlay on same screen
- **Plugin system:** Allow custom prompt templates per app context (e.g., coding mode, reading mode)

---

## 🔒 Privacy & Security

- All API keys stored exclusively in macOS Keychain
- Audio never stored to disk (streamed in-memory only)
- Screenshots discarded after Vision API response
- Conversation history stored in memory only (no disk persistence by default)
- Network calls only to user-configured, user-owned API endpoints

---

## ⚠️ Ethical Use

This tool is a productivity assistant for **personal use**.

- Do not use in environments where AI assistance tools are prohibited (e.g., exams, regulated assessments)
- The stealth screen-share feature is intended to protect **user privacy** — not to deceive others
- Users are responsible for compliance with the rules of any platform or environment they use this in

---

## ✅ Deliverables

- [ ] Functional macOS application (.app bundle)
- [ ] `StealthManager.swift` with verified screen-share invisibility
- [ ] Setup wizard for permissions + API key configuration
- [ ] Demo video (overlay in use, stealth verification clip)
- [ ] Source code repository with CI/CD
- [ ] Documentation (architecture, stealth implementation, permissions guide)