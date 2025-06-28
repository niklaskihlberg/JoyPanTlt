//
//  VirtualJoystickConfiguration.swift
//  JoyPanTlt
//
//  Created by Niklas Kihlberg on 2025-06-25.
//

import Foundation
import SwiftUI
import Combine

// MARK: - Joystick Instance Model
struct JoystickInstance: Identifiable, Codable {
  var id = UUID()
  var name: String
  var isEnabled: Bool = true
  var oscAddress: String          // Behåll för backward compatibility
  var oscPanAddress: String       // Ny separate Pan address
  var oscTiltAddress: String      // Ny separate Tilt address
  var midiChannel: Int
  var midiCCPan: Int
  var midiCCTilt: Int
  
  // FIX: Lägg till offset-funktionalitet
  var panOffsetEnabled: Bool = false
  var tiltOffsetEnabled: Bool = false
  var panOffset: Double = 0.0
  var tiltOffset: Double = 0.0
  
  init(name: String, oscAddress: String, midiChannel: Int = 1, midiCCPan: Int = 1, midiCCTilt: Int = 2) {
    self.name = name
    self.oscAddress = oscAddress
    self.oscPanAddress = "\(oscAddress)/pan"      // Default pan address
    self.oscTiltAddress = "\(oscAddress)/tilt"    // Default tilt address
    self.midiChannel = midiChannel
    self.midiCCPan = midiCCPan
    self.midiCCTilt = midiCCTilt
  }
  
  // Ny init med separata pan/tilt addresses
  init(name: String, oscPanAddress: String, oscTiltAddress: String, midiChannel: Int = 1, midiCCPan: Int = 1, midiCCTilt: Int = 2) {
    self.name = name
    self.oscAddress = oscPanAddress  // Use panAddress as fallback
    self.oscPanAddress = oscPanAddress
    self.oscTiltAddress = oscTiltAddress
    self.midiChannel = midiChannel
    self.midiCCPan = midiCCPan
    self.midiCCTilt = midiCCTilt
  }
  
  // CodingKeys för att hantera både gamla och nya format
  private enum CodingKeys: String, CodingKey {
    case name, isEnabled, oscAddress, oscPanAddress, oscTiltAddress, midiChannel, midiCCPan, midiCCTilt
    case panOffsetEnabled, tiltOffsetEnabled, panOffset, tiltOffset
  }
}

// MARK: - Virtual Joystick Configuration Model
class VirtualJoystickConfiguration: ObservableObject {
  // Published properties för SwiftUI binding
  @Published var sensitivityValue: Double = 0.5 {
    didSet { saveToUserDefaults() }
  }
  
  @Published var damping: Double = 0.8 {
    didSet { saveToUserDefaults() }
  }
  
  @Published var snapBackSpeed: Double = 0.3 {
    didSet { saveToUserDefaults() }
  }
  
  @Published var visualFeedback: Bool = false {
    didSet { saveToUserDefaults() }
  }
  
  @Published var joystickSize: Double = 150 {
    didSet { saveToUserDefaults() }
  }
  
  @Published var knobSize: Double = 90 {
    didSet { saveToUserDefaults() }
  }
  
  @Published var updateInterval: Double = 0.05 {
    didSet { saveToUserDefaults() }
  }
  
  // Color settings
  @Published var backgroundOpacity: Double = 0.3 {
    didSet { saveToUserDefaults() }
  }
  
  @Published var knobOpacity: Double = 1.0 {
    didSet { saveToUserDefaults() }
  }
  
  // LÄGG TILL DESSA:
  @Published var invertPan: Bool = false {
    didSet { saveToUserDefaults() }
  }
  
  @Published var invertTilt: Bool = false {
    didSet { saveToUserDefaults() }
  }
  
  // Multi-Joystick Settings
  @Published var numberOfJoysticks: Int = 1 {
    didSet { 
      updateJoystickInstances()
      saveToUserDefaults() 
    }
  }
  
  @Published var joystickInstances: [JoystickInstance] = [] {
    didSet { saveToUserDefaults() }
  }
  
  // Single Joystick OSC Addresses
  @Published var singleJoystickPanAddress: String = "/fixture/selected/overrides/panAngle" {
    didSet { saveToUserDefaults() }
  }
  
