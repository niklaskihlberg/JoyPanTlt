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
  private var destinations: [MIDIEndpointRef] = []
  
  // Status tracking
  @Published var isInitialized = false
  @Published var availableDestinations: [(name: String, endpoint: MIDIEndpointRef)] = []
  @Published var selectedDestination: MIDIEndpointRef = 0
  
  // Callback för status changes
  var onStatusChanged: ((Bool, String) -> Void)?
  
  init() {
    initializeMIDI()
    scanForDestinations()
  }
  
  deinit {
    cleanup()
  }
  
  // MARK: - MIDI Initialization
  
  private func initializeMIDI() {
    let status = MIDIClientCreate("JoyPanTlt-Client" as CFString, nil, nil, &midiClient)
    
    if status == noErr {
      let portStatus = MIDIOutputPortCreate(midiClient, "JoyPanTlt-Output" as CFString, &outputPort)
      
      if portStatus == noErr {
        isInitialized = true
        onStatusChanged?(true, "MIDI initialized successfully")
        print("✅ MIDI Client and Output Port created successfully")
      } else {
        isInitialized = false
        onStatusChanged?(false, "Failed to create MIDI output port: \(portStatus)")
        print("❌ Failed to create MIDI output port: \(portStatus)")
      }
    } else {
      isInitialized = false
      onStatusChanged?(false, "Failed to create MIDI client: \(status)")
      print("❌ Failed to create MIDI client: \(status)")
    }
  }
  
  private func scanForDestinations() {
    availableDestinations.removeAll()
    
    let numDestinations = MIDIGetNumberOfDestinations()
    print("🔍 Found \(numDestinations) MIDI destinations")
    
    for i in 0..<numDestinations {
      let endpoint = MIDIGetDestination(i)
      
      var cfName: Unmanaged<CFString>?
      let status = MIDIObjectGetStringProperty(endpoint, kMIDIPropertyName, &cfName)
      
      if status == noErr, let name = cfName?.takeRetainedValue() as String? {
        availableDestinations.append((name: name, endpoint: endpoint))
        print("📍 MIDI Destination: \(name)")
        
        // Auto-select first destination if none selected
        if selectedDestination == 0 {
          selectedDestination = endpoint
        }
      }
    }
    
    onStatusChanged?(true, "Found \(availableDestinations.count) MIDI destinations")
  }
  
  private func cleanup() {
    if outputPort != 0 {
      MIDIPortDispose(outputPort)
    }
    if midiClient != 0 {
      MIDIClientDispose(midiClient)
    }
  }
  
  // MARK: - MIDI Message Sending
  
  func sendControlChange(channel: UInt8, controller: UInt8, value: UInt8) {
    guard isInitialized, selectedDestination != 0 else {
      print("⚠️ MIDI not initialized or no destination selected")
      return
    }
    
    // MIDI Control Change: Status (0xB0 + channel), Controller, Value
    let statusByte: UInt8 = 0xB0 + (channel & 0x0F)
    let midiData: [UInt8] = [statusByte, controller & 0x7F, value & 0x7F]
    
    sendMIDIData(midiData)
  }
  
  func sendPitchBend(channel: UInt8, value: Int16) {
    guard isInitialized, selectedDestination != 0 else {
      print("⚠️ MIDI not initialized or no destination selected")
      return
    }
    
    // MIDI Pitch Bend: Status (0xE0 + channel), LSB, MSB
    // value range: -8192 to +8191, offset by 8192 to get 0-16383
    let pitchValue = UInt16(value + 8192)
    let lsb = UInt8(pitchValue & 0x7F)
    let msb = UInt8((pitchValue >> 7) & 0x7F)
    
    let statusByte: UInt8 = 0xE0 + (channel & 0x0F)
    let midiData: [UInt8] = [statusByte, lsb, msb]
    
    sendMIDIData(midiData)
  }
  
  func sendPanTilt(panChannel: UInt8, panController: UInt8, panValue: Double,
                   tiltChannel: UInt8, tiltController: UInt8, tiltValue: Double) {
    
    // Convert pan/tilt values (-180 to +180 for pan, 0 to 90 for tilt) to MIDI (0-127)
    let panMIDI = UInt8(max(0, min(127, (panValue + 180) / 360 * 127)))
    let tiltMIDI = UInt8(max(0, min(127, tiltValue / 90 * 127)))
    
    sendControlChange(channel: panChannel, controller: panController, value: panMIDI)
    sendControlChange(channel: tiltChannel, controller: tiltController, value: tiltMIDI)
    
    print("📡 MIDI Sent - Pan: \(panValue)° → CC\(panController)=\(panMIDI), Tilt: \(tiltValue)° → CC\(tiltController)=\(tiltMIDI)")
  }
  
  private func sendMIDIData(_ data: [UInt8]) {
    var packetList = MIDIPacketList()
    var packet = MIDIPacketListInit(&packetList)
    
    packet = MIDIPacketListAdd(&packetList, 1024, packet, 0, data.count, data)
    
    let status = MIDISend(outputPort, selectedDestination, &packetList)
    
    if status != noErr {
      print("❌ Failed to send MIDI data: \(status)")
    }
  }
  
  // MARK: - Public Methods
  
  func refreshDestinations() {
    scanForDestinations()
  }
  
  func selectDestination(named name: String) {
    if let destination = availableDestinations.first(where: { $0.name == name }) {
      selectedDestination = destination.endpoint
      print("🎯 Selected MIDI destination: \(name)")
    }
  }
  
  func testMIDI() {
    print("🧪 Testing MIDI output...")
    
    // Send test Control Change messages
    sendControlChange(channel: 0, controller: 1, value: 64)  // Modulation wheel center
    sendControlChange(channel: 0, controller: 7, value: 100) // Volume high
    
    // Send test Pitch Bend
    sendPitchBend(channel: 0, value: 0) // Center pitch
    
    print("🧪 MIDI test messages sent")
  }
}

