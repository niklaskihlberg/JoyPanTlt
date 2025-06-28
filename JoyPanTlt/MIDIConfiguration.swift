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

// NY: MIDI-konfiguration per joystick
struct JoystickMIDIConfig {
  var name: String
  var panChannel: Int
  var panController: Int
  var tiltChannel: Int
  var tiltController: Int
}

// MARK: - Uppdaterad MIDI Settings View
struct MIDISettingsView: View {
  @StateObject private var midiManager = MIDIManager.shared
  @StateObject private var virtualJoystickManager = VirtualJoystickManager.shared
  @State private var selectedJoystickIndex = 0
  
  var body: some View {
    VStack(spacing: 0) {
      // Enable MIDI checkbox
      enableMIDISection
      
      // MIDI destination dropdown
      destinationSection
      
      // Virtual joystick flikar
      multiJoystickTabView
    }
    .navigationTitle("MIDI Settings")
    .onAppear {
      // Uppdatera antal joystick-konfigurationer
      midiManager.configuration.updateForNumberOfJoysticks(
        virtualJoystickManager.configuration.numberOfJoysticks
      )
      
      // Auto-select first destination if none selected
      if midiManager.configuration.selectedDestinationName.isEmpty,
         let firstDestination = midiManager.configuration.backend.availableDestinations.first {
        midiManager.configuration.selectDestination(firstDestination.name)
      }
    }
  }
  
  // Enable MIDI sektion
  private var enableMIDISection: some View {
    VStack(spacing: 16) {
      HStack {
        Text("Enable MIDI:")
          .font(.headline)
        Toggle("", isOn: $midiManager.configuration.isEnabled)
          .padding(/*@START_MENU_TOKEN@*/.bottom, 5.0/*@END_MENU_TOKEN@*/)
        Spacer()
      }
      .padding(.horizontal, 20)
      .padding(.vertical, 16)
      
    }
  }
  