  @Published var singleJoystickTiltAddress: String = "/fixture/selected/overrides/tiltAngle" {
    didSet { saveToUserDefaults() }
  }
  
  // UserDefaults keys
  private let sensitivityKey = "VirtualJoystick_Sensitivity"
  private let dampingKey = "VirtualJoystick_Damping"
  private let snapBackSpeedKey = "VirtualJoystick_SnapBackSpeed"
  private let visualFeedbackKey = "VirtualJoystick_VisualFeedback"
  private let joystickSizeKey = "VirtualJoystick_Size"
  private let knobSizeKey = "VirtualJoystick_KnobSize"
  private let updateIntervalKey = "VirtualJoystick_UpdateInterval"
  private let backgroundOpacityKey = "VirtualJoystick_BackgroundOpacity"
  private let knobOpacityKey = "VirtualJoystick_KnobOpacity"
  private let invertPanKey = "VirtualJoystick_InvertPan"
  private let invertTiltKey = "VirtualJoystick_InvertTilt"
  private let numberOfJoysticksKey = "VirtualJoystick_NumberOfJoysticks"
  private let joystickInstancesKey = "VirtualJoystick_JoystickInstances"
  private let singleJoystickPanAddressKey = "VirtualJoystick_SingleJoystickPanAddress"
  private let singleJoystickTiltAddressKey = "VirtualJoystick_SingleJoystickTiltAddress"
  
  // Default values
  private let defaultSensitivity = 0.5
  private let defaultDamping = 0.8
  private let defaultSnapBackSpeed = 0.3
  private let defaultVisualFeedback = true
  private let defaultJoystickSize = 150.0
  private let defaultKnobSize = 50.0
  private let defaultUpdateInterval = 0.05
  private let defaultBackgroundOpacity = 0.3
  private let defaultKnobOpacity = 0.8
  private let defaultInvertPan = false
  private let defaultInvertTilt = false
  private let defaultNumberOfJoysticks = 1
  private let defaultSingleJoystickPanAddress = "/fixture/selected/overrides/panAngle"
  private let defaultSingleJoystickTiltAddress = "/fixture/selected/overrides/tiltAngle"
  
  init() {
    loadFromUserDefaults()
    // Sätt initial sensitivity i TranslationLogic
    TranslationLogic.setSensitivity(sensitivityValue)
  }
  
  // MARK: - UserDefaults
  private func loadFromUserDefaults() {
    sensitivityValue = UserDefaults.standard.object(forKey: sensitivityKey) as? Double ?? defaultSensitivity
    damping = UserDefaults.standard.object(forKey: dampingKey) as? Double ?? defaultDamping
    snapBackSpeed = UserDefaults.standard.object(forKey: snapBackSpeedKey) as? Double ?? defaultSnapBackSpeed
    visualFeedback = UserDefaults.standard.object(forKey: visualFeedbackKey) as? Bool ?? defaultVisualFeedback
    joystickSize = UserDefaults.standard.object(forKey: joystickSizeKey) as? Double ?? defaultJoystickSize
    knobSize = UserDefaults.standard.object(forKey: knobSizeKey) as? Double ?? defaultKnobSize
    updateInterval = UserDefaults.standard.object(forKey: updateIntervalKey) as? Double ?? defaultUpdateInterval
    backgroundOpacity = UserDefaults.standard.object(forKey: backgroundOpacityKey) as? Double ?? defaultBackgroundOpacity
    knobOpacity = UserDefaults.standard.object(forKey: knobOpacityKey) as? Double ?? defaultKnobOpacity
    invertPan = UserDefaults.standard.object(forKey: invertPanKey) as? Bool ?? defaultInvertPan
    invertTilt = UserDefaults.standard.object(forKey: invertTiltKey) as? Bool ?? defaultInvertTilt
    numberOfJoysticks = UserDefaults.standard.object(forKey: numberOfJoysticksKey) as? Int ?? defaultNumberOfJoysticks
    
    if let data = UserDefaults.standard.data(forKey: joystickInstancesKey),
       let decoded = try? JSONDecoder().decode([JoystickInstance].self, from: data) {
      joystickInstances = decoded
    } else {
      updateJoystickInstances()  // Skapa default joysticks
    }
    
    singleJoystickPanAddress = UserDefaults.standard.string(forKey: singleJoystickPanAddressKey) ?? defaultSingleJoystickPanAddress
    singleJoystickTiltAddress = UserDefaults.standard.string(forKey: singleJoystickTiltAddressKey) ?? defaultSingleJoystickTiltAddress
  }
  
