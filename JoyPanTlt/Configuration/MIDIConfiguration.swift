//
//  MIDIConfiguration.swift
//  JoyPanTlt
//
//  Created by Niklas Kihlberg on 2025-06-27.
//

import SwiftUI
import Combine
import CoreMIDI

// MARK: - MIDI Backend
class MIDIBackend: ObservableObject {
  private var midiClient: MIDIClientRef = 0
  private var outputPort: MIDIPortRef = 0
  private var virtualPort: MIDIPortRef = 0  // NY: Virtuell port
  private var destinations: [MIDIEndpointRef] = []
  
  @Published var isInitialized = false
  @Published var availableDestinations: [(name: String, endpoint: MIDIEndpointRef)] = []
  @Published var selectedDestination: MIDIEndpointRef = 0
  @Published var hasVirtualPort = false  // NY: Status för virtuell port
  
  var onStatusChanged: ((Bool, String) -> Void)?
  
  init() {
    initializeMIDI()
    createVirtualPort()  // NY: Skapa virtuell port
    scanForDestinations()
  }
  
  private func initializeMIDI() {
    let status = MIDIClientCreate("JoyPanTlt-Client" as CFString, nil, nil, &midiClient)
    if status == noErr {
      let portStatus = MIDIOutputPortCreate(midiClient, "JoyPanTlt-Output" as CFString, &outputPort)
      isInitialized = (portStatus == noErr)
      print(isInitialized ? "✅ MIDI initialized" : "❌ MIDI failed")
    }
  }
  
  // NY: Skapa virtuell MIDI-port
  private func createVirtualPort() {
    guard midiClient != 0 else { return }
    
    let status = MIDISourceCreate(midiClient, "JoyPanTlt Virtual Out" as CFString, &virtualPort)
    hasVirtualPort = (status == noErr)
    
    if hasVirtualPort {
      print("✅ Virtual MIDI port 'JoyPanTlt Virtual Out' created")
      // Lägg till virtuell port i destinations
      availableDestinations.append((name: "JoyPanTlt Virtual Out (Internal)", endpoint: virtualPort))
    } else {
      print("❌ Failed to create virtual MIDI port")
    }
  }
  
  private func scanForDestinations() {
    // Behåll virtuell port om den finns
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
        availableDestinations.append((name: name, endpoint: endpoint))
        if selectedDestination == 0 {
          selectedDestination = endpoint
        }
      }
    }
  }
  
  func sendControlChange(channel: UInt8, controller: UInt8, value: UInt8) {
    guard isInitialized else { return }
    
    let statusByte: UInt8 = 0xB0 + (channel & 0x0F)
    let midiData: [UInt8] = [statusByte, controller & 0x7F, value & 0x7F]
    
    // Skicka till både vanlig port och virtuell port
    var packetList = MIDIPacketList()
    var packet = MIDIPacketListInit(&packetList)
    packet = MIDIPacketListAdd(&packetList, 1024, packet, 0, midiData.count, midiData)
    
    // Skicka till vald destination
    if selectedDestination != 0 {
      MIDISend(outputPort, selectedDestination, &packetList)
    }
    
    // Skicka alltid till virtuell port om den finns
    if hasVirtualPort {
      MIDIReceived(virtualPort, &packetList)
    }
  }
  
  func sendPanTilt(panChannel: UInt8, panController: UInt8, panValue: Double,
                   tiltChannel: UInt8, tiltController: UInt8, tiltValue: Double) {
    let panMIDI = UInt8(max(0, min(127, (panValue + 180) / 360 * 127)))
    let tiltMIDI = UInt8(max(0, min(127, tiltValue / 90 * 127)))
    
    sendControlChange(channel: panChannel, controller: panController, value: panMIDI)
    sendControlChange(channel: tiltChannel, controller: tiltController, value: tiltMIDI)
  }
  
  func refreshDestinations() {
    scanForDestinations()
  }
  
  func selectDestination(named name: String) {
    if let destination = availableDestinations.first(where: { $0.name == name }) {
      selectedDestination = destination.endpoint
    }
  }
  
  func testMIDI() {
    guard isInitialized, selectedDestination != 0 else {
      print("❌ MIDI not initialized or no destination selected")
      return
    }
    
    print("🧪 Testing MIDI output...")
    // Send test CC messages
    sendControlChange(channel: 0, controller: 1, value: 64)
    sendControlChange(channel: 0, controller: 2, value: 32)
    print("✅ Test MIDI messages sent")
  }
}

