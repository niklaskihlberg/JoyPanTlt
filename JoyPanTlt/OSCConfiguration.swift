//
//  OSCConfiguration.swift
//  JoyPanTlt
//
//  Created by Niklas Kihlberg on 2025-06-25.
//

import SwiftUI
import Combine
import Network

// MARK: - OSCBackend (implementerad direkt här)
class OSCBackend {
    private var connection: NWConnection?
    private var isConnected = false
    
    // Callback för connection state changes
    var onConnectionStateChanged: ((Bool, String) -> Void)?
    
    init() {}
    
    // MARK: - Connection Management
    
    func connect(host: String, port: Int, usesTCP: Bool) {  // Lägg till usesTCP parameter
        disconnect() // Disconnect any existing connection
        
        let nwHost = NWEndpoint.Host(host)
        guard port > 0 && port <= 65535 else {
            notifyConnectionChange(false, "Invalid port: \(port)")
            return
        }
        
        let nwPort = NWEndpoint.Port(integerLiteral: UInt16(port))
        
        // Använd parameter istället för OSCConfiguration.shared
        let parameters: NWParameters = usesTCP ? .tcp : .udp
        connection = NWConnection(host: nwHost, port: nwPort, using: parameters)
        
        connection?.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                self?.handleConnectionState(state)
            }
        }
        
        connection?.start(queue: .global())
        notifyConnectionChange(false, "Connecting to \(host):\(port) via \(usesTCP ? "TCP" : "UDP")...")
        
        print("🔄 OSC Connecting to \(host):\(port) via \(usesTCP ? "TCP" : "UDP")")
    }
    
    func disconnect() {
        connection?.cancel()
        connection = nil
        isConnected = false
        notifyConnectionChange(false, "Disconnected")
        print("🔄 OSC Disconnected")
    }
    
    private func handleConnectionState(_ state: NWConnection.State) {
        switch state {
        case .ready:
            isConnected = true
            notifyConnectionChange(true, "Connected")
            print("✅ OSC Connected")
            
        case .failed(let error):
            isConnected = false
            notifyConnectionChange(false, "Failed: \(error.localizedDescription)")
            print("❌ OSC Connection failed: \(error)")
            
        case .cancelled:
            isConnected = false
            notifyConnectionChange(false, "Disconnected")
            print("🔄 OSC Connection cancelled")
            
        case .waiting(let error):
            isConnected = false
            notifyConnectionChange(false, "Waiting: \(error.localizedDescription)")
            print("⏳ OSC Waiting: \(error)")
            
        default:
            break
        }
    }
    
    private func notifyConnectionChange(_ connected: Bool, _ status: String) {
        onConnectionStateChanged?(connected, status)
    }
    
    // MARK: - Message Sending
    
    func sendPanTilt(panAddress: String, panValue: Double, tiltAddress: String, tiltValue: Double) {
        guard isConnected, let connection = connection else {
            print("⚠️ OSC not connected - connection: \(connection != nil), isConnected: \(isConnected)")
            return
        }
        
        print("📡 Sending OSC to Lightkey:")
        print("  - Host: \(connection.endpoint)")
        print("  - Pan: \(panAddress) = \(panValue)")
        print("  - Tilt: \(tiltAddress) = \(tiltValue)")
        
        // Skicka pan-meddelande
        let panMessage = createOSCMessage(address: panAddress, value: Float(panValue))
        connection.send(content: panMessage, completion: .contentProcessed { error in
            if let error = error {
                print("❌ Failed to send pan: \(error)")
            } else {
                print("✅ Pan message sent successfully")
            }
        })
        
        // Liten delay mellan meddelanden (kan hjälpa med vissa OSC-servrar)
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.01) {
            // Skicka tilt-meddelande
            let tiltMessage = self.createOSCMessage(address: tiltAddress, value: Float(tiltValue))
            connection.send(content: tiltMessage, completion: .contentProcessed { error in
                if let error = error {
                    print("❌ Failed to send tilt: \(error)")
                } else {
                    print("✅ Tilt message sent successfully")
                }
            })
        }
    }
    
    // MARK: - OSC Message Creation
    
    func createOSCMessage(address: String, value: Float) -> Data {
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
        
        print("📦 OSC Message: \(address) = \(value)")
        print("📦 Data length: \(data.count) bytes")
        print("📦 Hex: \(data.map { String(format: "%02x", $0) }.joined(separator: " "))")
        
        return data
    }
    
    // MARK: - Test Connection
    
    func testConnection(host: String, port: Int, completion: @escaping (Bool) -> Void) {
        let testHost = NWEndpoint.Host(host)
        guard port > 0 && port <= 65535 else {
            completion(false)
            return
        }
        
        let testPort = NWEndpoint.Port(integerLiteral: UInt16(port))
        
        let testConnection = NWConnection(host: testHost, port: testPort, using: .udp)
        
        var hasCompleted = false
        
        testConnection.stateUpdateHandler = { state in
            guard !hasCompleted else { return }
            
            switch state {
            case .ready:
                hasCompleted = true
                print("✅ Test connection to \(host):\(port) successful")
                
                // Skicka test-meddelande
                let testMessage = self.createOSCMessage(address: "/test", value: 1.0)
                testConnection.send(content: testMessage, completion: .contentProcessed { error in
                    testConnection.cancel()
                    completion(error == nil)
                })
                
            case .failed(let error):
                hasCompleted = true
                print("❌ Test connection to \(host):\(port) failed: \(error)")
                testConnection.cancel()
                completion(false)
                
            default:
                break
            }
        }
        
        testConnection.start(queue: .global())
        
        // Timeout efter 3 sekunder
        DispatchQueue.global().asyncAfter(deadline: .now() + 3) {
            if !hasCompleted {
                hasCompleted = true
                testConnection.cancel()
                completion(false)
            }
        }
    }
    
    // MARK: - Debugging Network Connection
    func debugNetworkConnection() {
        print("🔍 Network Connection Debug:")
        print("  - Connection exists: \(connection != nil)")
        print("  - Is connected: \(isConnected)")
        
        if let conn = connection {
            print("  - Endpoint: \(conn.endpoint)")
            print("  - Parameters: \(conn.parameters)")
            print("  - State: \(conn.state)")
        }
        
        // Test basic network connectivity - använd säkrare port creation
        let testHost = NWEndpoint.Host("127.0.0.1")
        guard let testPort = NWEndpoint.Port(rawValue: 21600) else {
            print("❌ Invalid port number")
            return
        }
        
        let pathMonitor = NWPathMonitor()
        pathMonitor.pathUpdateHandler = { path in
            print("  - Network available: \(path.status == .satisfied)")
            print("  - Interfaces: \(path.availableInterfaces)")
            print("  - Uses expensive: \(path.isExpensive)")
            print("  - Uses constrained: \(path.isConstrained)")
            
            // Lista tillgängliga interfaces
            for interface in path.availableInterfaces {
                print("    - Interface: \(interface.name) (\(interface.type))")
            }
        }
        
        let queue = DispatchQueue(label: "NetworkMonitor")
        pathMonitor.start(queue: queue)
        
        // Test även en enkel connection
        let testConnection = NWConnection(host: testHost, port: testPort, using: .udp)
        testConnection.stateUpdateHandler = { state in
            print("  - Test connection state: \(state)")
        }
        testConnection.start(queue: queue)
        
        // Stop efter 5 sekunder
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            pathMonitor.cancel()
            testConnection.cancel()
            print("🔍 Network debug completed")
        }
    }
}