  private func saveToUserDefaults() {
    UserDefaults.standard.set(sensitivityValue, forKey: sensitivityKey)
    UserDefaults.standard.set(damping, forKey: dampingKey)
    UserDefaults.standard.set(snapBackSpeed, forKey: snapBackSpeedKey)
    UserDefaults.standard.set(visualFeedback, forKey: visualFeedbackKey)
    UserDefaults.standard.set(joystickSize, forKey: joystickSizeKey)
    UserDefaults.standard.set(knobSize, forKey: knobSizeKey)
    UserDefaults.standard.set(updateInterval, forKey: updateIntervalKey)
    UserDefaults.standard.set(backgroundOpacity, forKey: backgroundOpacityKey)
    UserDefaults.standard.set(knobOpacity, forKey: knobOpacityKey)
    UserDefaults.standard.set(invertPan, forKey: invertPanKey)
    UserDefaults.standard.set(invertTilt, forKey: invertTiltKey)
    UserDefaults.standard.set(numberOfJoysticks, forKey: numberOfJoysticksKey)
    
    if let encoded = try? JSONEncoder().encode(joystickInstances) {
      UserDefaults.standard.set(encoded, forKey: joystickInstancesKey)
    }
    
    UserDefaults.standard.set(singleJoystickPanAddress, forKey: singleJoystickPanAddressKey)
    UserDefaults.standard.set(singleJoystickTiltAddress, forKey: singleJoystickTiltAddressKey)
  }
  
  // MARK: - Validation
  func isValidConfiguration() -> Bool {
    return sensitivityValue > 0 && sensitivityValue <= 2.0 &&
    damping >= 0 && damping <= 1.0 &&
    snapBackSpeed > 0 && snapBackSpeed <= 1.0 &&
    joystickSize >= 50 && joystickSize <= 300 &&
    knobSize >= 20 && knobSize <= 100 &&
    updateInterval >= 0.01 && updateInterval <= 0.5
  }
  
  func resetToDefaults() {
    sensitivityValue = defaultSensitivity
    damping = defaultDamping
    snapBackSpeed = defaultSnapBackSpeed
    visualFeedback = defaultVisualFeedback
    joystickSize = defaultJoystickSize
    knobSize = defaultKnobSize
    updateInterval = defaultUpdateInterval
    backgroundOpacity = defaultBackgroundOpacity
    knobOpacity = defaultKnobOpacity
    invertPan = defaultInvertPan
    invertTilt = defaultInvertTilt
    numberOfJoysticks = defaultNumberOfJoysticks
    joystickInstances = []
    updateJoystickInstances()
    
    singleJoystickPanAddress = defaultSingleJoystickPanAddress
    singleJoystickTiltAddress = defaultSingleJoystickTiltAddress
  }
  
  // MARK: - Multi-Joystick Management
  private func updateJoystickInstances() {
    let currentCount = joystickInstances.count
    
    if numberOfJoysticks > currentCount {
      // Lägg till nya joysticks
      for i in currentCount..<numberOfJoysticks {
        let newJoystick = JoystickInstance(
          name: "Joystick \(i + 1)",
          oscPanAddress: "/lightkey/layers/layer\(i + 1)/pan",
          oscTiltAddress: "/lightkey/layers/layer\(i + 1)/tilt",
          midiChannel: i + 1,
          midiCCPan: (i * 2) + 1,
          midiCCTilt: (i * 2) + 2
        )
        // FIX: Sätt default offset-värden för nya joysticks
        var joystickWithDefaults = newJoystick
        joystickWithDefaults.panOffsetEnabled = false
        joystickWithDefaults.tiltOffsetEnabled = false
        joystickWithDefaults.panOffset = 0.0
        joystickWithDefaults.tiltOffset = 0.0
        
        joystickInstances.append(joystickWithDefaults)
      }
    } else if numberOfJoysticks < currentCount {
      // Ta bort extra joysticks
      joystickInstances = Array(joystickInstances.prefix(numberOfJoysticks))
    }
  }
  