// MARK: - MIDI Configuration
class MIDIConfiguration: ObservableObject {
  @Published var isEnabled: Bool = false
  @Published var panChannel: Int = 1
  @Published var panController: Int = 1
  @Published var tiltChannel: Int = 1
  @Published var tiltController: Int = 2
  @Published var selectedDestinationName: String = ""
  
  // MIDI Backend
  let backend = MIDIBackend()
  
  init() {
    setupBackendCallbacks()
  }
  
  private func setupBackendCallbacks() {
    // Ta bort [weak self] eftersom vi inte använder self i closure
    backend.onStatusChanged = { isConnected, status in
      DispatchQueue.main.async {
        print("🎵 MIDI Status: \(status)")
      }
    }
  }
  
  // MARK: - Public Interface
  
  func sendPanTilt(pan: Double, tilt: Double) {
    guard isEnabled else {
      print("⚠️ MIDI output disabled")
      return
    }
    
    backend.sendPanTilt(
      panChannel: UInt8(panChannel - 1), // Convert 1-16 to 0-15
      panController: UInt8(panController),
      panValue: pan,
      tiltChannel: UInt8(tiltChannel - 1), // Convert 1-16 to 0-15
      tiltController: UInt8(tiltController),
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
    panChannel = 1
    panController = 1
    tiltChannel = 1
    tiltController = 2
    isEnabled = false
    selectedDestinationName = ""
    
    print("🔄 MIDI settings reset to defaults")
  }
}

// MARK: - MIDI Manager Singleton
class MIDIManager: ObservableObject {
  static let shared = MIDIManager()
  
  @Published var configuration = MIDIConfiguration()
  
  private init() {}
  
  // MARK: - Convenience Methods
  
  func updatePanTilt(pan: Double, tilt: Double) {
    configuration.sendPanTilt(pan: pan, tilt: tilt)
  }
  
  func toggleMIDI() {
    configuration.isEnabled.toggle()
    print("🎵 MIDI output \(configuration.isEnabled ? "enabled" : "disabled")")
  }
  
  func updatePanTiltMulti(pan: Double, tilt: Double, channel: Int, panCC: Int, tiltCC: Int, joystickName: String) {
    // Implementation för multi-joystick MIDI
  }
}

// MARK: - MIDI Settings View
struct MIDISettingsView: View {
  @StateObject private var midiManager = MIDIManager.shared
  