// MARK: - OSCConfiguration (lägg till shared)
class OSCConfiguration: ObservableObject {
    static let shared = OSCConfiguration()  // Lägg till denna rad
    
    @Published var host: String = "127.0.0.1"  // Eller Lightkey-datorns IP
    @Published var port: Int = 21600             // Lightkey's OSC port
    @Published var panAddress: String = "/fixture/selected/overrides/panAngle"
    @Published var tiltAddress: String = "/fixture/selected/overrides/tiltAngle"
    @Published var isConnected: Bool = false
    @Published var connectionStatus: String = "Disconnected"
    @Published var usesTCP: Bool = false  // NY: Välj TCP eller UDP
    
    // OSC Backend (nu implementerad ovan i samma fil)
    let backend = OSCBackend()
    
    init() {
        setupBackendCallbacks()
    }
    
    private func setupBackendCallbacks() {
        backend.onConnectionStateChanged = { [weak self] (isConnected: Bool, status: String) in
            DispatchQueue.main.async {
                self?.isConnected = isConnected
                self?.connectionStatus = status
            }
        }
    }
    
    // MARK: - Public Interface för ContentView
    
    /// Anslut till OSC-server
    func connect() {
        guard isValidConfiguration() else {
            print("❌ Invalid OSC configuration")
            return
        }
        
        // Skicka alla parametrar till backend
        backend.connect(host: host, port: port, usesTCP: usesTCP)
    }
    