  func getEnabledJoysticks() -> [JoystickInstance] {
    return joystickInstances.filter { $0.isEnabled }
  }
  
  func updateJoystick(_ joystick: JoystickInstance) {
    if let index = joystickInstances.firstIndex(where: { $0.id == joystick.id }) {
      joystickInstances[index] = joystick
    }
  }
}

// MARK: - Virtual Joystick Manager (Singleton)
class VirtualJoystickManager: ObservableObject {
  static let shared = VirtualJoystickManager()
  
  @Published var configuration = VirtualJoystickConfiguration()
  
  // FIX: Lägg till callback för när joystick-konfiguration ändras
  var onJoystickConfigurationChanged: ((Int) -> Void)?
  
  private init() {
    // FIX: Lyssna på ändringar i numberOfJoysticks och anropa callback
    configuration.$numberOfJoysticks
      .dropFirst() // Skippa initial värde
      .sink { [weak self] newCount in
        print("🔄 VirtualJoystickManager: Antal joysticks ändrat till \(newCount)")
        self?.onJoystickConfigurationChanged?(newCount)
      }
      .store(in: &cancellables)
  }
  
  private var cancellables = Set<AnyCancellable>()
  
  // Convenience methods
  func getSensitivity() -> Double {
    return configuration.sensitivityValue
  }
  
  func getJoystickColors() -> (background: Color, knob: Color) {
    let background = Color.gray.opacity(configuration.backgroundOpacity)
    let knob = Color.gray.opacity(configuration.knobOpacity)
    return (background, knob)
  }
  
  func getJoystickSizes() -> (joystick: CGFloat, knob: CGFloat) {
    return (CGFloat(configuration.joystickSize), CGFloat(configuration.knobSize))
  }
  
  func getUpdateInterval() -> TimeInterval {
    return configuration.updateInterval
  }
  
  // Convenience method för att applicera invert settings
  func applyInvertSettings(pan: Double, tilt: Double) -> (pan: Double, tilt: Double) {
    let adjustedPan = configuration.invertPan ? -pan : pan
    let adjustedTilt = configuration.invertTilt ? -tilt : tilt
    return (pan: adjustedPan, tilt: adjustedTilt)
  }
  
  // Convenience method för att få invert status
  func getInvertStatus() -> (panInverted: Bool, tiltInverted: Bool) {
    return (configuration.invertPan, configuration.invertTilt)
  }
}

// MARK: - Helper Extensions
extension VirtualJoystickConfiguration {
  var performanceInfo: String {
    return "Update: \(String(format: "%.0f", 1.0/updateInterval))Hz, Sensitivity: \(String(format: "%.1f", sensitivityValue))"
  }
  
  var appearanceInfo: String {
    return "Size: \(String(format: "%.0f", joystickSize))×\(String(format: "%.0f", knobSize))"
  }
}

// MARK: - Virtual Joystick Settings View
struct VirtualJoystickSettingsView: View {
  @StateObject private var virtualJoystickManager = VirtualJoystickManager.shared
  
