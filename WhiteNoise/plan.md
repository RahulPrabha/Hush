# White Noise Menu Bar App

A lightweight macOS menu bar app that generates white, pink, and brown noise.

## Status: Complete

## Features
- **3 noise types**: White (flat, crisp), Pink (balanced, natural), Brown (deep, rumbling)
- **Volume control** with slider and percentage display
- **Play/Pause** toggle
- **Global keyboard shortcut**: Cmd+Shift+W to toggle from anywhere
- **Preferences persistence**: Saves noise type and volume between sessions
- **Menu bar icon**: Changes based on playing state (waveform vs waveform.slash)
- **No dock icon**: Runs as a pure menu bar app (LSUIElement = true)

## Tech Stack
- SwiftUI + MenuBarExtra (macOS 13+)
- AVAudioEngine for real-time audio generation
- Carbon APIs for global hotkey registration
- @AppStorage for preferences

## Project Structure
```
WhiteNoise/
├── WhiteNoise.xcodeproj/
│   └── project.pbxproj
└── WhiteNoise/
    ├── WhiteNoiseApp.swift      # App entry point, MenuBarExtra setup
    ├── ContentView.swift         # Menu dropdown UI
    ├── AudioEngine.swift         # AVAudioEngine wrapper, play/pause/volume
    ├── NoiseGenerator.swift      # Noise algorithms (white/pink/brown)
    ├── HotkeyManager.swift       # Global Cmd+Shift+W shortcut
    └── Assets.xcassets/          # App icon and colors
```

## File Descriptions

### WhiteNoiseApp.swift
- Entry point with @main
- Creates MenuBarExtra with window style
- Initializes AudioEngine and HotkeyManager
- Menu bar icon updates based on isPlaying state

### NoiseGenerator.swift
- `NoiseType` enum: white, pink, brown
- White noise: Random samples (flat frequency spectrum)
- Pink noise: Paul Kellet's refined 1/f algorithm
- Brown noise: Integrated white noise (1/f²)

### AudioEngine.swift
- Wraps AVAudioEngine with AVAudioSourceNode
- Real-time sample generation in render callback
- Smooth fade in/out on play/pause
- Published properties: isPlaying, volume, noiseType

### ContentView.swift
- SwiftUI view for menu dropdown
- Noise type picker (inline style)
- Volume slider with speaker icons
- Play/Pause button with space bar shortcut
- Keyboard shortcut info display
- Quit button (Cmd+Q)
- Persists preferences with @AppStorage

### HotkeyManager.swift
- Uses Carbon APIs (RegisterEventHotKey)
- Registers Cmd+Shift+W globally
- Calls onToggle callback when triggered

## Build Instructions
```bash
open WhiteNoise.xcodeproj
# Press Cmd+R to build and run
```

## Requirements
- macOS 13.0+
- Xcode 15+

## Permissions
- Accessibility permission may be required for global keyboard shortcut
  (System Settings → Privacy & Security → Accessibility)

## Future Enhancements (not implemented)
- [ ] Sleep timer
- [ ] Additional sound types (rain, ocean, etc.)
- [ ] Customizable keyboard shortcut
- [ ] App icon design
