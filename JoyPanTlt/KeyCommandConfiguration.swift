//
//  KeyCommandConfiguration.swift
//  JoyPanTlt
//
//  Created by Niklas Kihlberg on 2025-06-28.
//

import SwiftUI
import Combine

// MARK: - Key Command Types
enum JoystickKeyCommand: CaseIterable {
  case up
  case down
  case left
  case right
  case reset
  
  var defaultKey: KeyEquivalent {
    switch self {
    case .up: return .upArrow
    case .down: return .downArrow
    case .left: return .leftArrow
    case .right: return .rightArrow
    case .reset: return .space
    }
  }
  
  var displayName: String {
    switch self {
    case .up: return "Move Up"
    case .down: return "Move Down"
    case .left: return "Move Left"
    case .right: return "Move Right"
    case .reset: return "Reset to Center"
    }
  }
}

// MARK: - Keyboard Input State
class KeyboardInputState: ObservableObject {
  @Published var pressedKeys: Set<KeyEquivalent> = []
  @Published var currentPosition: CGPoint = .zero
  @Published var isActive: Bool = false
  
  private var keyboardTimer: Timer?
  
  // Callbacks - nu stöd för flera joysticks
  var onPositionChanged: ((CGPoint) -> Void)?
  var onInputMethodChanged: ((InputMethod) -> Void)?
  var onMultiJoystickPositionChanged: ((CGPoint, Int) -> Void)? // NY: För multi-joystick support
  
  func addPressedKey(_ key: KeyEquivalent) {
    print("🎹 Adding pressed key: \(key)")
    pressedKeys.insert(key)
    updatePosition()
    startKeyboardTimer()
    
    if !isActive {
      isActive = true
      onInputMethodChanged?(.keyboard)
    }
  }
  
  func removePressedKey(_ key: KeyEquivalent) {
    print("🎹 Removing pressed key: \(key)")
    pressedKeys.remove(key)
    
    if pressedKeys.isEmpty {
      print("🎹 No more keys pressed - resetting")
      reset()
    } else {
      print("🎹 Still keys pressed: \(Array(pressedKeys)) - updating position")
      updatePosition()
    }
  }
  
  func reset() {
    pressedKeys.removeAll()
    currentPosition = .zero
    isActive = false
    stopKeyboardTimer()
    onInputMethodChanged?(.none)
    onPositionChanged?(.zero)
    
    // NY: Notifiera alla joysticks om reset
    notifyAllJoysticksReset()
  }
  
  private func updatePosition() {
    var x: Double = 0
    var y: Double = 0
    
    // Använd faktiska key mappings från KeyCommandManager
    let keyConfig = KeyCommandManager.shared.configuration
    
    // Beräkna x-position (höger/vänster) - använd rätt tangenter
    if pressedKeys.contains(keyConfig.getKeyForCommand(.right)) {
      x += 1.0
      print("🎹 Right key active: x = \(x)")
    }
    if pressedKeys.contains(keyConfig.getKeyForCommand(.left)) {
      x -= 1.0
      print("🎹 Left key active: x = \(x)")
    }
    
    // Beräkna y-position (upp/ner) - använd rätt tangenter
    if pressedKeys.contains(keyConfig.getKeyForCommand(.up)) {
      y -= 1.0
      print("🎹 Up key active: y = \(y)")
    }
    if pressedKeys.contains(keyConfig.getKeyForCommand(.down)) {
      y += 1.0
      print("🎹 Down key active: y = \(y)")
    }
    
    // Normalisera diagonal movement
    if x != 0 && y != 0 {
      let length = sqrt(x * x + y * y)
      x = x / length
      y = y / length
    }
    
    currentPosition = CGPoint(x: x, y: y)
    
    // Debug-utskrift
    print("🎹 KeyboardInputState updatePosition: \(currentPosition), pressedKeys: \(Array(pressedKeys))")
    
    onPositionChanged?(currentPosition)
    
    // NY: Notifiera alla joysticks
    notifyAllJoysticks(currentPosition)
  }
  
  // NY: Notifiera alla joysticks om position
  private func notifyAllJoysticks(_ position: CGPoint) {
    let keyConfig = KeyCommandManager.shared.configuration
    
    print("🎹 Notifying enabled joysticks with position: \(position)")
    print("🎹 Enabled joystick indices: \(keyConfig.enabledJoystickIndices)")
    print("🎹 Registered callback indices: \(Array(KeyCommandManager.shared.joystickCallbacks.keys).sorted())")
    
    // NY: Notifiera bara aktiverade joysticks
    for joystickIndex in KeyCommandManager.shared.joystickCallbacks.keys {
      if keyConfig.isJoystickKeyboardEnabled(joystickIndex) {
        onMultiJoystickPositionChanged?(position, joystickIndex)
      }
    }
  }
  