  var body: some View {
    Form {
      Section("Sensitivity & Response") {
        HStack {
          Text("Sensitivity:")
            .frame(width: 100, alignment: .leading)
          Slider(value: $virtualJoystickManager.configuration.sensitivityValue, in: 0.1...2.0, step: 0.1)
          Text(String(format: "%.1f", virtualJoystickManager.configuration.sensitivityValue))
            .frame(width: 30)
        }
        
        HStack {
          Text("Damping:")
            .frame(width: 100, alignment: .leading)
          Slider(value: $virtualJoystickManager.configuration.damping, in: 0.1...1.0, step: 0.1)
          Text(String(format: "%.1f", virtualJoystickManager.configuration.damping))
            .frame(width: 30)
        }
        
        HStack {
          Text("Snap Back Speed:")
            .frame(width: 100, alignment: .leading)
          Slider(value: $virtualJoystickManager.configuration.snapBackSpeed, in: 0.1...1.0, step: 0.1)
          Text(String(format: "%.1f", virtualJoystickManager.configuration.snapBackSpeed))
            .frame(width: 30)
        }
      }
      
      Section("Control Direction") {
        HStack {
          VStack(alignment: .leading) {
            Toggle("Invert Pan (X-axis)", isOn: $virtualJoystickManager.configuration.invertPan)
            Text("Reverse horizontal movement direction")
              .font(.caption)
              .foregroundColor(.secondary)
          }
        }
        
        HStack {
          VStack(alignment: .leading) {
            Toggle("Invert Tilt (Y-axis)", isOn: $virtualJoystickManager.configuration.invertTilt)
            Text("Reverse vertical movement direction")
              .font(.caption)
              .foregroundColor(.secondary)
          }
        }
      }
      
      Section("Multi-Joystick Setup") {
        HStack {
          Text("Number of Joysticks:")
            .frame(width: 130, alignment: .leading)
          Stepper(value: $virtualJoystickManager.configuration.numberOfJoysticks, in: 1...8) {
            Text("\(virtualJoystickManager.configuration.numberOfJoysticks)")
              .frame(width: 30)
          }
        }
        
        if virtualJoystickManager.configuration.numberOfJoysticks > 1 {
          DisclosureGroup("Configure Individual Joysticks") {
            ForEach($virtualJoystickManager.configuration.joystickInstances) { $joystick in
              JoystickConfigRow(joystick: $joystick)
                .padding(.vertical, 4)
            }
          }
          .padding(.top, 8)
        }
      }
      
      Section("Appearance") {
        HStack {
          Text("Joystick Size:")
            .frame(width: 100, alignment: .leading)
          Slider(value: $virtualJoystickManager.configuration.joystickSize, in: 100...300, step: 10)
          Text(String(format: "%.0f", virtualJoystickManager.configuration.joystickSize))
            .frame(width: 40)
        }
        
        HStack {
          Text("Knob Size:")
            .frame(width: 100, alignment: .leading)
          Slider(value: $virtualJoystickManager.configuration.knobSize, in: 30...100, step: 5)
          Text(String(format: "%.0f", virtualJoystickManager.configuration.knobSize))
            .frame(width: 40)
        }
        
        HStack {
          Text("Background Opacity:")
            .frame(width: 130, alignment: .leading)
          Slider(value: $virtualJoystickManager.configuration.backgroundOpacity, in: 0.1...1.0, step: 0.1)
          Text(String(format: "%.1f", virtualJoystickManager.configuration.backgroundOpacity))
            .frame(width: 30)
        }
        
        HStack {
          Text("Knob Opacity:")
            .frame(width: 130, alignment: .leading)
          Slider(value: $virtualJoystickManager.configuration.knobOpacity, in: 0.1...1.0, step: 0.1)
          Text(String(format: "%.1f", virtualJoystickManager.configuration.knobOpacity))
            .frame(width: 30)
        }
      }
      
      Section("Performance") {
        HStack {
          Text("Update Interval:")
            .frame(width: 100, alignment: .leading)
          Slider(value: $virtualJoystickManager.configuration.updateInterval, in: 0.01...0.2, step: 0.01)
          Text(String(format: "%.2fs", virtualJoystickManager.configuration.updateInterval))
            .frame(width: 50)
          Text("(\(String(format: "%.0f", 1.0/virtualJoystickManager.configuration.updateInterval))Hz)")
            .foregroundColor(.secondary)
        }
      }
      
      Section("Actions") {
        HStack {
          Button("Test Settings") {
            testSettings()
          }
          
          Spacer()
          
          Button("Reset to Defaults") {
            virtualJoystickManager.configuration.resetToDefaults()
          }
        }
      }
      
      Section("Configuration Info") {
        VStack(alignment: .leading, spacing: 8) {
          HStack {
            Text("Performance:")
              .fontWeight(.medium)
            Spacer()
            Text("\(String(format: "%.0f", 1.0/virtualJoystickManager.configuration.updateInterval))Hz")
              .foregroundColor(.secondary)
          }
          
          HStack {
            Text("Appearance:")
              .fontWeight(.medium)
            Spacer()
            Text("\(String(format: "%.0f", virtualJoystickManager.configuration.joystickSize))×\(String(format: "%.0f", virtualJoystickManager.configuration.knobSize))")
              .foregroundColor(.secondary)
          }
          
          HStack {
            Text("Response:")
              .fontWeight(.medium)
            Spacer()
            Text("Sens: \(String(format: "%.1f", virtualJoystickManager.configuration.sensitivityValue)), Damp: \(String(format: "%.1f", virtualJoystickManager.configuration.damping))")
              .foregroundColor(.secondary)
          }
          
          HStack {
            Text("Direction:")
              .fontWeight(.medium)
            Spacer()
            Text("Pan: \(virtualJoystickManager.configuration.invertPan ? "Inverted" : "Normal"), Tilt: \(virtualJoystickManager.configuration.invertTilt ? "Inverted" : "Normal")")
              .foregroundColor(.secondary)
          }
        }
      }
    }
    .padding()
    .navigationTitle("Virtual Joystick Settings")
  }
  
