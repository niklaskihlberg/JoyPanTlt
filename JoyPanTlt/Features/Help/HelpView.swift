import SwiftUI

struct HelpView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                
                // Header
                HStack {
                    Image(systemName: "questionmark.circle.fill")
                        .font(.title)
                        .foregroundColor(.blue)
                    
                    Text("JoyPanTlt Help")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Spacer()
                }
                
                Divider()
                
                // Keyboard Shortcuts
                HelpSection(
                    title: "Keyboard Shortcuts",
                    icon: "keyboard",
                    items: [
                        HelpItem(shortcut: "⌘ + ,", description: "Open Settings"),
                        HelpItem(shortcut: "⌘ + ?", description: "Show this Help"),
                        HelpItem(shortcut: "⌘ + W", description: "Close Window"),
                        HelpItem(shortcut: "⌘ + Q", description: "Quit Application"),
                        HelpItem(shortcut: "Space", description: "Reset ALL joysticks to center")
                    ]
                )
                
                // Virtual Joystick Controls
                HelpSection(
                    title: "Virtual Joystick Controls",
                    icon: "gamecontroller",
                    items: [
                        HelpItem(shortcut: "Arrow Keys", description: "Move ALL joysticks simultaneously"),
                        HelpItem(shortcut: "↑ + →", description: "Diagonal movement (combinations)"),
                        HelpItem(shortcut: "Mouse Drag", description: "Precise individual joystick control"),
                        HelpItem(shortcut: "Click", description: "Jump joystick to position"),
                        HelpItem(shortcut: "Space", description: "Reset all joysticks to center"),
                        HelpItem(shortcut: "Multi-Joystick", description: "Support for 1-8 joysticks simultaneously")
                    ]
                )
                
                // OSC Connection
                HelpSection(
                    title: "OSC Connection",
                    icon: "antenna.radiowaves.left.and.right",
                    items: [
                        HelpItem(shortcut: "Default Port", description: "21600 (Lightkey OSC)"),
                        HelpItem(shortcut: "Host", description: "127.0.0.1 (localhost)"),
                        HelpItem(shortcut: "Pan Address", description: "/fixture/selected/overrides/panAngle"),
                        HelpItem(shortcut: "Tilt Address", description: "/fixture/selected/overrides/tiltAngle"),
                        HelpItem(shortcut: "Multi Addresses", description: "/lightkey/layers/layer1/pan, /layer2/pan..."),
                        HelpItem(shortcut: "Auto Connect", description: "Connects automatically when enabled"),
                        HelpItem(shortcut: "Protocol", description: "UDP or TCP support")
                    ]
                )
                
                // Multi-Joystick System
                HelpSection(
                    title: "Multi-Joystick System",
                    icon: "rectangle.3.group",
                    items: [
                        HelpItem(shortcut: "Number of Joysticks", description: "Configure 1-8 virtual joysticks"),
                        HelpItem(shortcut: "Individual Settings", description: "Per-joystick sensitivity, invert, deadzone"),
                        HelpItem(shortcut: "Smart Layout", description: "Automatic grid layout based on window size"),
                        HelpItem(shortcut: "Keyboard Control", description: "Arrow keys affect ALL joysticks"),
                        HelpItem(shortcut: "Individual OSC", description: "Separate OSC addresses per joystick"),
                        HelpItem(shortcut: "Individual MIDI", description: "Separate MIDI channels/CCs per joystick")
                    ]
                )
                
                // Virtual Joystick Settings
                HelpSection(
                    title: "Virtual Joystick Settings",
                    icon: "slider.vertical.3",
                    items: [
                        HelpItem(shortcut: "Sensitivity", description: "Individual response speed (0.1 - 2.0)"),
                        HelpItem(shortcut: "Deadzone", description: "Ignore small movements (0.0 - 0.5)"),
                        HelpItem(shortcut: "Damping", description: "Smooth movement (0.1 - 1.0)"),
                        HelpItem(shortcut: "Invert X/Y", description: "Reverse movement direction per axis"),
                        HelpItem(shortcut: "Update Rate", description: "10-100 Hz performance control"),
                        HelpItem(shortcut: "Visual Feedback", description: "Show position indicators (disabled)")
                    ]
                )
                
                // Key Commands
                HelpSection(
                    title: "Key Commands",
                    icon: "keyboard.badge.ellipsis",
                    items: [
                        HelpItem(shortcut: "Enable/Disable", description: "Toggle keyboard control"),
                        HelpItem(shortcut: "Sensitivity", description: "Keyboard input sensitivity (0.1 - 2.0)"),
                        HelpItem(shortcut: "Multi-Joystick", description: "Commands affect all joysticks"),
                        HelpItem(shortcut: "Customizable", description: "Remap arrow keys and reset key"),
                        HelpItem(shortcut: "Real-time", description: "20Hz continuous updates while pressed")
                    ]
                )
                
                // MIDI Output
                HelpSection(
                    title: "MIDI Output",
                    icon: "pianokeys",
                    items: [
                        HelpItem(shortcut: "Virtual Port", description: "Creates 'JoyPanTlt Virtual Out' port"),
                        HelpItem(shortcut: "Per-Joystick MIDI", description: "Individual channels and CCs"),
                        HelpItem(shortcut: "Pan CC", description: "MIDI Continuous Controller for Pan"),
                        HelpItem(shortcut: "Tilt CC", description: "MIDI Continuous Controller for Tilt"),
                        HelpItem(shortcut: "Channels", description: "MIDI Channels 1-16"),
                        HelpItem(shortcut: "Auto-mapping", description: "Ch1:CC1-2, Ch2:CC3-4, etc.")
                    ]
                )
                
                // Gamepad Support
                HelpSection(
                    title: "Gamepad Support",
                    icon: "gamecontroller.fill",
                    items: [
                        HelpItem(shortcut: "Controller Types", description: "Xbox, PlayStation, MFi controllers"),
                        HelpItem(shortcut: "Joystick Selection", description: "Left stick, Right stick, or D-Pad"),
                        HelpItem(shortcut: "Sensitivity", description: "Adjustable response (0.1 - 3.0)"),
                        HelpItem(shortcut: "Deadzone", description: "Ignore controller drift (0.0 - 0.5)"),
                        HelpItem(shortcut: "Invert Axes", description: "Reverse X or Y axis individually"),
                        HelpItem(shortcut: "Auto-detect", description: "Automatic controller detection")
                    ]
                )
                
                // Tips & Tricks
                HelpSection(
                    title: "Tips & Tricks",
                    icon: "lightbulb",
                    items: [
                        HelpItem(shortcut: "High Performance", description: "Lower update interval for smooth control"),
                        HelpItem(shortcut: "Precise Control", description: "Use lower sensitivity values"),
                        HelpItem(shortcut: "Multi-Joystick Setup", description: "Start with 2-4 joysticks for testing"),
                        HelpItem(shortcut: "Quick Reset", description: "Press Space to center all joysticks"),
                        HelpItem(shortcut: "Keyboard + Mouse", description: "Use both input methods simultaneously"),
                        HelpItem(shortcut: "Individual Tuning", description: "Each joystick has separate settings"),
                        HelpItem(shortcut: "OSC Testing", description: "Enable→Auto-connect for quick testing")
                    ]
                )
                
                Spacer(minLength: 20)
                
                // Footer
                VStack(spacing: 8) {
                    Divider()
                    HStack {
                        Text("JoyPanTlt v2.0")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("Created by Niklas Kihlberg, 2025")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(24)
        }
        .frame(minWidth: 600, minHeight: 500)
        .navigationTitle("Help")
    }
}

// MARK: - Help Section Component
struct HelpSection: View {
    let title: String
    let icon: String
    let items: [HelpItem]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                    .font(.title2)
                
                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            
            VStack(spacing: 8) {
                ForEach(items, id: \.shortcut) { item in
                    HStack {
                        Text(item.shortcut)
                            .font(.system(.body, design: .monospaced))
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                            .frame(minWidth: 120, alignment: .leading)
                        
                        Text(item.description)
                            .foregroundColor(.primary)
                        
                        Spacer()
                    }
                    .padding(.vertical, 2)
                }
            }
            .padding(.leading, 30)
        }
    }
}

// MARK: - Help Item Model
struct HelpItem {
    let shortcut: String
    let description: String
}

// MARK: - Preview
#Preview {
    HelpView()
}