  var body: some View {
    Form {
      Section("MIDI Output") {
        HStack {
          Text("Enable MIDI:")
            .frame(width: 100, alignment: .leading)
          Toggle("", isOn: $midiManager.configuration.isEnabled)
          
          Spacer()
          
          Button("Refresh Destinations") {
            midiManager.configuration.refreshDestinations()
          }
        }
        
        HStack {
          Text("Destination:")
            .frame(width: 100, alignment: .leading)
          
          if midiManager.configuration.backend.availableDestinations.isEmpty {
            Text("No MIDI destinations found")
              .foregroundColor(.red)
          } else {
            Picker("MIDI Destination", selection: $midiManager.configuration.selectedDestinationName) {
              ForEach(midiManager.configuration.backend.availableDestinations, id: \.name) { destination in
                Text(destination.name)
                  .tag(destination.name)
              }
            }
            .pickerStyle(MenuPickerStyle())
            .onChange(of: midiManager.configuration.selectedDestinationName) { oldValue, newValue in
              midiManager.configuration.selectDestination(newValue)
            }
          }
        }
        
        HStack {
          Text("Status:")
            .frame(width: 100, alignment: .leading)
          Text(midiManager.configuration.backend.isInitialized ? "Initialized" : "Not initialized")
            .foregroundColor(midiManager.configuration.backend.isInitialized ? .green : .red)
        }
      }
      
      Section("Pan Configuration") {
        HStack {
//          Text("MIDI Channel:")
//            .frame(width: 100, alignment: .leading)
          Picker("Pan MIDI Channel", selection: $midiManager.configuration.panChannel) {
            ForEach(1...16, id: \.self) { channel in
              Text("Channel \(channel)")
                .tag(channel)
            }
          }
          .pickerStyle(MenuPickerStyle())
          .frame(width: 240.0)
        }
        
        HStack {
          Text("Controller:")
            .frame(width: 100, alignment: .leading)
          TextField("1", text: Binding(
            get: { String(midiManager.configuration.panController) },
            set: { midiManager.configuration.panController = Int($0) ?? 1 }
          ))
          .textFieldStyle(RoundedBorderTextFieldStyle())
          .frame(width: 60)
          
          Text("(CC\(midiManager.configuration.panController))")
            .foregroundColor(.secondary)
        }
      }
      
      Section("Tilt Configuration") {
        HStack {
//          Text("MIDI Channel:")
//            .frame(width: 100, alignment: .leading)
          Picker("Tilt MIDI Channel", selection: $midiManager.configuration.tiltChannel) {
            ForEach(1...16, id: \.self) { channel in
              Text("Channel \(channel)")
                .tag(channel)
            }
          }
          .pickerStyle(MenuPickerStyle())
          .frame(width: 240)
        }
        
        HStack {
          Text("Controller:")
            .frame(width: 100, alignment: .leading)
          TextField("2", text: Binding(
            get: { String(midiManager.configuration.tiltController) },
            set: { midiManager.configuration.tiltController = Int($0) ?? 2 }
          ))
          .textFieldStyle(RoundedBorderTextFieldStyle())
          .frame(width: 60)
          
          Text("(CC\(midiManager.configuration.tiltController))")
            .foregroundColor(.secondary)
        }
      }
      
      Section("Test & Debug") {
        VStack(alignment: .leading, spacing: 10) {
          HStack {
            Button("Test MIDI Output") {
              midiManager.configuration.testMIDI()
            }
            .disabled(!midiManager.configuration.isEnabled)
            
            Button("Send Test Pan/Tilt") {
              midiManager.updatePanTilt(pan: 45.0, tilt: 30.0)
            }
            .disabled(!midiManager.configuration.isEnabled)
          }
          
          Button("Reset to Defaults") {
            midiManager.configuration.resetToDefaults()
          }
        }
      }
      
      Section("Configuration Info") {
        VStack(alignment: .leading, spacing: 8) {
          HStack {
            Text("MIDI Output:")
              .fontWeight(.medium)
            Spacer()
            Text(midiManager.configuration.isEnabled ? "Enabled" : "Disabled")
              .foregroundColor(midiManager.configuration.isEnabled ? .green : .red)
          }
          
          HStack {
            Text("Destination:")
              .fontWeight(.medium)
            Spacer()
            Text(midiManager.configuration.selectedDestinationName.isEmpty ? "None" : midiManager.configuration.selectedDestinationName)
              .foregroundColor(.secondary)
          }
          
          HStack {
            Text("Pan Mapping:")
              .fontWeight(.medium)
            Spacer()
            Text("Ch\(midiManager.configuration.panChannel) CC\(midiManager.configuration.panController)")
              .foregroundColor(.secondary)
          }
          
          HStack {
            Text("Tilt Mapping:")
              .fontWeight(.medium)
            Spacer()
            Text("Ch\(midiManager.configuration.tiltChannel) CC\(midiManager.configuration.tiltController)")
              .foregroundColor(.secondary)
          }
          
          HStack {
            Text("Available Destinations:")
              .fontWeight(.medium)
            Spacer()
            Text("\(midiManager.configuration.backend.availableDestinations.count)")
              .foregroundColor(.secondary)
          }
        }
      }
    }
    .padding()
    .navigationTitle("MIDI Settings")
    .onAppear {
      // Auto-select first destination if none selected
      if midiManager.configuration.selectedDestinationName.isEmpty,
         let firstDestination = midiManager.configuration.backend.availableDestinations.first {
        midiManager.configuration.selectDestination(firstDestination.name)
      }
    }
  }
}

// MARK: - Preview-specifik View
struct MIDISettingsPreviewView: View {
    @StateObject private var mockManager = MockMIDIManager()
    