  // NY: Notifiera alla joysticks om reset
  private func notifyAllJoysticksReset() {
    let keyConfig = KeyCommandManager.shared.configuration
    
    print("🎹 Resetting enabled joysticks")
    print("🎹 Enabled joystick indices: \(keyConfig.enabledJoystickIndices)")
    
    // NY: Notifiera bara aktiverade joysticks
    for joystickIndex in KeyCommandManager.shared.joystickCallbacks.keys {
      if keyConfig.isJoystickKeyboardEnabled(joystickIndex) {
        onMultiJoystickPositionChanged?(.zero, joystickIndex)
      }
    }
  }
  
  private func startKeyboardTimer() {
    stopKeyboardTimer()
    
    // Kontinuerlig uppdatering varje 50ms (20 Hz)
    keyboardTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
      if !self.pressedKeys.isEmpty && self.isActive {
        self.onPositionChanged?(self.currentPosition)
        // NY: Kontinuerligt uppdatera alla joysticks
        self.notifyAllJoysticks(self.currentPosition)
      }
    }
  }
  
  private func stopKeyboardTimer() {
    keyboardTimer?.invalidate()
    keyboardTimer = nil
  }
}

// MARK: - Key Command Configuration
class KeyCommandConfiguration: ObservableObject {
  @Published var keyMappings: [JoystickKeyCommand: KeyEquivalent] = [:]
  @Published var isKeyboardInputEnabled: Bool = true
  @Published var keyboardSensitivity: Double = 1.0
  
  // NY: Individuell kontroll över vilka joysticks som tangentbordet styr
  @Published var enabledJoystickIndices: Set<Int> = [] {
    didSet { saveToUserDefaults() }
  }
  
  // UserDefaults keys
  private let keyMappingsKey = "KeyCommand_Mappings"
  private let keyboardEnabledKey = "KeyCommand_Enabled"
  private let keyboardSensitivityKey = "KeyCommand_Sensitivity"
  private let enabledJoystickIndicesKey = "KeyCommand_EnabledJoystickIndices"
  
  init() {
    loadFromUserDefaults()
    setupDefaultMappings()
  }
  
  private func setupDefaultMappings() {
    for command in JoystickKeyCommand.allCases {
      if keyMappings[command] == nil {
        keyMappings[command] = command.defaultKey
      }
    }
  }
  