    /// Koppla från OSC-server
    func disconnect() {
        backend.disconnect()
    }
    
    /// Skicka pan/tilt-värden via OSC
    func sendPanTilt(pan: Double, tilt: Double) {
        guard isConnected else {
            print("⚠️ OSC not connected - cannot send pan/tilt")
            return
        }
        
        backend.sendPanTilt(
            panAddress: panAddress,
            panValue: pan,
            tiltAddress: tiltAddress,
            tiltValue: tilt
        )
        
        print("📡 OSC Sent - Pan: \(pan)°, Tilt: \(tilt)°")
    }
    
    /// Reset pan/tilt till centrum (0, 0)
    func resetPanTilt() {
        sendPanTilt(pan: 0.0, tilt: 0.0)
    }
    
    /// Kontrollera om konfigurationen är giltig
    func isValidConfiguration() -> Bool {
        return !host.isEmpty && 
               port > 0 && 
               port <= 65535 && 
               !panAddress.isEmpty && 
               !tiltAddress.isEmpty
    }
    
    /// Få knapp-text för connect/disconnect
    func getConnectionButtonText() -> String {
        return isConnected ? "Disconnect OSC" : "Connect OSC"
    }
    
    /// Test olika portar för att hitta vilken som fungerar
    func testCommonPorts() {
        let commonPorts = [8000, 9000, 7001, 21600, 53000, 3333, 7777]
        
        print("🧪 Testing common OSC ports...")
        
        for testPort in commonPorts {
            backend.testConnection(host: host, port: testPort) { success in
                DispatchQueue.main.async {
                    if success {
                        print("✅ Port \(testPort) responded!")
                        self.port = testPort
                    } else {
                        print("❌ Port \(testPort) failed")
                    }
                }
            }
        }
    }
}

// MARK: - OSC Manager Singleton (förenklad)
class OSCManager: ObservableObject {
    static let shared = OSCManager()
    
    @Published var configuration = OSCConfiguration()
    
    private init() {}
    
    // MARK: - Convenience Methods för ContentView
    
    /// Uppdatera pan/tilt och skicka via OSC
    func updatePanTilt(pan: Double, tilt: Double) {
        configuration.sendPanTilt(pan: pan, tilt: tilt)
    }
    
    /// Reset pan/tilt till centrum
    func resetPanTilt() {
        configuration.resetPanTilt()
    }
    
    /// Toggle anslutning (connect/disconnect)
    func toggleConnection() {
        if configuration.isConnected {
            configuration.disconnect()
        } else {
            configuration.connect()
        }
    }
    
    /// Uppdatera pan/tilt för flera joysticks
    func updatePanTiltMulti(pan: Double, tilt: Double, address: String, joystickName: String) {
        // Implementation för multi-joystick OSC
    }
    