    var body: some View {
        Form {
            Section("MIDI Output") {
                HStack {
                    Text("Enable MIDI:")
                        .frame(width: 100, alignment: .leading)
                    Toggle("", isOn: $mockManager.configuration.isEnabled)
                    
                    Spacer()
                    
                    Button("Refresh Destinations") {
                        mockManager.configuration.refreshDestinations()
                    }
                }
                
                HStack {
                    Text("Destination:")
                        .frame(width: 100, alignment: .leading)
                    
                    Picker("MIDI Destination", selection: $mockManager.configuration.selectedDestinationName) {
                        ForEach(mockManager.configuration.backend.availableDestinations, id: \.name) { destination in
                            Text(destination.name)
                                .tag(destination.name)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                HStack {
                    Text("Status:")
                        .frame(width: 100, alignment: .leading)
                    Text("Initialized")
                        .foregroundColor(.green)
                }
            }
            
            Section("Pan Configuration") {
                HStack {
                    Picker("Pan MIDI Channel", selection: $mockManager.configuration.panChannel) {
                        ForEach(1...16, id: \.self) { channel in
                            Text("Channel \(channel)")
                                .tag(channel)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(width: 240)
                }
                
                HStack {
                    Text("Controller:")
                        .frame(width: 100, alignment: .leading)
                    TextField("1", text: Binding(
                        get: { String(mockManager.configuration.panController) },
                        set: { mockManager.configuration.panController = Int($0) ?? 1 }
                    ))
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 60)
                    
                    Text("(CC\(mockManager.configuration.panController))")
                        .foregroundColor(.secondary)
                }
            }
            
            Section("Tilt Configuration") {
                HStack {
                    Picker("Tilt MIDI Channel", selection: $mockManager.configuration.tiltChannel) {
                        ForEach(1...16, id: \.self) { channel in
                            Text("Channel \(channel)")
                                .tag(channel)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(width: 240)
                }
                
                HStack {
                    Text("Controller:")
                        .frame(width: 100, alignment: .leading)
                    TextField("2", text: Binding(
                        get: { String(mockManager.configuration.tiltController) },
                        set: { mockManager.configuration.tiltController = Int($0) ?? 2 }
                    ))
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 60)
                    
                    Text("(CC\(mockManager.configuration.tiltController))")
                        .foregroundColor(.secondary)
                }
            }
            
            Section("Test & Debug") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Button("Test MIDI Output") {
                            mockManager.configuration.testMIDI()
                        }
                        .disabled(!mockManager.configuration.isEnabled)
                        
                        Button("Send Test Pan/Tilt") {
                            mockManager.updatePanTilt(pan: 45.0, tilt: 30.0)
                        }
                        .disabled(!mockManager.configuration.isEnabled)
                    }
                    
                    Button("Reset to Defaults") {
                        mockManager.configuration.resetToDefaults()
                    }
                }
            }
            
            Section("Configuration Info") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("MIDI Output:")
                            .fontWeight(.medium)
                        Spacer()
                        Text(mockManager.configuration.isEnabled ? "Enabled" : "Disabled")
                            .foregroundColor(mockManager.configuration.isEnabled ? .green : .red)
                    }
                    
                    HStack {
                        Text("Destination:")
                            .fontWeight(.medium)
                        Spacer()
                        Text(mockManager.configuration.selectedDestinationName)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Pan Mapping:")
                            .fontWeight(.medium)
                        Spacer()
                        Text("Ch\(mockManager.configuration.panChannel) CC\(mockManager.configuration.panController)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Tilt Mapping:")
                            .fontWeight(.medium)
                        Spacer()
                        Text("Ch\(mockManager.configuration.tiltChannel) CC\(mockManager.configuration.tiltController)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Available Destinations:")
                            .fontWeight(.medium)
                        Spacer()
                        Text("\(mockManager.configuration.backend.availableDestinations.count)")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .navigationTitle("MIDI Settings")
    }
}

// MARK: - MIDI Settings Preview (uppdaterad)
struct MIDISettingsView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Mock version för bättre design (interaktiv)
            MIDISettingsPreviewView()
                .previewDisplayName("MIDI Settings - Interactive")
                .frame(width: 600, height: 500)
            
            // Dark mode version
            MIDISettingsPreviewView()
                .previewDisplayName("MIDI Settings - Dark")
                .frame(width: 600, height: 500)
                .preferredColorScheme(.dark)
            
            // Använd den riktiga MIDISettingsView (kan vara mindre stabil)
            MIDISettingsView()
                .previewDisplayName("MIDI Settings - Real")
                .frame(width: 600, height: 500)
        }
    }
}


// MARK: - Mock MIDI Manager för Preview
class MockMIDIManager: ObservableObject {
    @Published var configuration = MockMIDIConfiguration()
    
