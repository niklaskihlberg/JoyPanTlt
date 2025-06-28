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
                        HelpItem(shortcut: "Space", description: "Reset Pan/Tilt to Center")
                    ]
                )
                
                // Virtual Joystick Controls
                HelpSection(
                    title: "Virtual Joystick Controls",
                    icon: "gamecontroller",
                    items: [
                        HelpItem(shortcut: "Arrow Keys", description: "Move in 100% direction"),
                        HelpItem(shortcut: "↑ + →", description: "Diagonal movement (combinations)"),
                        HelpItem(shortcut: "Mouse Drag", description: "Precise joystick control"),
                        HelpItem(shortcut: "Click", description: "Jump joystick to position"),
                        HelpItem(shortcut: "Space", description: "Reset joystick to center")
                    ]
                )
                
                // OSC Connection
                HelpSection(
                    title: "OSC Connection",
                    icon: "antenna.radiowaves.left.and.right",
                    items: [
                        HelpItem(shortcut: "Default Port", description: "21600 (Lightkey OSC)"),
                        HelpItem(shortcut: "Host", description: "127.0.0.1 (localhost)"),
                        HelpItem(shortcut: "Pan Message", description: "/lightkey/layers/master/opacity"),
                        HelpItem(shortcut: "Tilt Message", description: "/lightkey/layers/master/pan"),
                        HelpItem(shortcut: "Auto Connect", description: "Connects automatically on startup")
                    ]
                )
                
                // Settings
                HelpSection(
                    title: "Virtual Joystick Settings",
                    icon: "slider.vertical.3",
                    items: [
                        HelpItem(shortcut: "Sensitivity", description: "Control response speed (0.1 - 2.0)"),
                        HelpItem(shortcut: "Damping", description: "Smooth movement (0.0 - 1.0)"),
                        HelpItem(shortcut: "Snap Back Speed", description: "Return-to-center speed"),
                        HelpItem(shortcut: "Visual Feedback", description: "Show position indicators"),
                        HelpItem(shortcut: "Invert Pan/Tilt", description: "Reverse movement direction"),
                        HelpItem(shortcut: "Update Rate", description: "10-100 Hz performance control")
                    ]
                )
                
                // MIDI (if implemented)
                HelpSection(
                    title: "MIDI Output",
                    icon: "pianokeys",
                    items: [
                        HelpItem(shortcut: "Pan CC", description: "MIDI Continuous Controller for Pan"),
                        HelpItem(shortcut: "Tilt CC", description: "MIDI Continuous Controller for Tilt"),
                        HelpItem(shortcut: "Channel", description: "MIDI Channel (1-16)"),
                        HelpItem(shortcut: "Virtual Port", description: "Creates virtual MIDI output")
                    ]
                )
                
                // Tips & Tricks
                HelpSection(
                    title: "Tips & Tricks",
                    icon: "lightbulb",
                    items: [
                        HelpItem(shortcut: "High Performance", description: "Lower update interval for smooth control"),
                        HelpItem(shortcut: "Precise Control", description: "Use lower sensitivity values"),
                        HelpItem(shortcut: "Quick Reset", description: "Press Space key to center quickly"),
                        HelpItem(shortcut: "Visual Debug", description: "Enable visual feedback to see exact positions"),
                        HelpItem(shortcut: "Test Connection", description: "Use Settings → Test Lightkey to verify OSC")
                    ]
                )
                
                Spacer(minLength: 20)
                
                // Footer
                VStack(spacing: 8) {
                    Divider()
                    HStack {
                        Text("JoyPanTlt v1.0")
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