    /// Uppdatera pan/tilt med specifika adresser
    func updatePanTiltWithAddresses(pan: Double, tilt: Double, panAddress: String, tiltAddress: String) {
        configuration.backend.sendPanTilt(
            panAddress: panAddress,
            panValue: pan,
            tiltAddress: tiltAddress,
            tiltValue: tilt
        )
    }
}

// MARK: - OSC Settings View
struct OSCSettingsView: View {
  @StateObject private var oscManager = OSCManager.shared
  @StateObject private var virtualJoystickManager = VirtualJoystickManager.shared
  
  var body: some View {
    VStack(spacing: 0) {
      // OSC Connection Header
      OSCConnectionSection()
      
      Divider()
      
      // Joystick Mapping Tabs
      if virtualJoystickManager.configuration.numberOfJoysticks == 1 {
        // Single Joystick - no tabs needed
        SingleJoystickOSCSection()
          .padding()
      } else {
        // Multiple Joysticks - use tabs
        TabView {
          ForEach(Array(virtualJoystickManager.configuration.joystickInstances.enumerated()), id: \.element.id) { index, joystick in
            JoystickOSCSection(
              joystick: .constant(virtualJoystickManager.configuration.joystickInstances[index]),
              joystickNumber: index + 1
            )
            .tabItem {
              Image(systemName: "gamecontroller.fill")
              Text("Joystick \(index + 1)")
            }
          }
        }
        .frame(minHeight: 350)
      }
      
      Divider()
      
      // Test & Debug Section
      OSCTestSection()
        .padding()
    }
  }
}

// MARK: - OSC Connection Section
struct OSCConnectionSection: View {
  @StateObject private var oscManager = OSCManager.shared
  
  var body: some View {
    Form {
      Section("OSC Connection") {
        HStack {
          Text("Host:")
            .frame(width: 80, alignment: .leading)
          TextField("127.0.0.1", text: $oscManager.configuration.host)
            .textFieldStyle(RoundedBorderTextFieldStyle())
        }
        
        HStack {
          Text("Port:")
            .frame(width: 80, alignment: .leading)
          TextField("21600", text: Binding(
            get: { String(oscManager.configuration.port) },
            set: { oscManager.configuration.port = Int($0) ?? 21600 }
          ))
          .textFieldStyle(RoundedBorderTextFieldStyle())
        }
        
        HStack {
          Text("Protocol:")
            .frame(width: 80, alignment: .leading)
          Picker("Protocol", selection: $oscManager.configuration.usesTCP) {
            Text("UDP").tag(false)
            Text("TCP").tag(true)
          }
          .pickerStyle(SegmentedPickerStyle())
          .frame(width: 120)
        }
        
        HStack {
          Text("Status:")
            .frame(width: 80, alignment: .leading)
          HStack {
            Circle()
              .fill(oscManager.configuration.isConnected ? Color.green : Color.red)
              .frame(width: 8, height: 8)
            Text(oscManager.configuration.connectionStatus)
              .foregroundColor(oscManager.configuration.isConnected ? .green : .secondary)
          }
          
          Spacer()
          
          Button(oscManager.configuration.getConnectionButtonText()) {
            oscManager.toggleConnection()
          }
          .disabled(!oscManager.configuration.isValidConfiguration())
        }
      }
    }
    .padding(.horizontal)
    .background(Color.gray.opacity(0.05))
  }
}

// MARK: - Single Joystick OSC Section
struct SingleJoystickOSCSection: View {
  @StateObject private var virtualJoystickManager = VirtualJoystickManager.shared
  