  private func loadFromUserDefaults() {
    isKeyboardInputEnabled = UserDefaults.standard.object(forKey: keyboardEnabledKey) as? Bool ?? true
    keyboardSensitivity = UserDefaults.standard.object(forKey: keyboardSensitivityKey) as? Double ?? 1.0
    
    // NY: Ladda enabled joystick indices
    if let data = UserDefaults.standard.data(forKey: enabledJoystickIndicesKey),
       let decoded = try? JSONDecoder().decode(Set<Int>.self, from: data) {
      enabledJoystickIndices = decoded
    } else {
      // Default: alla joysticks aktiverade
      updateEnabledJoysticksForCurrentCount()
    }
    
    // Ladda key mappings (komplex eftersom vi behöver KeyEquivalent)
    if let data = UserDefaults.standard.data(forKey: keyMappingsKey),
       let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
      
      for (commandString, keyString) in decoded {
        if let command = JoystickKeyCommand.allCases.first(where: { "\($0)" == commandString }),
           let key = keyEquivalentFromString(keyString) {
          keyMappings[command] = key
        }
      }
    }
  }
  
  private func saveToUserDefaults() {
    UserDefaults.standard.set(isKeyboardInputEnabled, forKey: keyboardEnabledKey)
    UserDefaults.standard.set(keyboardSensitivity, forKey: keyboardSensitivityKey)
    
    // NY: Spara enabled joystick indices
    if let encoded = try? JSONEncoder().encode(enabledJoystickIndices) {
      UserDefaults.standard.set(encoded, forKey: enabledJoystickIndicesKey)
    }
    
    // Spara key mappings som strings
    let mappingsDict = keyMappings.mapValues { keyEquivalentToString($0) }
    let commandDict = Dictionary(uniqueKeysWithValues: mappingsDict.map { ("\($0.key)", $0.value) })
    
    if let encoded = try? JSONEncoder().encode(commandDict) {
      UserDefaults.standard.set(encoded, forKey: keyMappingsKey)
    }
  }
  
  func resetToDefaults() {
    keyMappings.removeAll()
    setupDefaultMappings()
    isKeyboardInputEnabled = true
    keyboardSensitivity = 1.0
    saveToUserDefaults()
  }
  
  func getKeyForCommand(_ command: JoystickKeyCommand) -> KeyEquivalent {
    return keyMappings[command] ?? command.defaultKey
  }
  
  func setKeyForCommand(_ command: JoystickKeyCommand, key: KeyEquivalent) {
    keyMappings[command] = key
    saveToUserDefaults()
  }
  
  func isArrowKey(_ key: KeyEquivalent) -> Bool {
    let arrowCommands: [JoystickKeyCommand] = [.up, .down, .left, .right]
    return arrowCommands.contains { getKeyForCommand($0) == key }
  }
  
  func isResetKey(_ key: KeyEquivalent) -> Bool {
    return getKeyForCommand(.reset) == key
  }
  
  // NY: Uppdatera enabled joysticks när antalet ändras
  func updateEnabledJoysticksForCurrentCount() {
    let currentCount = VirtualJoystickManager.shared.configuration.numberOfJoysticks
    
    // NY: ALLA nya joysticks ska vara aktiverade som default
    for i in 0..<currentCount {
      enabledJoystickIndices.insert(i)
    }
    
    // Ta bort joysticks som inte längre finns
    enabledJoystickIndices = enabledJoystickIndices.filter { $0 < currentCount }
    
    print("🎹 KeyCommandConfiguration: Updated enabled joysticks to: \(enabledJoystickIndices)")
    saveToUserDefaults()
  }
  
  // NY: Kontrollera om en specifik joystick är aktiverad för tangentbordskontroll
  func isJoystickKeyboardEnabled(_ index: Int) -> Bool {
    return enabledJoystickIndices.contains(index)
  }
  
  // NY: Aktivera/deaktivera tangentbordskontroll för specifik joystick
  func setJoystickKeyboardEnabled(_ index: Int, enabled: Bool) {
    if enabled {
      enabledJoystickIndices.insert(index)
    } else {
      enabledJoystickIndices.remove(index)
    }
  }
}

// MARK: - Keyboard Input Handling
class KeyboardInputHandler {
  static let shared = KeyboardInputHandler()
  
  private var cancellables = Set<AnyCancellable>()
  
  private init() {
    // NY: Lyssna på ändringar av aktiverade joysticks
    KeyCommandManager.shared.configuration.$enabledJoystickIndices
      .sink { indices in
        print("🎹 Enabled joystick indices updated: \(indices)")
      }
      .store(in: &cancellables)
  }
}

// MARK: - Key Command Manager (Singleton)
class KeyCommandManager: ObservableObject {
  static let shared = KeyCommandManager()
  
  @Published var configuration = KeyCommandConfiguration()
  @Published var inputState = KeyboardInputState()
  
  // NY: Callbacks för alla joysticks
  internal var joystickCallbacks: [Int: (CGPoint) -> Void] = [:]
  private var inputMethodCallbacks: [Int: (InputMethod) -> Void] = [:]
  
  private init() {
    setupCallbacks()
  }
  
  private func setupCallbacks() {
    // Lyssna på konfigurationsändringar
    configuration.$isKeyboardInputEnabled
      .sink { [weak self] enabled in
        if !enabled {
          self?.inputState.reset()
        }
      }
      .store(in: &cancellables)
    
    // NY: Setup multi-joystick callback
    inputState.onMultiJoystickPositionChanged = { [weak self] position, joystickIndex in
      self?.notifyJoystick(joystickIndex, position: position)
    }
  }
  
  private var cancellables = Set<AnyCancellable>()
  
  // MARK: - Public Interface
  
