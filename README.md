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

## ⚠️ Ethical Use Notice

This tool is a **personal productivity assistant**. The stealth screen-share feature protects user privacy — not to deceive others. Users are responsible for compliance with the rules of any platform or environment they use this in.

---

## 📄 License

MIT License — See [LICENSE](LICENSE) for details.
