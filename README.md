# 🧠 AI Overlay Assistant (macOS)

A native macOS AI assistant that captures screen content, transcribes audio, and uses LLM APIs to generate answers — all displayed in a **translucent floating overlay** that is **completely invisible to screen sharing and recording tools**.

![macOS 13+](https://img.shields.io/badge/macOS-13%2B%20Ventura-blue)
![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange)
![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-purple)

---

## ✨ Features

- **🔒 Screen-Share Invisible** — Overlay is hidden from Zoom, Teams, OBS, QuickTime, and all macOS screenshot tools using `NSWindow.sharingType = .none`
- **📸 Screen Capture** — Capture any screen region using ScreenCaptureKit with OCR text extraction
- **🎤 Audio Transcription** — Real-time speech-to-text via Whisper API with voice activity detection
- **🤖 Multi-LLM Support** — OpenAI (GPT-4o), Anthropic (Claude), and Google (Gemini) with streaming responses
- **💎 Glassmorphic UI** — Beautiful, translucent floating overlay with vibrancy effects
- **🔐 Secure Credentials** — All API keys stored exclusively in macOS Keychain
- **⌨️ Global Hotkeys** — Trigger from anywhere with system-wide keyboard shortcuts

---

## ✅ Positive Use Cases (Non-Cheating)

AI Overlay Assistant can be used to make everyday work **faster, clearer, and more accessible**—without harming others.

### Accessibility & inclusion
- **Reading support** — simplify dense text, explain jargon, summarize long pages
- **Translation** — translate selected on-screen text while keeping context
- **Focus help** — turn what’s on screen into short checklists and next steps

### Learning & coaching (outside graded/proctored contexts)
- **Tutoring** — guided hints and explanations for practice problems and self-study
- **Debugging mentor** — interpret logs/errors, suggest safe troubleshooting steps
- **Writing clarity** — rewrite drafts for tone, brevity, and structure (you review before sending)

### Productivity & knowledge work
- **Meetings** — summarize notes/transcripts, generate action items and follow-ups
- **Research** — extract key points from docs/papers, compare options, list pros/cons
- **Privacy-first assist** — the overlay can keep sensitive help *off* recordings and screen shares when you’re presenting

---

## 🚀 Getting Started

### Prerequisites

- macOS 13.0 (Ventura) or later
- Xcode 15.0+
- Swift 5.9+
- At least one LLM API key (OpenAI, Anthropic, or Google)

### Build & Run

```bash
cd mac-app
swift build
swift run
```

Or open in Xcode:

```bash
cd mac-app
open Package.swift
```

### First Launch

1. Grant **Accessibility** permission when prompted (required for global hotkeys)
2. Open Settings from the menu bar icon (🧠)
3. Enter your API key(s) — they're stored securely in macOS Keychain
4. Press **⌘⇧Space** to show the overlay

---

## ⌨️ Keyboard Shortcuts

| Shortcut | Action |
|---|---|
| `⌘⇧Space` | Toggle overlay visibility |
| `⌘⇧C` | Capture screen region + analyze |
| `⌘⇧A` | Toggle audio capture |
| `Escape` | Hide overlay |

---

## 🏗️ Architecture

```
mac-app/Sources/
├── App/
│   ├── EntryPoint.swift              # SwiftUI App entry point
│   └── AppDelegate.swift             # Lifecycle, services, hotkeys
├── Core/
│   ├── HotkeyManager.swift           # Carbon-based global hotkeys
│   ├── StealthManager.swift          # 🔒 Screen share invisibility
│   ├── ScreenCaptureManager.swift    # ScreenCaptureKit integration
│   ├── AudioCaptureManager.swift     # AVAudioEngine mic input
│   └── ContextBuilder.swift          # LLM context assembly
├── Services/
│   ├── LLMService.swift              # Multi-provider LLM (streaming)
│   ├── VisionService.swift           # Google Vision OCR
│   ├── WhisperService.swift          # Whisper transcription
│   └── KeychainService.swift         # Secure API key storage
├── UI/
│   ├── OverlayPanel.swift            # NSPanel with stealth config
│   ├── OverlayViewModel.swift        # State management
│   ├── OverlayContentView.swift      # Main overlay SwiftUI view
│   ├── RegionSelectorView.swift      # Screen region selector
│   └── SettingsView.swift            # API key + preferences
└── Resources/
    ├── Info.plist                     # Permission descriptions
    └── AIOverlayAssistant.entitlements
```

---

## 🔒 Stealth Technology

The overlay uses `NSWindow.sharingType = .none` — Apple's official API to exclude windows from all screen capture:

```swift
overlayWindow.sharingType = .none
```

This makes the overlay invisible to:
- ✅ Zoom screen share
- ✅ Google Meet / Microsoft Teams
- ✅ QuickTime screen recording
- ✅ macOS screenshots (⌘⇧3/4/5)
- ✅ OBS, Loom, CleanShot X
- ✅ `screencapture` CLI tool

The overlay remains visible only on your physical display.

---

## 🔐 Security & Privacy

- **API keys** are stored exclusively in macOS Keychain — never in `.env` files
- **Audio** is streamed in-memory only — never saved to disk
- **Screenshots** are discarded after processing — never persisted
- **Conversation history** is stored in memory only (clears on app quit)
- **Network calls** go only to user-configured API endpoints

---

## 🛠 Supported LLM Providers

| Provider | Models | Features |
|---|---|---|
| OpenAI | GPT-4o, GPT-4 Turbo | Streaming, Vision |
| Anthropic | Claude Sonnet 4 | Streaming, Long context |
| Google | Gemini 2.0 Flash | Streaming, Free tier |

---

## ⚠️ Responsible Use (Anti-Cheating) Notice

This tool is a **personal productivity and accessibility assistant**. The stealth screen-share feature is intended to **protect privacy** (e.g., when presenting or recording) — **not** to misrepresent work or bypass rules.

Please use responsibly:
- **Do not use** this in exams, interviews, or any proctored / closed-book / no-assistance environment.
- **Follow policies** for schools, employers, clients, and platforms you’re using.
- **Respect others**: don’t use the overlay to gain unfair advantage over people who are following the rules.
- **Get consent** before capturing or transcribing other people’s audio/content.

---

## 📄 License

MIT License — See [LICENSE](LICENSE) for details.