  func handleKeyPress(_ keyPress: KeyPress) -> KeyPress.Result {
    print("🎹 KeyCommandManager.handleKeyPress: \(keyPress.key), phase: \(keyPress.phase)")
    
    guard configuration.isKeyboardInputEnabled else { 
      print("🎹 Keyboard input is DISABLED")
      return .ignored 
    }
    
    let key = keyPress.key
    
    switch keyPress.phase {
    case .down:
      if configuration.isResetKey(key) {
        print("🎹 Reset key detected: \(key)")
        inputState.reset()
        return .handled
      }
      
      if configuration.isArrowKey(key) {
        print("🎹 Arrow key DOWN detected: \(key)")
        inputState.addPressedKey(key)
        return .handled
      }
      
      print("🎹 Key not handled: \(key)")
      
    case .up:
      if configuration.isArrowKey(key) {
        print("🎹 Arrow key UP detected: \(key)")
        inputState.removePressedKey(key)
        return .handled
      }
      
      if configuration.isResetKey(key) {
        print("🎹 Reset key UP detected: \(key)")
        return .handled
      }
      
    case .repeat:
      // NY: Ignorera repeat events för arrow keys (de hanteras av timer istället)
      if configuration.isArrowKey(key) || configuration.isResetKey(key) {
        return .handled
      }
      
    default:
      break
    }
    
    return .ignored
  }
  
  // NY: Registrera callback för specifik joystick - FÖRENKLAD
  func setPositionCallback(for joystickIndex: Int, _ callback: @escaping (CGPoint) -> Void) {
    print("🎹 KeyCommandManager: Registering position callback for joystick \(joystickIndex)")
    
    joystickCallbacks[joystickIndex] = { position in
      // Applicera sensitivity
      let adjustedPosition = CGPoint(
        x: position.x * self.configuration.keyboardSensitivity,
        y: position.y * self.configuration.keyboardSensitivity
      )
      callback(adjustedPosition)
    }
    
    print("🎹 KeyCommandManager: Total registered callbacks: \(joystickCallbacks.count)")
    print("🎹 KeyCommandManager: Registered indices: \(Array(joystickCallbacks.keys).sorted())")
  }
  
  // NY: Registrera input method callback för specifik joystick  
  func setInputMethodCallback(for joystickIndex: Int, _ callback: @escaping (InputMethod) -> Void) {
    print("🎹 KeyCommandManager: Registering input method callback for joystick \(joystickIndex)")
    inputMethodCallbacks[joystickIndex] = callback
  }
  
  // NY: Notifiera specifik joystick
  private func notifyJoystick(_ index: Int, position: CGPoint) {
    print("🎹 KeyCommandManager.notifyJoystick: index=\(index), position=\(position)")
    joystickCallbacks[index]?(position)
  }
  
  // Gamla metoder för backwards compatibility
  func setPositionCallback(_ callback: @escaping (CGPoint) -> Void) {
    setPositionCallback(for: 0, callback)
  }
  
  func setInputMethodCallback(_ callback: @escaping (InputMethod) -> Void) {
    setInputMethodCallback(for: 0, callback)
  }
  
  func getCurrentPosition() -> CGPoint {
    return inputState.currentPosition
  }
  
  func isKeyboardActive() -> Bool {
    return inputState.isActive
  }
  
  func resetInput() {
    inputState.reset()
  }
  
  // NY: Rensa callbacks när joysticks tas bort
  func clearCallbacks(for joystickIndex: Int) {
    joystickCallbacks.removeValue(forKey: joystickIndex)
    inputMethodCallbacks.removeValue(forKey: joystickIndex)
  }
  
  // NY: Rensa alla callbacks
  func clearAllCallbacks() {
    print("🎹 KeyCommandManager: Clearing all callbacks (had \(joystickCallbacks.count) callbacks)")
    joystickCallbacks.removeAll()
    inputMethodCallbacks.removeAll()
    print("🎹 KeyCommandManager: All callbacks cleared")
  }
  
  // NY: Få antal registrerade callbacks (för debugging)
  func getRegisteredCallbackCount() -> Int {
    return joystickCallbacks.count
  }
  
  // NY: Få alla registrerade joystick index (för debugging)
  func getRegisteredJoystickIndices() -> [Int] {
    return Array(joystickCallbacks.keys).sorted()
  }
}

// MARK: - Helper Functions
private func keyEquivalentToString(_ key: KeyEquivalent) -> String {
  switch key {
  case .upArrow: return "upArrow"
  case .downArrow: return "downArrow"
  case .leftArrow: return "leftArrow"
  case .rightArrow: return "rightArrow"
  case .space: return "space"
  case .return: return "return"
  case .tab: return "tab"
  case .escape: return "escape"
  default: return "\(key)"
  }
}

private func keyEquivalentFromString(_ string: String) -> KeyEquivalent? {
  switch string {
  case "upArrow": return .upArrow
  case "downArrow": return .downArrow
  case "leftArrow": return .leftArrow
  case "rightArrow": return .rightArrow
  case "space": return .space
  case "return": return .return
  case "tab": return .tab
  case "escape": return .escape
  default: return nil
  }
}

// MARK: - Key Command Settings View