  // MIDI destination sektion
  private var destinationSection: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack {
        Text("MIDI Destination:")
          .font(.headline)
          .frame(width: 112)
        
        if midiManager.configuration.backend.availableDestinations.isEmpty {
          Text("No MIDI destinations found")
            .foregroundColor(.red)
        } else {
          Picker("", selection: $midiManager.configuration.selectedDestinationName){
            ForEach(midiManager.configuration.backend.availableDestinations, id: \.name) { destination in
              Text(destination.name)
                .tag(destination.name)
            }
          }
          .frame(width: 256)
          .pickerStyle(MenuPickerStyle())
          .onTapGesture {
            // Automatisk refresh när dropdown öppnas
            midiManager.configuration.refreshDestinations()
          }
          .onChange(of: midiManager.configuration.selectedDestinationName) { _, newValue in
            midiManager.configuration.selectDestination(newValue)
          }
          Spacer()
        }
      }
      .padding(.horizontal, 20)
      .padding(.bottom, 16)
      
    }
  }
  
  // Virtual joystick flikar
  private var multiJoystickTabView: some View {
    TabView(selection: $selectedJoystickIndex) {
      ForEach(0..<max(1, virtualJoystickManager.configuration.numberOfJoysticks), id: \.self) { index in
        joystickConfigurationView(for: index)
          .tabItem {
            Image(systemName: "gamecontroller.fill")
            Text("Joystick \(index + 1)")
          }
          .tag(index)
      }
    }
    .frame(minHeight: 300)
    // FIX: Enkel validering av selectedJoystickIndex
    .onChange(of: virtualJoystickManager.configuration.numberOfJoysticks) { _, newCount in
      if selectedJoystickIndex >= newCount {
        selectedJoystickIndex = max(0, newCount - 1)
      }
    }
  }
  
  // Joystick-specifik konfiguration med enkel layout (alignad till top)
  private func joystickConfigurationView(for index: Int) -> some View {
    VStack(alignment: .leading, spacing: 24) {
      if index < midiManager.configuration.joystickConfigs.count {
        let config = midiManager.configuration.joystickConfigs[index]
        
        // Pan sektion
        VStack(alignment: .leading, spacing: 12) {
          Text("Pan (X-axis)")
            .font(.headline)
          
          HStack {
            Text("MIDI Channel:")
              .frame(width: 112, alignment: .leading)
            Picker("", selection: Binding(
              get: { config.panChannel },
              set: { midiManager.configuration.joystickConfigs[index].panChannel = $0 }
            )) {
              ForEach(1...16, id: \.self) { channel in
                Text("Channel \(channel)")
                  .tag(channel)
              }
            }
            .pickerStyle(MenuPickerStyle())
            .frame(width: 256)
          }
          
          HStack {
            Text("MIDI CC:")
              .frame(width: 120, alignment: .leading)
            TextField("CC", value: Binding(
              get: { config.panController },
              set: { midiManager.configuration.joystickConfigs[index].panController = $0 }
            ), format: .number)
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .frame(width: 64)
            
            Text("(CC\(config.panController))")
              .foregroundColor(.secondary)
          }
        }
        
        // Tilt sektion
        VStack(alignment: .leading, spacing: 12) {
          Text("Tilt (Y-axis)")
            .font(.headline)
          
          HStack {
            Text("MIDI Channel:")
              .frame(width: 112, alignment: .leading)
            Picker("", selection: Binding(
              get: { config.tiltChannel },
              set: { midiManager.configuration.joystickConfigs[index].tiltChannel = $0 }
            )) {
              ForEach(1...16, id: \.self) { channel in
                Text("Channel \(channel)")
                  .tag(channel)
              }
            }
            .pickerStyle(MenuPickerStyle())
            .frame(width: 256)
          }
          
          HStack {
            Text("MIDI CC:")
              .frame(width: 120, alignment: .leading)
            TextField("CC", value: Binding(
              get: { config.tiltController },
              set: { midiManager.configuration.joystickConfigs[index].tiltController = $0 }
            ), format: .number)
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .frame(width: 64)
            
            Text("(CC\(config.tiltController))")
              .foregroundColor(.secondary)
          }
        }
        
        // Reset knapp
        HStack {
          Spacer()
          Button("Reset to Defaults") {
            resetJoystickToDefaults(index: index)
          }
          .foregroundColor(.blue)
        }
        
        // FIX: Lägg till Spacer för att pusha allt till toppen
        Spacer()
      }
    }
    .padding(20)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top) // FIX: Top alignment
  }
  
  private func resetJoystickToDefaults(index: Int) {
    guard index < midiManager.configuration.joystickConfigs.count else { return }
    
    midiManager.configuration.joystickConfigs[index] = JoystickMIDIConfig(
      name: "Joystick \(index + 1)",
      panChannel: index + 1,
      panController: (index * 2) + 1,
      tiltChannel: index + 1,
      tiltController: (index * 2) + 2
    )
    
    print("🔄 MIDI settings for Joystick \(index + 1) reset to defaults")
  }
}

// MARK: - Uppdaterad MIDI Manager
class MIDIManager: ObservableObject {
  static let shared = MIDIManager()
  
  @Published var configuration = MIDIConfiguration()
  
  private init() {
    // FIX: Registrera callback för när virtual joystick-konfiguration ändras
    VirtualJoystickManager.shared.onJoystickConfigurationChanged = { [weak self] newCount in
      print("🎵 MIDIManager: Fick callback om \(newCount) joysticks - uppdaterar konfiguration")
      self?.configuration.updateForNumberOfJoysticks(newCount)
    }
  }
  
  func updatePanTilt(pan: Double, tilt: Double, forJoystick index: Int = 0) {
    configuration.sendPanTilt(pan: pan, tilt: tilt, forJoystick: index)
  }
  
  func toggleMIDI() {
    configuration.isEnabled.toggle()
  }
}

// MARK: - MIDI Settings Preview
struct MIDISettingsView_Previews: PreviewProvider {
  static var previews: some View {
    MIDISettingsView()
      .frame(width: 600, height: 500)
  }
}
