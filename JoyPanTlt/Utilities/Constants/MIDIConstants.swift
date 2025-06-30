//
//  MIDIConstants.swift
//  JoyPanTlt
//
//  Created by Niklas Kihlberg on 2025-06-29.
//

import Foundation

// MARK: - MIDI Constants
enum MIDIConstants {
    // MIDI value ranges
    static let minValue: UInt8 = 0
    static let maxValue: UInt8 = 127
    static let centerValue: UInt8 = 64
    
    // MIDI channels (1-16)
    static let minChannel = 1
    static let maxChannel = 16
    
    // Default settings
    static let defaultChannel = 1
    static let defaultPanController = 1
    static let defaultTiltController = 2
    
    // Virtual port name
    static let virtualPortName = "JoyPanTlt Virtual Out"
    
    // Conversion helpers
    static func panToMIDI(_ pan: Double) -> UInt8 {
        // Pan: -180° to +180° → 0 to 127
        let normalized = (pan + 180.0) / 360.0
        return UInt8(max(0, min(127, normalized * 127)))
    }
    
    static func tiltToMIDI(_ tilt: Double) -> UInt8 {
        // Tilt: -90° to +90° → 0 to 127
        let normalized = (tilt + 90.0) / 180.0
        return UInt8(max(0, min(127, normalized * 127)))
    }
    
    static func normalizedToMIDI(_ value: Double) -> UInt8 {
        // Normalized -1.0 to +1.0 → 0 to 127
        let normalized = (value + 1.0) / 2.0
        return UInt8(max(0, min(127, normalized * 127)))
    }
}