  var body: some View {
    VStack(spacing: 16) {
      Text("Single Joystick OSC Mapping")
        .font(.headline)
      
      Form {
        Section("OSC Addresses") {
          HStack {
            Image(systemName: "arrow.left.and.right")
              .foregroundColor(.blue)
              .frame(width: 20)
            Text("Pan (X):")
              .frame(width: 80, alignment: .leading)
            TextField("Pan OSC Address", text: $virtualJoystickManager.configuration.singleJoystickPanAddress)
              .textFieldStyle(RoundedBorderTextFieldStyle())
              .font(.system(.body, design: .monospaced))
          }
          
          HStack {
            Image(systemName: "arrow.up.and.down")
              .foregroundColor(.green)
              .frame(width: 20)
            Text("Tilt (Y):")
              .frame(width: 80, alignment: .leading)
            TextField("Tilt OSC Address", text: $virtualJoystickManager.configuration.singleJoystickTiltAddress)
              .textFieldStyle(RoundedBorderTextFieldStyle())
              .font(.system(.body, design: .monospaced))
          }
        }
        
        Section("Quick Presets") {
          OSCPresetButtonsInline(
            onLightkey: {
              virtualJoystickManager.configuration.singleJoystickPanAddress = "/fixture/selected/overrides/panAngle"
              virtualJoystickManager.configuration.singleJoystickTiltAddress = "/fixture/selected/overrides/tiltAngle"
            },
            onQLab: {
              virtualJoystickManager.configuration.singleJoystickPanAddress = "/cue/pan"
              virtualJoystickManager.configuration.singleJoystickTiltAddress = "/cue/tilt"
            },
            onGrandMA: {
              virtualJoystickManager.configuration.singleJoystickPanAddress = "/gma3/cmd"
              virtualJoystickManager.configuration.singleJoystickTiltAddress = "/gma3/cmd"
            }
          )
        }
      }
    }
  }
}

// MARK: - Individual Joystick OSC Section
struct JoystickOSCSection: View {
  @Binding var joystick: JoystickInstance
  let joystickNumber: Int
  