// MARK: - MIDI Configuration (uppdaterad för multi-joystick)
class MIDIConfiguration: ObservableObject {
  @Published var isEnabled: Bool = false
  @Published var selectedDestinationName: String = ""
  
  // Multi-joystick configurations
  @Published var joystickConfigs: [JoystickMIDIConfig] = []
  
  let backend = MIDIBackend()
  
  init() {
    backend.onStatusChanged = { _, status in
      print("🎵 MIDI: \(status)")
    }
    initializeJoystickConfigs()
  }
  
  private func initializeJoystickConfigs() {
    // Skapa default konfiguration för första joysticken
    if joystickConfigs.isEmpty {
      joystickConfigs.append(JoystickMIDIConfig(
        name: "Joystick 1",
        panChannel: 1,
        panController: 1,
        tiltChannel: 1,
        tiltController: 2
      ))
    }
  }
  
  func updateForNumberOfJoysticks(_ count: Int) {
    let currentCount = joystickConfigs.count
    
    // FIX: Förbättrad logging och hantering
    print("🎵 MIDI: Uppdaterar från \(currentCount) till \(count) joysticks")
    
    if count > currentCount {
      // Lägg till nya joystick-konfigurationer
      for i in currentCount..<count {
        let newConfig = JoystickMIDIConfig(
          name: "Joystick \(i + 1)",
          panChannel: i + 1,
          panController: (i * 2) + 1,
          tiltChannel: i + 1,
          tiltController: (i * 2) + 2
        )
        joystickConfigs.append(newConfig)
        print("🎵 MIDI: Lade till konfiguration för Joystick \(i + 1)")
      }
    } else if count < currentCount {
      // Ta bort extra konfigurationer
      let removedConfigs = joystickConfigs.suffix(currentCount - count)
      joystickConfigs = Array(joystickConfigs.prefix(count))
      print("🎵 MIDI: Tog bort \(removedConfigs.count) joystick-konfigurationer")
    }
    
    // FIX: Notifiera om ändringar för att uppdatera UI
    DispatchQueue.main.async {
      self.objectWillChange.send()
    }
  }
  
  func sendPanTilt(pan: Double, tilt: Double, forJoystick index: Int = 0) {
    guard isEnabled, index < joystickConfigs.count else { return }
    
    let config = joystickConfigs[index]
    backend.sendPanTilt(
      panChannel: UInt8(config.panChannel - 1),
      panController: UInt8(config.panController),
      panValue: pan,
      tiltChannel: UInt8(config.tiltChannel - 1),
      tiltController: UInt8(config.tiltController),
      tiltValue: tilt
    )
  }
  
  func refreshDestinations() {
    backend.refreshDestinations()
  }
  
  func selectDestination(_ name: String) {
    selectedDestinationName = name
    backend.selectDestination(named: name)
  }
  
  func testMIDI() {
    backend.testMIDI()
  }
  
  func resetToDefaults() {
    for i in 0..<joystickConfigs.count {
      joystickConfigs[i] = JoystickMIDIConfig(
        name: "Joystick \(i + 1)",
        panChannel: i + 1,
        panController: (i * 2) + 1,
        tiltChannel: i + 1,
        tiltController: (i * 2) + 2
      )
    }
    isEnabled = false
    selectedDestinationName = ""
    
    print("🔄 MIDI settings reset to defaults")
  }
}

