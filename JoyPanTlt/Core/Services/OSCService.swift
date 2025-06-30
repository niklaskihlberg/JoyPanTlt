//
//  OSCService.swift
//  JoyPanTlt
//
//  Created by Niklas Kihlberg on 2025-06-29.
//

import Foundation
import Network
import Combine

// MARK: - OSC Service Implementation
class OSCService: OSCServiceProtocol {
    // MARK: - Published Properties
    @Published var isConnected: Bool = false
    @Published var connectionStatus: String = "Disconnected"
    @Published var isEnabled: Bool = false
    
    // MARK: - Private Properties
    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "OSCService")
    
    // MARK: - Connection Management
    func connect(host: String, port: Int) async -> Bool {
        return await withCheckedContinuation { continuation in
            disconnect() // Close existing connection
            
            let nwHost = NWEndpoint.Host(host)
            guard port > 0 && port <= 65535 else {
                DispatchQueue.main.async {
                    self.connectionStatus = "Invalid port range"
                }
                continuation.resume(returning: false)
                return
            }
            
            let nwPort = NWEndpoint.Port(integerLiteral: UInt16(port))
            
            let connection = NWConnection(host: nwHost, port: nwPort, using: .udp)
            self.connection = connection
            
            var hasCompleted = false
            
            connection.stateUpdateHandler = { [weak self] state in
                guard !hasCompleted else { return }
                
                DispatchQueue.main.async {
                    switch state {
                    case .ready:
                        hasCompleted = true
                        self?.isConnected = true
                        self?.connectionStatus = "Connected to \(host):\(port)"
                        print("✅ OSC Connected to \(host):\(port)")
                        continuation.resume(returning: true)
                        
                    case .failed(let error):
                        hasCompleted = true
                        self?.isConnected = false
                        self?.connectionStatus = "Failed: \(error.localizedDescription)"
                        print("❌ OSC Connection failed: \(error)")
                        continuation.resume(returning: false)
                        
                    case .cancelled:
                        if !hasCompleted {
                            hasCompleted = true
                            self?.isConnected = false
                            self?.connectionStatus = "Cancelled"
                            continuation.resume(returning: false)
                        }
                        
                    case .waiting(let error):
                        self?.connectionStatus = "Waiting: \(error.localizedDescription)"
                        
                    default:
                        break
                    }
                }
            }
            
            connection.start(queue: queue)
            
            // Timeout after 5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                if !hasCompleted {
                    hasCompleted = true
                    connection.cancel()
                    self.connectionStatus = "Connection timeout"
                    continuation.resume(returning: false)
                }
            }
        }
    }
    
    func disconnect() {
        connection?.cancel()
        connection = nil
        DispatchQueue.main.async {
            self.isConnected = false
            self.connectionStatus = "Disconnected"
        }
        print("🔄 OSC Disconnected")
    }
    
    // MARK: - Message Sending
    func sendPanTilt(pan: Double, tilt: Double, panAddress: String, tiltAddress: String) {
        guard isConnected, let connection = connection else {
            print("⚠️ OSC not connected - cannot send pan/tilt")
            return
        }
        
        // Send pan message
        let panMessage = createOSCMessage(address: panAddress, value: Float(pan))
        connection.send(content: panMessage, completion: .contentProcessed { error in
            if let error = error {
                print("❌ Failed to send pan: \(error)")
            }
        })
        
        // Send tilt message with small delay
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.01) {
            let tiltMessage = self.createOSCMessage(address: tiltAddress, value: Float(tilt))
            connection.send(content: tiltMessage, completion: .contentProcessed { error in
                if let error = error {
                    print("❌ Failed to send tilt: \(error)")
                }
            })
        }
        
        print("📡 OSC Sent - Pan: \(pan)° → \(panAddress), Tilt: \(tilt)° → \(tiltAddress)")
    }
    
    func sendTestMessage(to address: String, value: Double) {
        guard isConnected, let connection = connection else {
            print("⚠️ OSC not connected - cannot send test message")
            return
        }
        
        let message = createOSCMessage(address: address, value: Float(value))
        connection.send(content: message, completion: .contentProcessed { error in
            if let error = error {
                print("❌ Failed to send test message: \(error)")
            } else {
                print("✅ Test message sent: \(address) = \(value)")
            }
        })
    }
    
    func testConnection() async -> Bool {
        // For now, just check if we're connected
        // Could be extended to send a test message and wait for response
        return isConnected
    }
    
    func resetPanTilt(panAddress: String, tiltAddress: String) {
        sendPanTilt(pan: 0.0, tilt: 0.0, panAddress: panAddress, tiltAddress: tiltAddress)
        print("🔄 OSC Reset pan/tilt to center")
    }
    
    // MARK: - OSC Message Creation
    private func createOSCMessage(address: String, value: Float) -> Data {
        var data = Data()
        
        // 1. OSC Address (null-terminated, padded to 4-byte boundary)
        let addressData = address.data(using: .utf8)!
        data.append(addressData)
        data.append(0) // null terminator
        
        // Pad to 4-byte boundary
        let addressPadding = (4 - (data.count % 4)) % 4
        for _ in 0..<addressPadding {
            data.append(0)
        }
        
        // 2. Type tag string ",f" (for one float argument)
        let typeTag = ",f".data(using: .utf8)!
        data.append(typeTag)
        data.append(0) // null terminator
        
        // Pad to 4-byte boundary
        let typePadding = (4 - (data.count % 4)) % 4
        for _ in 0..<typePadding {
            data.append(0)
        }
        
        // 3. Float argument (32-bit big-endian)
        var bigEndianValue = value.bitPattern.bigEndian
        let floatData = Data(bytes: &bigEndianValue, count: MemoryLayout<UInt32>.size)
        data.append(floatData)
        
        return data
    }
}