  var body: some View {
    VStack(spacing: 16) {
      // Header
      VStack(spacing: 8) {
        Text("Joystick \(joystickNumber)")
          .font(.title2)
          .fontWeight(.medium)
        
        HStack {
          TextField("Joystick Name", text: $joystick.name)
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .frame(width: 200)
          
          Toggle("Enabled", isOn: $joystick.isEnabled)
            .toggleStyle(.switch)
        }
      }
      .padding()
      .background(Color.gray.opacity(0.05))
      .cornerRadius(10)
      
      if joystick.isEnabled {
        Form {
          Section("OSC Addresses") {
            HStack {
              Image(systemName: "arrow.left.and.right")
                .foregroundColor(.blue)
                .frame(width: 20)
              Text("Pan (X):")
                .frame(width: 80, alignment: .leading)
              TextField("Pan OSC Address", text: $joystick.oscPanAddress)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .font(.system(.body, design: .monospaced))
            }
            
            HStack {
              Image(systemName: "arrow.up.and.down")
                .foregroundColor(.green)
                .frame(width: 20)
              Text("Tilt (Y):")
                .frame(width: 80, alignment: .leading)
              TextField("Tilt OSC Address", text: $joystick.oscTiltAddress)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .font(.system(.body, design: .monospaced))
            }
          }
          
          Section("MIDI Settings") {
            HStack {
              Image(systemName: "pianokeys")
                .foregroundColor(.purple)
                .frame(width: 20)
              
              VStack {
                Text("Channel")
                  .font(.caption)
                Stepper(value: $joystick.midiChannel, in: 1...16) {
                  Text("\(joystick.midiChannel)")
                    .frame(width: 30)
                }
              }
              
              VStack {
                Text("Pan CC")
                  .font(.caption)
                Stepper(value: $joystick.midiCCPan, in: 0...127) {
                  Text("\(joystick.midiCCPan)")
                    .frame(width: 40)
                }
              }
              
              VStack {
                Text("Tilt CC")
                  .font(.caption)
                Stepper(value: $joystick.midiCCTilt, in: 0...127) {
                  Text("\(joystick.midiCCTilt)")
                    .frame(width: 40)
                }
              }
            }
          }
          
          Section("Quick Presets") {
            OSCPresetButtonsInline(
              onLightkey: {
                joystick.oscPanAddress = "/lightkey/layers/layer\(joystickNumber)/pan"
                joystick.oscTiltAddress = "/lightkey/layers/layer\(joystickNumber)/tilt"
              },
              onQLab: {
                joystick.oscPanAddress = "/cue/\(joystickNumber)/pan"
                joystick.oscTiltAddress = "/cue/\(joystickNumber)/tilt"
              },
              onGrandMA: {
                joystick.oscPanAddress = "/gma3/layer\(joystickNumber)/pan"
                joystick.oscTiltAddress = "/gma3/layer\(joystickNumber)/tilt"
              }
            )
          }
        }
      } else {
        VStack {
          Image(systemName: "gamecontroller.slash")
            .font(.system(size: 40))
            .foregroundColor(.gray)
          Text("Joystick Disabled")
            .font(.title3)
            .foregroundColor(.secondary)
          Text("Enable this joystick to configure OSC addresses")
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    }
    .padding()
  }
}

// MARK: - Inline OSC Preset Buttons
struct OSCPresetButtonsInline: View {
  let onLightkey: () -> Void
  let onQLab: () -> Void
  let onGrandMA: () -> Void
  
  var body: some View {
    HStack {
      Button("Lightkey") {
        onLightkey()
      }
      .buttonStyle(.bordered)
      .foregroundColor(.blue)
      
      Button("QLab") {
        onQLab()
      }
      .buttonStyle(.bordered)
      .foregroundColor(.orange)
      
      Button("GrandMA3") {
        onGrandMA()
      }
      .buttonStyle(.bordered)
      .foregroundColor(.red)
      
      Spacer()
    }
  }
}

// MARK: - OSC Test Section
struct OSCTestSection: View {
  @StateObject private var oscManager = OSCManager.shared
  
  var body: some View {
    Form {
      Section("Test & Debug") {
        VStack(alignment: .leading, spacing: 10) {
          HStack {
            Button("Test Connection") {
              print("🧪 Testing OSC connection...")
              oscManager.configuration.testCommonPorts()
            }
            
            Button("Send Test Values") {
              print("🧪 Sending test values...")
              oscManager.updatePanTilt(pan: 45.0, tilt: 30.0)
            }
            
            Button("Reset Values") {
              print("🧪 Resetting to center...")
              oscManager.updatePanTilt(pan: 0.0, tilt: 0.0)
            }
          }
          
          Button("Reset to Lightkey Defaults") {
            resetToLightkeyDefaults()
          }
          .foregroundColor(.blue)
        }
      }
      
      Section("Current Configuration") {
        VStack(alignment: .leading, spacing: 6) {
          HStack {
            Text("Target:")
              .fontWeight(.medium)
            Spacer()
            Text("\(oscManager.configuration.host):\(oscManager.configuration.port)")
              .foregroundColor(.secondary)
              .font(.system(.body, design: .monospaced))
          }
          
          HStack {
            Text("Protocol:")
              .fontWeight(.medium)
            Spacer()
            Text(oscManager.configuration.usesTCP ? "TCP" : "UDP")
              .foregroundColor(oscManager.configuration.usesTCP ? .blue : .orange)
          }
          
          HStack {
            Text("Valid Config:")
              .fontWeight(.medium)
            Spacer()
            Text(oscManager.configuration.isValidConfiguration() ? "✓ Yes" : "✗ No")
              .foregroundColor(oscManager.configuration.isValidConfiguration() ? .green : .red)
          }
        }
      }
    }
  }
  
  private func resetToLightkeyDefaults() {
    oscManager.configuration.host = "127.0.0.1"
    oscManager.configuration.port = 21600
    oscManager.configuration.panAddress = "/fixture/selected/overrides/panAngle"
    oscManager.configuration.tiltAddress = "/fixture/selected/overrides/tiltAngle"
    oscManager.configuration.usesTCP = false
    
    print("🔄 OSC settings reset to Lightkey defaults")
  }
}


