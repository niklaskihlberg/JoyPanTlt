//
//  VirtualJoystickConfiguration.swift
//  JoyPanTlt
//
//  Created by Niklas Kihlberg on 2025-06-25.
//

import Foundation
import SwiftUI
import Combine

// MARK: - Virtual Joystick Configuration Model
class VirtualJoystickConfiguration: ObservableObject {
  // Globala inställningar
  @Published var numberOfJoysticks: Int = 1 {
    didSet { 
      updateJoystickInstances()
      saveToUserDefaults() 
    }
  }
  
  @Published var updateInterval: Double = 0.05 {
    didSet { saveToUserDefaults() }
  }
  
  // Fasta värden (ej längre konfigurerbara via UI)
  let joystickSize: Double = 145
  let knobSize: Double = 90
  let backgroundOpacity: Double = 0.25
  let knobOpacity: Double = 1.0
  let snapBackSpeed: Double = 0.25
  let visualFeedback: Bool = false
  
  @Published var joystickInstances: [JoystickInstance] = [] {
    didSet { saveToUserDefaults() }
  }
  
  // Computed properties för backwards compatibility (använder första joystick)
  var sensitivityValue: Double {
    return joystickInstances.first?.sensitivity ?? 0.5
  }
  
  var invertPan: Bool {
    return joystickInstances.first?.invertX ?? false
  }
  
  var invertTilt: Bool {
    return joystickInstances.first?.invertY ?? false
  }
  
  var damping: Double {
    return joystickInstances.first?.damping ?? 0.8
  }
  
  // UserDefaults keys
  private let numberOfJoysticksKey = "VirtualJoystick_NumberOfJoysticks"
  private let joystickInstancesKey = "VirtualJoystick_JoystickInstances"
  
  // Default values
  private let defaultNumberOfJoysticks = 1
  
  init() {
    loadFromUserDefaults()
    // Sätt initial sensitivity i TranslationLogic
    TranslationLogic.setSensitivity(sensitivityValue)
  }
  
  // MARK: - UserDefaults
  private func loadFromUserDefaults() {
    numberOfJoysticks = UserDefaults.standard.object(forKey: numberOfJoysticksKey) as? Int ?? defaultNumberOfJoysticks
    
    if let data = UserDefaults.standard.data(forKey: joystickInstancesKey),
       let decoded = try? JSONDecoder().decode([JoystickInstance].self, from: data) {
      joystickInstances = decoded
    } else {
      updateJoystickInstances()  // Skapa default joysticks
    }
  }
  
  private func saveToUserDefaults() {
    UserDefaults.standard.set(numberOfJoysticks, forKey: numberOfJoysticksKey)
    
    if let encoded = try? JSONEncoder().encode(joystickInstances) {
      UserDefaults.standard.set(encoded, forKey: joystickInstancesKey)
    }
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
    numberOfJoysticks = defaultNumberOfJoysticks
    joystickInstances = []
    updateJoystickInstances()
    
    // Rensa UserDefaults för att undvika korrupta data
    UserDefaults.standard.removeObject(forKey: joystickInstancesKey)
    UserDefaults.standard.removeObject(forKey: numberOfJoysticksKey)
    
    saveToUserDefaults()
  }
  
  // MARK: - Multi-Joystick Management
  private func updateJoystickInstances() {
    let currentCount = joystickInstances.count
    
    if numberOfJoysticks > currentCount {
      // Lägg till nya joysticks
      for i in currentCount..<numberOfJoysticks {
        let newJoystick = JoystickInstance(
          name: "Joystick \(i + 1)",
          oscPanAddress: i == 0 ? "/fixture/selected/overrides/panAngle" : "/lightkey/layers/layer\(i + 1)/pan",
          oscTiltAddress: i == 0 ? "/fixture/selected/overrides/tiltAngle" : "/lightkey/layers/layer\(i + 1)/tilt",
          midiChannel: i + 1,
          midiCCPan: (i * 2) + 1,
          midiCCTilt: (i * 2) + 2
        )
        
        joystickInstances.append(newJoystick)
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
  
  // Callback för när joystick-konfiguration ändras
  var onJoystickConfigurationChanged: ((Int) -> Void)?
  
  private init() {
    // Lyssna på ändringar i numberOfJoysticks och anropa callback
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
