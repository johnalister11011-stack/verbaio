# verba.io

A lightweight macOS menu bar app that converts speech to text in real-time. Press a global hotkey to start recording, see live transcription in a floating overlay, and auto-paste the result into any text field.

## Features

- **Global hotkey** — `Cmd+Shift+Space` to toggle recording from anywhere
- **Live transcription** — real-time speech-to-text powered by Apple's Speech framework
- **Floating overlay** — non-intrusive panel with pulsing indicator, live text, and duration
- **Auto-paste** — transcribed text is automatically pasted into the focused field when you stop
- **Menu bar app** — lives in the menu bar, no dock icon clutter

## Requirements

- macOS 14.0+
- Swift 5.9+

## Build & Run

```bash
# Clone
git clone https://github.com/johnalister11011-stack/verbaio.git
cd verbaio

# Build and package the .app bundle
bash build-app.sh

# Launch
open build/VerbaIO.app
```

## Permissions

On first launch, grant these when prompted:

| Permission | Why |
|---|---|
| **Microphone** | Captures your voice for transcription |
| **Speech Recognition** | Converts speech to text via Apple's on-device engine |
| **Accessibility** | Enables the global hotkey and auto-paste (System Settings > Privacy & Security > Accessibility) |

## Usage

1. Launch the app — a waveform icon appears in the menu bar
2. Press **`Cmd+Shift+Space`** — a floating overlay appears and recording begins
3. Speak — your words appear in real-time in the overlay
4. Press **`Cmd+Shift+Space`** again — recording stops, text is pasted into the focused field
5. Click the menu bar icon to toggle recording or quit

## License

MIT
