//
//  JoystickMIDIConfig.swift
//  JoyPanTlt
//
//  Created by Niklas Kihlberg on 2025-06-29.
//

import Foundation

// MARK: - MIDI Configuration per Joystick
struct JoystickMIDIConfig: Identifiable, Codable {
    var id = UUID()
    var name: String
    var panChannel: Int
    var panController: Int
    var tiltChannel: Int
    var tiltController: Int
    
    init(name: String, panChannel: Int, panController: Int, tiltChannel: Int, tiltController: Int) {
        self.name = name
        self.panChannel = panChannel
        self.panController = panController
        self.tiltChannel = tiltChannel
        self.tiltController = tiltController
    }
}

// MARK: - Extensions
extension JoystickMIDIConfig {
    /// Skapa default konfiguration för en joystick baserat på index
    static func defaultConfig(for index: Int) -> JoystickMIDIConfig {
        return JoystickMIDIConfig(
            name: "Joystick \(index + 1)",
            panChannel: index + 1,
            panController: (index * 2) + 1,
            tiltChannel: index + 1,
            tiltController: (index * 2) + 2
        )
    }
    
    /// Validera MIDI konfiguration
    var isValid: Bool {
        return panChannel >= 1 && panChannel <= 16 &&
               tiltChannel >= 1 && tiltChannel <= 16 &&
               panController >= 0 && panController <= 127 &&
               tiltController >= 0 && tiltController <= 127
    }
}
