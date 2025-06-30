//
//  HelpViewModel.swift
//  JoyPanTlt
//
//  Created by Niklas Kihlberg on 2025-06-29.
//

import Foundation

// MARK: - Help View Model
class HelpViewModel: ObservableObject {
    // MARK: - Help Content
    struct HelpSection {
        let title: String
        let icon: String
        let items: [HelpItem]
    }
    
    struct HelpItem {
        let shortcut: String
        let description: String
    }
    
    // MARK: - Published Properties
    @Published var helpSections: [HelpSection] = []
    
    // MARK: - Initialization
    init() {
        setupHelpContent()
    }
    
    // MARK: - Setup
    private func setupHelpContent() {
        helpSections = [
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
            ),
            
            HelpSection(
                title: "OSC Connection",
                icon: "antenna.radiowaves.left.and.right",
                items: [
                    HelpItem(shortcut: "Default Port", description: "21600 (Lightkey OSC)"),
                    HelpItem(shortcut: "Host", description: "127.0.0.1 (localhost)"),
                    HelpItem(shortcut: "Pan Message", description: "/fixture/selected/overrides/panAngle"),
                    HelpItem(shortcut: "Tilt Message", description: "/fixture/selected/overrides/tiltAngle"),
                    HelpItem(shortcut: "Auto Connect", description: "Connects automatically on startup")
                ]
            ),
            
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
            ),
            
            HelpSection(
                title: "MIDI Output",
                icon: "pianokeys",
                items: [
                    HelpItem(shortcut: "Virtual Port", description: "JoyPanTlt Virtual Out (internal routing)"),
                    HelpItem(shortcut: "Pan Control", description: "MIDI CC mapped to X-axis movement"),
                    HelpItem(shortcut: "Tilt Control", description: "MIDI CC mapped to Y-axis movement"),
                    HelpItem(shortcut: "Channels", description: "Separate MIDI channels per joystick"),
                    HelpItem(shortcut: "Range", description: "Full 0-127 MIDI CC range")
                ]
            ),
            
            HelpSection(
                title: "Multi-Joystick Setup",
                icon: "squares.below.rectangle",
                items: [
                    HelpItem(shortcut: "Number of Joysticks", description: "1-8 virtual joysticks"),
                    HelpItem(shortcut: "Individual OSC", description: "Each joystick has own OSC addresses"),
                    HelpItem(shortcut: "Individual MIDI", description: "Each joystick has own MIDI channels"),
                    HelpItem(shortcut: "Grid Layout", description: "Automatic responsive grid arrangement"),
                    HelpItem(shortcut: "Enable/Disable", description: "Per-joystick activation control")
                ]
            ),
            
            HelpSection(
                title: "Physical Gamepad Support",
                icon: "gamecontroller.fill",
                items: [
                    HelpItem(shortcut: "Auto Detection", description: "Automatically finds connected controllers"),
                    HelpItem(shortcut: "Thumbsticks", description: "Left/Right thumbstick selection"),
                    HelpItem(shortcut: "D-Pad Support", description: "Use D-Pad for digital control"),
                    HelpItem(shortcut: "Sensitivity", description: "Adjustable response sensitivity"),
                    HelpItem(shortcut: "Deadzone", description: "Configurable deadzone for precision")
                ]
            )
        ]
    }
}