  // MARK: - Helper Functions
  private func testSettings() {
    print("🧪 Testing virtual joystick settings:")
    print("  - Sensitivity: \(virtualJoystickManager.configuration.sensitivityValue)")
    print("  - Update rate: \(String(format: "%.0f", 1.0/virtualJoystickManager.configuration.updateInterval))Hz")
    print("  - Size: \(virtualJoystickManager.configuration.joystickSize)×\(virtualJoystickManager.configuration.knobSize)")
    print("  - Invert Pan: \(virtualJoystickManager.configuration.invertPan)")
    print("  - Invert Tilt: \(virtualJoystickManager.configuration.invertTilt)")
    
    // Test invert logic
    let testValues = virtualJoystickManager.applyInvertSettings(pan: 45.0, tilt: 30.0)
    print("  - Test: 45°, 30° → \(testValues.pan)°, \(testValues.tilt)°")
    
    // Test med joystick position
    let testPosition = CGPoint(x: 0.5, y: 0.3)
    let result1 = TranslationLogic.convertJoystickToPanTilt(testPosition)
    print("  - Before invert: \(result1.pan)°, \(result1.tilt)°")
    
    // Temporärt ändra invert
    let originalPan = virtualJoystickManager.configuration.invertPan
    let originalTilt = virtualJoystickManager.configuration.invertTilt
    virtualJoystickManager.configuration.invertPan = !originalPan
    virtualJoystickManager.configuration.invertTilt = !originalTilt
    
    let result2 = TranslationLogic.convertJoystickToPanTilt(testPosition)
    print("  - After invert: \(result2.pan)°, \(result2.tilt)°")
    
    // Återställ
    virtualJoystickManager.configuration.invertPan = originalPan
    virtualJoystickManager.configuration.invertTilt = originalTilt
  }
}

// MARK: - Individual Joystick Configuration Row
struct JoystickConfigRow: View {
  @Binding var joystick: JoystickInstance
  
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Toggle("", isOn: $joystick.isEnabled)
          .frame(width: 20)
        
        TextField("Name", text: $joystick.name)
          .textFieldStyle(.roundedBorder)
          .frame(width: 120)
        
        Spacer()
      }
      
      if joystick.isEnabled {
        HStack {
          Text("OSC:")
            .frame(width: 40, alignment: .leading)
          TextField("OSC Address", text: $joystick.oscAddress)
            .textFieldStyle(.roundedBorder)
            .frame(width: 220)
        }
        
        HStack {
          Text("MIDI:")
            .frame(width: 40, alignment: .leading)
          Text("Ch:")
            .frame(width: 25)
          TextField("", value: $joystick.midiChannel, format: .number)
            .textFieldStyle(.roundedBorder)
            .frame(width: 40)
          Text("Pan CC:")
            .frame(width: 50)
          TextField("", value: $joystick.midiCCPan, format: .number)
            .textFieldStyle(.roundedBorder)
            .frame(width: 40)
          Text("Tilt CC:")
            .frame(width: 50)  
          TextField("", value: $joystick.midiCCTilt, format: .number)
            .textFieldStyle(.roundedBorder)
            .frame(width: 40)
        }
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .background(Color.gray.opacity(0.1))
    .cornerRadius(8)
  }
}

// MARK: - Virtual Joystick Settings Preview
struct VirtualJoystickSettingsView_Previews: PreviewProvider {
  static var previews: some View {
    VirtualJoystickSettingsView()
      .frame(width: 500, height: 700)
  }
}