    func updatePanTilt(pan: Double, tilt: Double) {
        print("Mock MIDI: Pan \(pan)°, Tilt \(tilt)°")
    }
    
    func toggleMIDI() {
        configuration.isEnabled.toggle()
    }
}

class MockMIDIConfiguration: ObservableObject {
    @Published var isEnabled: Bool = true
    @Published var panChannel: Int = 1
    @Published var panController: Int = 1
    @Published var tiltChannel: Int = 1
    @Published var tiltController: Int = 2
    @Published var selectedDestinationName: String = "Logic Pro Virtual In"
    
    let backend = MockMIDIBackend()
    
    func sendPanTilt(pan: Double, tilt: Double) {
        print("Mock sendPanTilt: \(pan), \(tilt)")
    }
    
    func refreshDestinations() {
        print("Mock refresh destinations")
    }
    
    func selectDestination(_ name: String) {
        selectedDestinationName = name
    }
    
    func testMIDI() {
        print("Mock test MIDI")
    }
    
    func resetToDefaults() {
        panChannel = 1
        panController = 1
        tiltChannel = 1
        tiltController = 2
        isEnabled = false
        selectedDestinationName = ""
    }
}

class MockMIDIBackend: ObservableObject {
    @Published var isInitialized = true
    @Published var availableDestinations: [(name: String, endpoint: MIDIEndpointRef)] = [
        (name: "Logic Pro Virtual In", endpoint: 1),
        (name: "MainStage Virtual In", endpoint: 2),
        (name: "Ableton Live Virtual In", endpoint: 3),
        (name: "MIDI Network Session", endpoint: 4),
        (name: "Hardware MIDI Device", endpoint: 5)
    ]
    @Published var selectedDestination: MIDIEndpointRef = 1
}


