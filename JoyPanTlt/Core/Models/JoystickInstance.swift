//
//  JoystickInstance.swift
//  JoyPanTlt
//
//  Created by Niklas Kihlberg on 2025-06-29.
//

import Foundation

// MARK: - Joystick Instance Model
struct JoystickInstance: Identifiable, Codable {
    var id = UUID()
    var name: String
    var number: Int = 1
    var isEnabled: Bool = true
    var oscPanAddress: String
    var oscTiltAddress: String
    var midiChannel: Int
    var midiCCPan: Int
    var midiCCTilt: Int
    
    // Per-joystick inställningar
    var sensitivity: Double = 0.5
    var invertX: Bool = false
    var invertY: Bool = false
    var deadzone: Double = 0.1
    var damping: Double = 0.8
    
    // Settings för denna joystick
    var settings: JoystickSettings = JoystickSettings()
    
    // Backward compatibility properties
    var oscAddress: String {
        get { oscPanAddress }
        set { 
            oscPanAddress = newValue 
            oscTiltAddress = newValue.replacingOccurrences(of: "pan", with: "tilt")
        }
    }
    
    // CodingKeys för att hantera både gamla och nya format
    private enum CodingKeys: String, CodingKey {
        case id, name, number, isEnabled, oscPanAddress, oscTiltAddress, midiChannel, midiCCPan, midiCCTilt
        case sensitivity, invertX, invertY, deadzone, damping, settings
    }
}

// MARK: - Joystick Settings
struct JoystickSettings: Codable {
    var panOffsetEnabled: Bool = false
    var tiltOffsetEnabled: Bool = false
    var panOffset: Double = 0.0
    var tiltOffset: Double = 0.0
}

// MARK: - Extensions
extension JoystickInstance {
    // Convenience initializers
    init(name: String, oscAddress: String, midiChannel: Int = 1, midiCCPan: Int = 1, midiCCTilt: Int = 2) {
        self.name = name
        self.number = midiChannel
        self.oscPanAddress = "\(oscAddress)/pan"
        self.oscTiltAddress = "\(oscAddress)/tilt"
        self.midiChannel = midiChannel
        self.midiCCPan = midiCCPan
        self.midiCCTilt = midiCCTilt
    }
    
    init(name: String, oscPanAddress: String, oscTiltAddress: String, midiChannel: Int = 1, midiCCPan: Int = 1, midiCCTilt: Int = 2) {
        self.name = name
        self.number = midiChannel
        self.oscPanAddress = oscPanAddress
        self.oscTiltAddress = oscTiltAddress
        self.midiChannel = midiChannel
        self.midiCCPan = midiCCPan
        self.midiCCTilt = midiCCTilt
    }
}
