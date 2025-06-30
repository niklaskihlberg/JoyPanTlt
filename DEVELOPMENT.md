# JoyPanTlt, Developer Guide

## Quick Reference

### Structure (2025-06-29)

```sh

JoyPanTlt/
├─ App/
│  ├─ JoyPanTltApp.swift                        # Application entry point, SwiftUI @main
│  └─ AppDelegate.swift                         # macOS app lifecycle, window management
├─ Core/
│  ├─ Models/
│  │  ├─ JoystickInstance.swift                 # Data for a joystick
│  │  ├─ JoystickMIDIConfig.swift               # MIDI settings per joystick
│  │  └─ TranslationResult.swift                # Result of input translation
│  ├─ Services/
│  │  ├─ Protocols/
│  │  │   ├─ OSCServiceProtocol.swift           # Protocol for OSC service
│  │  │   ├─ MIDIServiceProtocol.swift          # Protocol for MIDI service
│  │  │   └─ InputServiceProtocol.swift         # Protocol for input services
│  │  ├─ OSCService.swift                       # Implementation of OSC service
│  │  ├─ MIDIService.swift                      # Implementation of MIDI service
│  │  └─ GamepadService.swift                   # Implementation of gamepad service
│  └─ Managers/
│      ├─ ConfigurationManager.swift            # Handles loading/saving config
│      ├─ JoystickManager.swift                 # Handles joystick logic
│      └─ TranslationManager.swift              # Handles input translation
├─ Features/
│  ├─ MainView/
│  │   ├─ ContentView.swift                     # Main view, displays joysticks
│  │   ├─ ContentViewModel.swift                # ViewModel for the main view
│  │   └─ Components/
│  │       ├─ VirtualJoystick.swift             # UI component for joystick
│  │       ├─ JoystickGridItem.swift            # A joystick in grid layout
│  │       └─ VisualEffectBackground.swift      # Blurry/transparent background
│  ├─ Settings/
│  │   ├─ ConfigurationView.swift               # Settings main view
│  │   ├─ ConfigurationViewModel.swift          # ViewModel for settings
│  │   └─ Tabs/
│  │       ├─ VirtualJoystickSettingsView.swift # Joystick settings
│  │       ├─ OSCSettingsView.swift             # OSC settings
│  │       ├─ MIDISettingsView.swift            # MIDI settings
│  │       └─ GamepadSettingsView.swift         # Gamepad settings
│  └─ Help/
│      ├─ HelpView.swift                        # Help view (UI)
│      └─ HelpViewModel.swift                   # ViewModel for help
├─ Configuration/
│  ├─ VirtualJoystickConfiguration.swift        # Data & logic for joystick settings
│  ├─ OSCConfiguration.swift                    # Data & logic for OSC settings
│  ├─ MIDIConfiguration.swift                   # Data & logic for MIDI settings
│  └─ GamepadConfiguration.swift                # Data & logic for gamepad settings
├─ Utilities/
│  ├─ Extensions/
│  │   ├─ CGPoint+Extensions.swift              # Helper methods for CGPoint
│  │   └─ Color+Extensions.swift                # Helper methods for colors
│  ├─ Constants/
│  │   ├─ OSCConstants.swift                    # Default values for OSC
│  │   └─ MIDIConstants.swift                   # Default values for MIDI
│  └─ Helpers/
│      ├─ UserDefaultsHelper.swift              # Helper for UserDefaults
│      └─ ValidationHelper.swift                # Input/data validation
└─ Resources/
    └─ Assets.xcassets/                         # Images, colors, icons

```

## Architecture & Flows

**Input Flow:**

```sh

Input Source → Normalization → Translation → Output
     ↓               ↓            ↓           ↓
Virtual/Physical → (-1...1) → (degrees) → OSC/MIDI

```

- `numberOfJoysticks` (1-8) triggers `updateJoystickInstances()`
- Each `JoystickInstance` has its own OSC/MIDI settings
- Managers sync via callback system  
---

**Performance:**

- Update interval: 0.01–0.2s (10–100Hz)
- Grid layout optimizes for window aspect ratio
- Input priority: gamepad → mouse → keyboard

---

## Status & Checklist

- [x] MVVM + Dependency Injection
- [x] Protocol-based service design
- [x] Feature-based file structure
- [x] Settings interface
- [x] UI/UX: anti-cropping, padding, dynamic joystick count
- [x] App builds & runs without errors

---

## Distribution

**Build and create DMG:**
```bash
./build_and_distribute.sh
```
**Manually:**
```bash
xcodebuild -project JoyPanTlt.xcodeproj -scheme JoyPanTlt -configuration Release build
mkdir -p Distribution/JoyPanTlt
cp -R ~/Library/Developer/Xcode/DerivedData/.../Release/JoyPanTlt.app Distribution/JoyPanTlt/
ln -sf /Applications Distribution/JoyPanTlt/Applications
hdiutil create -volname "JoyPanTlt v1.0" -srcfolder Distribution/JoyPanTlt -format UDZO -imagekey zlib-level=9 JoyPanTlt-v1.0.dmg
```

---

## Style Guide

- **Indentation:** 2 spaces (Swift, Markdown, Bash)
- **Naming convention:** CamelCase for Swift, snake_case for UserDefaults keys
- **ViewModels:** All business logic outside Views
- **Protocols:** All service access via protocols for testability
- **UI:** SwiftUI, no UIKit/AppKit in Views

**Example code style:**

```swift

struct ExampleView: View {
  var body: some View {
    VStack(spacing: 8) {
      Text("Hej!")
        .font(.headline)
      Button("Press me") {
        print("Klick!")
      }
    }
    .padding(16)
  }
}

```

---

## History & Archive

### Old patterns (replaced)

```swift
// Before (singleton):
@StateObject private var oscManager = OSCManager.shared

// After (DI):
struct ContentView: View {
  @StateObject var viewModel: ContentViewModel
  init(viewModel: ContentViewModel) {
    self._viewModel = StateObject(wrappedValue: viewModel)
  }
}

```
