//
//  GamepadConfiguration.swift
//  JoyPanTlt
//
//  Created by Niklas Kihlberg on 2025-06-25.
//

import Foundation
import GameController
import SwiftUI
import Combine

// MARK: - Gamepad Configuration Model
class GamepadConfiguration: ObservableObject {
    // Published properties för SwiftUI binding
    @Published var selectedGamepadIndex: Int = 0 {
        didSet { saveToUserDefaults() }
    }
    
    @Published var selectedJoystickType: JoystickType = .leftThumbstick {
        didSet { saveToUserDefaults() }
    }
    
    @Published var invertXAxis: Bool = false {
        didSet { saveToUserDefaults() }
    }
    
    @Published var invertYAxis: Bool = false {
        didSet { saveToUserDefaults() }
    }
    
    @Published var sensitivity: Double = 1.0 {
        didSet { saveToUserDefaults() }
    }
    
    @Published var deadzone: Double = 0.1 {
        didSet { saveToUserDefaults() }
    }
    
    // Status properties
    @Published var availableGamepads: [GCController] = []
    @Published var isGamepadConnected: Bool = false
    @Published var currentGamepadName: String = "No gamepad connected"
    
    // UserDefaults keys
    private let selectedGamepadKey = "Gamepad_SelectedIndex"
    private let selectedJoystickKey = "Gamepad_SelectedJoystick"
    private let invertXKey = "Gamepad_InvertX"
    private let invertYKey = "Gamepad_InvertY"
    private let sensitivityKey = "Gamepad_Sensitivity"
    private let deadzoneKey = "Gamepad_Deadzone"
    
    init() {
        loadFromUserDefaults()
        setupGamepadNotifications()
        updateAvailableGamepads()
    }
    
    // MARK: - Joystick Types
    enum JoystickType: Int, CaseIterable {
        case leftThumbstick = 0
        case rightThumbstick = 1
        case dpad = 2
        
        var displayName: String {
            switch self {
            case .leftThumbstick:
                return "Left Thumbstick"
            case .rightThumbstick:
                return "Right Thumbstick"
            case .dpad:
                return "D-Pad"
            }
        }
    }
    
    // MARK: - UserDefaults
    private func loadFromUserDefaults() {
        selectedGamepadIndex = UserDefaults.standard.integer(forKey: selectedGamepadKey)
        
        if let joystickRawValue = UserDefaults.standard.object(forKey: selectedJoystickKey) as? Int,
           let joystickType = JoystickType(rawValue: joystickRawValue) {
            selectedJoystickType = joystickType
        }
        
        invertXAxis = UserDefaults.standard.bool(forKey: invertXKey)
        invertYAxis = UserDefaults.standard.bool(forKey: invertYKey)
        sensitivity = UserDefaults.standard.object(forKey: sensitivityKey) as? Double ?? 1.0
        deadzone = UserDefaults.standard.object(forKey: deadzoneKey) as? Double ?? 0.1
    }
    
    private func saveToUserDefaults() {
        UserDefaults.standard.set(selectedGamepadIndex, forKey: selectedGamepadKey)
        UserDefaults.standard.set(selectedJoystickType.rawValue, forKey: selectedJoystickKey)
        UserDefaults.standard.set(invertXAxis, forKey: invertXKey)
        UserDefaults.standard.set(invertYAxis, forKey: invertYKey)
        UserDefaults.standard.set(sensitivity, forKey: sensitivityKey)
        UserDefaults.standard.set(deadzone, forKey: deadzoneKey)
    }
    
    // MARK: - Gamepad Management
    private func setupGamepadNotifications() {
        NotificationCenter.default.addObserver(
            forName: .GCControllerDidConnect,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateAvailableGamepads()
        }
        
        NotificationCenter.default.addObserver(
            forName: .GCControllerDidDisconnect,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateAvailableGamepads()
        }
    }
    
    private func updateAvailableGamepads() {
        availableGamepads = GCController.controllers()
        isGamepadConnected = !availableGamepads.isEmpty
        
        if isGamepadConnected {
            let selectedGamepad = getSelectedGamepad()
            currentGamepadName = selectedGamepad?.vendorName ?? "Unknown Gamepad"
        } else {
            currentGamepadName = "No gamepad connected"
        }
    }
    
    func getSelectedGamepad() -> GCController? {
        guard selectedGamepadIndex < availableGamepads.count else {
            return availableGamepads.first
        }
        return availableGamepads[selectedGamepadIndex]
    }
    
    // MARK: - Validation
    func resetToDefaults() {
        selectedGamepadIndex = 0
        selectedJoystickType = .leftThumbstick
        invertXAxis = false
        invertYAxis = false
        sensitivity = 1.0
        deadzone = 0.1
    }
}

// MARK: - Gamepad Backend
class GamepadBackend: ObservableObject {
    private let configuration: GamepadConfiguration
    private var currentController: GCController?
    private var cancellables = Set<AnyCancellable>()
    
    // Callback för joystick-värden
    var onJoystickChanged: ((CGPoint) -> Void)?
    
