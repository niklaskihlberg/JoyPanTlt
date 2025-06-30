//
//  MIDIService.swift
//  JoyPanTlt
//
//  Created by Niklas Kihlberg on 2025-06-29.
//

import Foundation
import CoreMIDI
import Combine

// MARK: - MIDI Service Implementation
class MIDIService: MIDIServiceProtocol {
    // MARK: - Published Properties
    @Published var isInitialized: Bool = false
    @Published var isEnabled: Bool = false
    @Published var availableDestinations: [(name: String, id: String)] = []
    @Published var selectedDestinationID: String = ""
    
    // MARK: - Private Properties
    private var midiClient: MIDIClientRef = 0
    private var outputPort: MIDIPortRef = 0
    private var virtualPort: MIDIPortRef = 0
    private var selectedEndpoint: MIDIEndpointRef = 0
    private var hasVirtualPort = false
    
    // MARK: - Initialization
    init() {
        _ = initialize()
    }
    
    deinit {
        cleanup()
    }
    
    func initialize() -> Bool {
        guard !isInitialized else { return true }
        
        let status = MIDIClientCreate("JoyPanTlt-Client" as CFString, nil, nil, &midiClient)
        guard status == noErr else {
            print("❌ Failed to create MIDI client: \(status)")
            return false
        }
        
        let portStatus = MIDIOutputPortCreate(midiClient, "JoyPanTlt-Output" as CFString, &outputPort)
        guard portStatus == noErr else {
            print("❌ Failed to create MIDI output port: \(portStatus)")
            return false
        }
        
        // Create virtual port
        createVirtualPort()
        
        isInitialized = true
        refreshDestinations()
        
        print("✅ MIDI Service initialized")
        return true
    }
    
    private func createVirtualPort() {
        guard midiClient != 0 else { return }
        
        let status = MIDISourceCreate(midiClient, "JoyPanTlt Virtual Out" as CFString, &virtualPort)
        hasVirtualPort = (status == noErr)
        
        if hasVirtualPort {
            print("✅ Virtual MIDI port 'JoyPanTlt Virtual Out' created")
            // Add virtual port to destinations
            availableDestinations.append((name: "JoyPanTlt Virtual Out (Internal)", id: "virtual"))
        } else {
            print("❌ Failed to create virtual MIDI port")
        }
    }
    
    // MARK: - Destination Management
    func refreshDestinations() {
        // Keep virtual destination if it exists
        let virtualDestination = availableDestinations.first { $0.name.contains("Virtual Out") }
        availableDestinations.removeAll()
        
        if let virtual = virtualDestination {
            availableDestinations.append(virtual)
        }
        
        let numDestinations = MIDIGetNumberOfDestinations()
        
        for i in 0..<numDestinations {
            let endpoint = MIDIGetDestination(i)
            var cfName: Unmanaged<CFString>?
            let status = MIDIObjectGetStringProperty(endpoint, kMIDIPropertyName, &cfName)
            
            if status == noErr, let name = cfName?.takeRetainedValue() as String? {
                let id = "\(endpoint)"
                availableDestinations.append((name: name, id: id))
                
                if selectedDestinationID.isEmpty {
                    selectedDestinationID = id
                    selectedEndpoint = endpoint
                }
            }
        }
        
        print("🎵 Found \(availableDestinations.count) MIDI destinations")
    }
    
    func selectDestination(id: String) {
        selectedDestinationID = id
        
        if id == "virtual" {
            // Virtual port selected
            selectedEndpoint = 0 // Special case for virtual port
        } else {
            // Find the endpoint for this ID
            let numDestinations = MIDIGetNumberOfDestinations()
            for i in 0..<numDestinations {
                let endpoint = MIDIGetDestination(i)
                if "\(endpoint)" == id {
                    selectedEndpoint = endpoint
                    break
                }
            }
        }
        
        print("🎵 Selected MIDI destination: \(id)")
    }
    
    // MARK: - MIDI Output
    func sendControlChange(channel: UInt8, controller: UInt8, value: UInt8) {
        guard isInitialized else {
            print("⚠️ MIDI not initialized")
            return
        }
        
        let statusByte: UInt8 = 0xB0 + (channel & 0x0F)
        let midiData: [UInt8] = [statusByte, controller & 0x7F, value & 0x7F]
        
        // Create MIDI packet
        var packetList = MIDIPacketList()
        var packet = MIDIPacketListInit(&packetList)
        packet = MIDIPacketListAdd(&packetList, 1024, packet, 0, midiData.count, midiData)
        
        // Send to selected destination
        if selectedEndpoint != 0 {
            MIDISend(outputPort, selectedEndpoint, &packetList)
        }
        
        // Always send to virtual port if available
        if hasVirtualPort {
            MIDIReceived(virtualPort, &packetList)
        }
        
        print("🎵 MIDI CC sent: Ch\(channel + 1) CC\(controller) = \(value)")
    }
    
    func sendPanTilt(pan: Double, tilt: Double, config: JoystickMIDIConfig) {
        guard isEnabled else { return }
        
        // Convert degrees to MIDI values (0-127)
        let panMIDI = UInt8(max(0, min(127, (pan + 180) / 360 * 127)))
        let tiltMIDI = UInt8(max(0, min(127, (tilt + 90) / 180 * 127)))
        
        sendControlChange(
            channel: UInt8(config.panChannel - 1),
            controller: UInt8(config.panController),
            value: panMIDI
        )
        
        sendControlChange(
            channel: UInt8(config.tiltChannel - 1),
            controller: UInt8(config.tiltController),
            value: tiltMIDI
        )
    }
    
    func sendTestMessage() {
        guard isInitialized else {
            print("❌ MIDI not initialized or no destination selected")
            return
        }
        
        print("🧪 Testing MIDI output...")
        sendControlChange(channel: 0, controller: 1, value: 64)
        sendControlChange(channel: 0, controller: 2, value: 32)
        print("✅ Test MIDI messages sent")
    }
    
    // MARK: - Cleanup
    func cleanup() {
        if midiClient != 0 {
            MIDIClientDispose(midiClient)
            midiClient = 0
        }
        isInitialized = false
        print("🎵 MIDI Service cleaned up")
    }
}
