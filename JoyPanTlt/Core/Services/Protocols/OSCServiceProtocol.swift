//
//  OSCServiceProtocol.swift
//  JoyPanTlt
//
//  Created by Niklas Kihlberg on 2025-06-29.
//

import Foundation
import Combine

// MARK: - OSC Service Protocol
protocol OSCServiceProtocol: ObservableObject {
    var isConnected: Bool { get }
    var connectionStatus: String { get }
    var isEnabled: Bool { get set }
    
    /// Anslut till OSC destination
    func connect(host: String, port: Int) async -> Bool
    
    /// Koppla från OSC destination
    func disconnect()
    
    /// Skicka pan/tilt värden till specifika OSC addresses
    func sendPanTilt(pan: Double, tilt: Double, panAddress: String, tiltAddress: String)
    
    /// Testa anslutning
    func testConnection() async -> Bool
    
    /// Skicka test meddelanden
    func sendTestMessage(to address: String, value: Double)
    
    /// Reset pan/tilt till centrum
    func resetPanTilt(panAddress: String, tiltAddress: String)
}

// MARK: - Default implementations
extension OSCServiceProtocol {
    func resetPanTilt(panAddress: String, tiltAddress: String) {
        sendPanTilt(pan: 0.0, tilt: 0.0, panAddress: panAddress, tiltAddress: tiltAddress)
    }
}
