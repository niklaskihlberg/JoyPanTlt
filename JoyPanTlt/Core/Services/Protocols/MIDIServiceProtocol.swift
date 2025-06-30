//
//  MIDIServiceProtocol.swift
//  JoyPanTlt
//
//  Created by Niklas Kihlberg on 2025-06-29.
//

import Foundation
import Combine

// MARK: - MIDI Service Protocol
protocol MIDIServiceProtocol: ObservableObject {
    var isInitialized: Bool { get }
    var isEnabled: Bool { get set }
    var availableDestinations: [(name: String, id: String)] { get }
    var selectedDestinationID: String { get set }
    
    /// Initialisera MIDI system
    func initialize() -> Bool
    
    /// Skicka MIDI Control Change
    func sendControlChange(channel: UInt8, controller: UInt8, value: UInt8)
    
    /// Skicka pan/tilt som MIDI CC med konfiguration
    func sendPanTilt(pan: Double, tilt: Double, config: JoystickMIDIConfig)
    
    /// Uppdatera tillgängliga MIDI destinations
    func refreshDestinations()
    
    /// Välj MIDI destination
    func selectDestination(id: String)
    
    /// Testa MIDI output
    func sendTestMessage()
    
    /// Stäng MIDI connections
    func cleanup()
}
