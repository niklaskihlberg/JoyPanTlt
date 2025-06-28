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
  static let shared = OSCConfiguration()
  
  @Published var isEnabled: Bool = false  // FIX: Lägg till enable/disable funktionalitet
  @Published var host: String = "127.0.0.1"
  @Published var port: Int = 21600
  @Published var panAddress: String = "/fixture/selected/overrides/panAngle"
  @Published var tiltAddress: String = "/fixture/selected/overrides/tiltAngle"
  @Published var isConnected: Bool = false
  @Published var connectionStatus: String = "Disconnected"
  @Published var usesTCP: Bool = false
  
  // OSC Backend (nu implementerad ovan i samma fil)
  let backend = OSCBackend()
  
  init() {
    setupBackendCallbacks()
    // FIX: Auto-connect när enabled och konfiguration är giltig
    setupAutoConnect()
  }
  
  private func setupBackendCallbacks() {
    backend.onConnectionStateChanged = { [weak self] (isConnected: Bool, status: String) in
      DispatchQueue.main.async {
        self?.isConnected = isConnected
        self?.connectionStatus = status
      }
    }
  }
  
  // FIX: Auto-connect funktionalitet
  private func setupAutoConnect() {
    // Lyssna på ändringar i isEnabled, host, port, usesTCP
    Publishers.CombineLatest4($isEnabled, $host, $port, $usesTCP)
      .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
      .sink { [weak self] (enabled, host, port, usesTCP) in
        if enabled && self?.isValidConfiguration() == true {
          print("📡 OSC Auto-connecting...")
          self?.backend.connect(host: host, port: port, usesTCP: usesTCP)
        } else {
          print("📡 OSC Auto-disconnecting...")
          self?.backend.disconnect()
        }
      }
      .store(in: &cancellables)
  }
  
  private var cancellables = Set<AnyCancellable>()
  
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
  @State private var selectedJoystickIndex = 0
  
  var body: some View {
    VStack(spacing: 0) {
      // Enable OSC checkbox
      enableOSCSection
      
      // OSC Connection Settings
      connectionSettingsSection
      
      // Virtual joystick flikar
      multiJoystickTabView
    }
    .navigationTitle("OSC Settings")
    .onAppear {
      // Auto-select first joystick if none selected
      if selectedJoystickIndex >= virtualJoystickManager.configuration.numberOfJoysticks {
        selectedJoystickIndex = max(0, virtualJoystickManager.configuration.numberOfJoysticks - 1)
      }
    }
  }
  
  // Enable OSC sektion
  private var enableOSCSection: some View {
    VStack(spacing: 16) {
      HStack {
        Text("Enable OSC:")
          .font(.headline)
        Toggle("", isOn: $oscManager.configuration.isEnabled, )
          .padding(/*@START_MENU_TOKEN@*/.bottom, 5.0/*@END_MENU_TOKEN@*/)
        Spacer()
      }
      
      .padding(.horizontal, 20)
      .padding(.vertical, 16)
      
    }
  }
  
  // OSC Connection Settings sektion
  private var connectionSettingsSection: some View {
    VStack(spacing: 16) {
      VStack(spacing: 12) {
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
          Picker("", selection: $oscManager.configuration.usesTCP) {
            Text("UDP").tag(false)
            Text("TCP").tag(true)
          }
          .pickerStyle(SegmentedPickerStyle())
          .frame(width: 120)
          
          Spacer()
          
//          // Connection status indikator (enklare version)
//          HStack(spacing: 4) {
//            Circle()
//              .fill(oscManager.configuration.isConnected ? Color.green : Color.gray)
//              .frame(width: 8, height: 8)
//            Text(oscManager.configuration.isConnected ? "Connected" : "Disconnected")
//              .font(.caption)
//              .foregroundColor(.secondary)
//          }
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
        joystickOSCConfigurationView(for: index)
          .tabItem {
            Image(systemName: "gamecontroller.fill")
            Text("Joystick \(index + 1)")
          }
          .tag(index)
      }
    }
    .frame(minHeight: 300)
    .onChange(of: virtualJoystickManager.configuration.numberOfJoysticks) { _, newCount in
      if selectedJoystickIndex >= newCount {
        selectedJoystickIndex = max(0, newCount - 1)
      }
    }
  }
  
  // Joystick-specifik OSC konfiguration med offset
  private func joystickOSCConfigurationView(for index: Int) -> some View {
    VStack(alignment: .leading, spacing: 24) {
      if index < virtualJoystickManager.configuration.joystickInstances.count {
        let joystick = virtualJoystickManager.configuration.joystickInstances[index]
        
        // Pan Address sektion
        VStack(alignment: .leading, spacing: 12) {
          Text("Pan Address")
            .font(.headline)
          
          HStack {
            Text("Address:")
              .frame(width: 80, alignment: .leading)
            TextField("Pan OSC Address", text: Binding(
              get: { joystick.oscPanAddress },
              set: { virtualJoystickManager.configuration.joystickInstances[index].oscPanAddress = $0 }
            ))
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .font(.system(.body, design: .monospaced))
          }
        }
        
        // Tilt Address sektion
        VStack(alignment: .leading, spacing: 12) {
          Text("Tilt Address")
            .font(.headline)
          
          HStack {
            Text("Address:")
              .frame(width: 80, alignment: .leading)
            TextField("Tilt OSC Address", text: Binding(
              get: { joystick.oscTiltAddress },
              set: { virtualJoystickManager.configuration.joystickInstances[index].oscTiltAddress = $0 }
            ))
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .font(.system(.body, design: .monospaced))
          }
        }
        
        // Reset knapp
        HStack {
          Spacer()
          Button("Reset to Defaults") {
            resetJoystickOSCToDefaults(index: index)
          }
          .foregroundColor(.blue)
        }
        
        Spacer()
      }
    }
    .padding(20)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
  }
  
  private func resetJoystickOSCToDefaults(index: Int) {
    guard index < virtualJoystickManager.configuration.joystickInstances.count else { return }
    
    virtualJoystickManager.configuration.joystickInstances[index].oscPanAddress = "/lightkey/layers/layer\(index + 1)/pan"
    virtualJoystickManager.configuration.joystickInstances[index].oscTiltAddress = "/lightkey/layers/layer\(index + 1)/tilt"
    
    // TA BORT TILLS VIDARE - kommer tillbaka när offset-egenskaperna kompilerats
    /*
    virtualJoystickManager.configuration.joystickInstances[index].panOffsetEnabled = false
    virtualJoystickManager.configuration.joystickInstances[index].tiltOffsetEnabled = false
    virtualJoystickManager.configuration.joystickInstances[index].panOffset = 0.0
    virtualJoystickManager.configuration.joystickInstances[index].tiltOffset = 0.0
    */
    
    print("🔄 OSC settings for Joystick \(index + 1) reset to defaults")
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

// MARK: - OSC Settings Preview
struct OSCSettingsView_Previews: PreviewProvider {
  static var previews: some View {
    OSCSettingsView()
      .frame(width: 600, height: 500)
  }
}
//            Button("Test Connection") {
//              print("🧪 Testing OSC connection...")
//              oscManager.configuration.testCommonPorts()
//            }
//            
//            Button("Send Test Values") {
//              print("🧪 Sending test values...")
//              oscManager.updatePanTilt(pan: 45.0, tilt: 30.0)
//            }
//            
//            Button("Reset Values") {
//              print("🧪 Resetting to center...")
//              oscManager.updatePanTilt(pan: 0.0, tilt: 0.0)
//            }
//          }
//          
//          Button("Reset to Lightkey Defaults") {
//            resetToLightkeyDefaults()
//          }
//          .foregroundColor(.blue)
//        }
//      }
//      
//      Section("Current Configuration") {
//        VStack(alignment: .leading, spacing: 6) {
//          HStack {
//            Text("Target:")
//              .fontWeight(.medium)
//            Spacer()
//            Text("\(oscManager.configuration.host):\(oscManager.configuration.port)")
//              .foregroundColor(.secondary)
//              .font(.system(.body, design: .monospaced))
//          }
//          
//          HStack {
//            Text("Protocol:")
//              .fontWeight(.medium)
//            Spacer()
//            Text(oscManager.configuration.usesTCP ? "TCP" : "UDP")
//              .foregroundColor(oscManager.configuration.usesTCP ? .blue : .orange)
//          }
//          
//          HStack {
//            Text("Valid Config:")
//              .fontWeight(.medium)
//            Spacer()
//            Text(oscManager.configuration.isValidConfiguration() ? "✓ Yes" : "✗ No")
//              .foregroundColor(oscManager.configuration.isValidConfiguration() ? .green : .red)
//          }
//        }
//      }
//    }
//  }
//  
//  private func resetToLightkeyDefaults() {
//    oscManager.configuration.host = "127.0.0.1"
//    oscManager.configuration.port = 21600
//    oscManager.configuration.panAddress = "/fixture/selected/overrides/panAngle"
//    oscManager.configuration.tiltAddress = "/fixture/selected/overrides/tiltAngle"
//    oscManager.configuration.usesTCP = false
//    
//    print("🔄 OSC settings reset to Lightkey defaults")
//  }
//}