    init(configuration: GamepadConfiguration) {
        self.configuration = configuration
        // Flytta setupGamepadInput() till efter init
    }
    
    // MARK: - Input Setup
    func setupGamepadInput() {
        // Observera när gamepad-konfiguration ändras
        configuration.$selectedGamepadIndex.sink { [weak self] _ in
            self?.updateControllerInput()
        }.store(in: &cancellables)
        
        configuration.$selectedJoystickType.sink { [weak self] _ in
            self?.updateControllerInput()
        }.store(in: &cancellables)
        
        // Initial setup
        updateControllerInput()
    }
    
    private func updateControllerInput() {
        currentController = configuration.getSelectedGamepad()
        
        guard let controller = currentController,
              let extendedGamepad = controller.extendedGamepad else {
            return
        }
        
        // Sätt upp input-handlers baserat på vald joystick-typ
        switch configuration.selectedJoystickType {
        case .leftThumbstick:
            setupThumbstickInput(extendedGamepad.leftThumbstick)
        case .rightThumbstick:
            setupThumbstickInput(extendedGamepad.rightThumbstick)
        case .dpad:
            setupDPadInput(extendedGamepad.dpad)
        }
    }
    
    private func setupThumbstickInput(_ thumbstick: GCControllerDirectionPad) {
        thumbstick.valueChangedHandler = { [weak self] (dpad, xValue, yValue) in
            self?.processJoystickInput(x: xValue, y: yValue)
        }
    }
    
    private func setupDPadInput(_ dpad: GCControllerDirectionPad) {
        dpad.valueChangedHandler = { [weak self] (dpad, xValue, yValue) in
            self?.processJoystickInput(x: xValue, y: yValue)
        }
    }
    
    // MARK: - Input Processing
    private func processJoystickInput(x: Float, y: Float) {
        var processedX = Double(x)
        var processedY = Double(y)
        
        // Applicera deadzone
        let magnitude = sqrt(processedX * processedX + processedY * processedY)
        if magnitude < configuration.deadzone {
            processedX = 0
            processedY = 0
        } else {
            // Normalisera efter deadzone
            let normalizedMagnitude = (magnitude - configuration.deadzone) / (1.0 - configuration.deadzone)
            let angle = atan2(processedY, processedX)
            processedX = cos(angle) * normalizedMagnitude
            processedY = sin(angle) * normalizedMagnitude
        }
        
        // Applicera känslighet
        processedX *= configuration.sensitivity
        processedY *= configuration.sensitivity
        
        // Applicera axel-inversion
        if configuration.invertXAxis {
            processedX = -processedX
        }
        if configuration.invertYAxis {
            processedY = -processedY
        }
        
        // Begränsa till [-1, 1]
        processedX = max(-1.0, min(1.0, processedX))
        processedY = max(-1.0, min(1.0, processedY))
        
        // Skicka processade värden
        let point = CGPoint(x: processedX, y: processedY)
        
        DispatchQueue.main.async {
            self.onJoystickChanged?(point)
        }
    }
    
    // MARK: - Public Methods
    func startInput() {
        updateControllerInput()
    }
    
    func stopInput() {
        // Nollställ input handlers
        currentController?.extendedGamepad?.leftThumbstick.valueChangedHandler = nil
        currentController?.extendedGamepad?.rightThumbstick.valueChangedHandler = nil
        currentController?.extendedGamepad?.dpad.valueChangedHandler = nil
    }
    
    // MARK: - Test Functions
    func testCurrentGamepad() {
        guard let controller = currentController else {
            print("No gamepad connected")
            return
        }
        
        print("Testing gamepad: \(controller.vendorName ?? "Unknown")")
        print("Selected joystick: \(configuration.selectedJoystickType.displayName)")
    }
}

// MARK: - Gamepad Manager (Singleton)
class GamepadManager: ObservableObject {
    static let shared = GamepadManager()
    
    @Published var configuration: GamepadConfiguration
    @Published var backend: GamepadBackend
    
    private init() {
        // Skapa konfiguration först
        let config = GamepadConfiguration()
        
        // Tilldela alla stored properties
        self.configuration = config
        self.backend = GamepadBackend(configuration: config)
        
        // Sätt upp gamepad input efter init
        self.backend.setupGamepadInput()
    }
    
    func setJoystickCallback(_ callback: @escaping (CGPoint) -> Void) {
        backend.onJoystickChanged = callback
    }
    
    func startGamepadInput() {
        backend.startInput()
    }
    
    func stopGamepadInput() {
        backend.stopInput()
    }
}

// MARK: - Helper Extensions
extension GamepadConfiguration {
    var gamepadInfo: String {
        if isGamepadConnected {
            return "\(currentGamepadName) - \(selectedJoystickType.displayName)"
        } else {
            return "No gamepad connected"
        }
    }
    
    var settingsInfo: String {
        return "Sensitivity: \(String(format: "%.1f", sensitivity)), Deadzone: \(String(format: "%.1f", deadzone))"
    }
}

