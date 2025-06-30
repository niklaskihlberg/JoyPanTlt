//
//  ContentViewModel.swift
//  JoyPanTlt
//
//  Created by Niklas Kihlberg on 2025-06-29.
//

import Foundation
import SwiftUI
import Combine
import Cocoa

// MARK: - Content View Model
class ContentViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var panTiltValues: [(pan: Double, tilt: Double)] = [(0.0, 0.0)]
    @Published var joystickInstances: [JoystickInstance] = []
    @Published var keyboardControlledPositions: [CGPoint] = [CGPoint.zero] // För tangentbordsstyrning
    
    // MARK: - Configuration (Integrera med befintlig konfiguration)
    let virtualJoystickConfig: VirtualJoystickConfiguration
    
    // Computed property för numberOfJoysticks
    var numberOfJoysticks: Int {
        return virtualJoystickConfig.numberOfJoysticks
    }
    
    // MARK: - Dependencies
    private let oscService: any OSCServiceProtocol
    private let midiService: any MIDIServiceProtocol
    private let configService: any ConfigurationServiceProtocol
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private var activeKeys = Set<KeyEquivalent>() // Håll koll på aktiva tangenter
    private var keyboardTimer: Timer? // Timer för kontinuerlig uppdatering
    
    // MARK: - Initialization
    init(
        oscService: any OSCServiceProtocol,
        midiService: any MIDIServiceProtocol,
        configService: any ConfigurationServiceProtocol,
        virtualJoystickConfig: VirtualJoystickConfiguration
    ) {
        self.oscService = oscService
        self.midiService = midiService
        self.configService = configService
        self.virtualJoystickConfig = virtualJoystickConfig
        
        loadConfiguration()
        setupBindings()
    }
    
    // MARK: - Configuration Management
    private func loadConfiguration() {
        // Load joystick instances from VirtualJoystickConfiguration
        joystickInstances = virtualJoystickConfig.joystickInstances
        
        if joystickInstances.isEmpty {
            // Create default joystick if none exist
            createDefaultJoysticks(count: 1)
        }
        
        initializePanTiltValues()
    }
    
    private func setupBindings() {
        // Watch for changes to numberOfJoysticks in virtualJoystickConfig
        virtualJoystickConfig.$numberOfJoysticks
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newCount in
                self?.onNumberOfJoysticksChanged(newCount: newCount)
            }
            .store(in: &cancellables)
        
        // Watch for changes to joystickInstances in virtualJoystickConfig
        virtualJoystickConfig.$joystickInstances
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newInstances in
                self?.joystickInstances = newInstances
                self?.initializePanTiltValues()
            }
            .store(in: &cancellables)
    }
    
    private func initializePanTiltValues() {
        panTiltValues = Array(repeating: (pan: 0.0, tilt: 0.0), count: numberOfJoysticks)
        keyboardControlledPositions = Array(repeating: CGPoint.zero, count: numberOfJoysticks)
    }
    
    private func updateJoystickInstances(count: Int) {
        let currentCount = joystickInstances.count
        
        if count > currentCount {
            // Add new joysticks
            for i in currentCount..<count {
                let newJoystick = JoystickInstance(
                    name: "Joystick \(i + 1)",
                    oscPanAddress: "/lightkey/layers/layer\(i + 1)/pan",
                    oscTiltAddress: "/lightkey/layers/layer\(i + 1)/tilt",
                    midiChannel: i + 1,
                    midiCCPan: (i * 2) + 1,
                    midiCCTilt: (i * 2) + 2
                )
                joystickInstances.append(newJoystick)
            }
        } else if count < currentCount {
            // Remove extra joysticks
            joystickInstances = Array(joystickInstances.prefix(count))
        }
    }
    
    private func createDefaultJoysticks(count: Int) {
        joystickInstances = []
        for i in 0..<count {
            let joystick = JoystickInstance(
                name: "Joystick \(i + 1)",
                oscPanAddress: "/fixture/selected/overrides/panAngle",
                oscTiltAddress: "/fixture/selected/overrides/tiltAngle",
                midiChannel: i + 1,
                midiCCPan: (i * 2) + 1,
                midiCCTilt: (i * 2) + 2
            )
            joystickInstances.append(joystick)
        }
    }
    
    // MARK: - Public Methods
    func updatePanTilt(from position: CGPoint, joystickIndex: Int) {
        guard joystickIndex < joystickInstances.count else { return }
        
        let result = TranslationResult.from(normalizedPosition: position)
        let joystick = joystickInstances[joystickIndex]
        
        // Update local state
        if joystickIndex < panTiltValues.count {
            panTiltValues[joystickIndex] = (pan: result.pan, tilt: result.tilt)
        }
        
        // Send via OSC
        if oscService.isEnabled {
            oscService.sendPanTilt(
                pan: result.pan,
                tilt: result.tilt,
                panAddress: joystick.oscPanAddress,
                tiltAddress: joystick.oscTiltAddress
            )
        }
        
        // Send via MIDI
        if midiService.isEnabled {
            let midiConfig = JoystickMIDIConfig(
                name: joystick.name,
                panChannel: joystick.midiChannel,
                panController: joystick.midiCCPan,
                tiltChannel: joystick.midiChannel,
                tiltController: joystick.midiCCTilt
            )
            midiService.sendPanTilt(pan: result.pan, tilt: result.tilt, config: midiConfig)
        }
        
        print("🕹️ \(joystick.name): Pan=\(String(format: "%.1f", result.pan))°, Tilt=\(String(format: "%.1f", result.tilt))°")
    }
    
    func getEnabledJoysticks() -> [JoystickInstance] {
        return joystickInstances.filter { $0.isEnabled }
    }
    
    func updateJoystick(_ joystick: JoystickInstance) {
        if let index = joystickInstances.firstIndex(where: { $0.id == joystick.id }) {
            joystickInstances[index] = joystick
        }
    }
    
    // MARK: - Key Handling
    func handleKeyPress(_ keyPress: KeyPress) -> KeyPress.Result {
        print("🎹 ContentViewModel: Handling key press: \(keyPress.key), phase: \(keyPress.phase)")
        
        let key = keyPress.key
        
        // Handle different key phases
        switch keyPress.phase {
        case .down:
            return handleKeyDown(keyPress)
        case .up:
            return handleKeyUp(keyPress)
        case .repeat:
            return handleKeyRepeat(keyPress)
        default:
            return .ignored
        }
    }
    
    private func handleKeyDown(_ key: KeyPress) -> KeyPress.Result {
        print("🎹 Key down: \(key)")
        
        // Handle arrow keys for joystick movement (momentary style)
        switch key.key {
        case .upArrow, .downArrow, .leftArrow, .rightArrow:
            activeKeys.insert(key.key)
            startKeyboardTimer()
            return .handled
        case .space:
            resetJoystick()
            return .handled
        default:
            return .ignored
        }
    }
    
    private func handleKeyUp(_ key: KeyPress) -> KeyPress.Result {
        print("🎹 Key up: \(key)")
        
        // Stop movement when key is released (momentary style)
        switch key.key {
        case .upArrow, .downArrow, .leftArrow, .rightArrow:
            activeKeys.remove(key.key)
            if activeKeys.isEmpty {
                stopKeyboardTimer()
                resetJoystickToCenter() // Återfjädra till centrum
            } else {
                updateJoystickFromActiveKeys() // Uppdatera för resterande tangenter
            }
            return .handled
        default:
            return .ignored
        }
    }
    
    private func handleKeyRepeat(_ key: KeyPress) -> KeyPress.Result {
        // För momentary style behöver vi inte hantera repeat - timer sköter kontinuerlig uppdatering
        return .handled
    }
    
    // MARK: - Momentary Keyboard Control
    private func startKeyboardTimer() {
        stopKeyboardTimer() // Stoppa befintlig timer
        keyboardTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in // ~60 FPS
            self.updateJoystickFromActiveKeys()
        }
    }
    
    private func stopKeyboardTimer() {
        keyboardTimer?.invalidate()
        keyboardTimer = nil
    }
    
    private func updateJoystickFromActiveKeys() {
        guard numberOfJoysticks > 0 else { return }
        
        let joystickIndex = 0 // Kontrollera första joysticken
        var newPan: Double = 0.0
        var newTilt: Double = 0.0
        
        // Beräkna position baserat på aktiva tangenter (100% när nedtryckt)
        if activeKeys.contains(.leftArrow) {
            newPan -= 1.0
        }
        if activeKeys.contains(.rightArrow) {
            newPan += 1.0
        }
        if activeKeys.contains(.downArrow) {
            newTilt -= 1.0
        }
        if activeKeys.contains(.upArrow) {
            newTilt += 1.0
        }
        
        // Normalisera diagonal rörelser (så att diagonal inte blir 1.41x snabbare)
        let magnitude = sqrt(newPan * newPan + newTilt * newTilt)
        if magnitude > 1.0 {
            newPan /= magnitude
            newTilt /= magnitude
        }
        
        // Update position
        panTiltValues[joystickIndex] = (pan: newPan, tilt: newTilt)
        
        // Update keyboard controlled position for UI
        let normalizedPosition = CGPoint(x: newPan, y: newTilt)
        if joystickIndex < keyboardControlledPositions.count {
            keyboardControlledPositions[joystickIndex] = normalizedPosition
        }
        
        // Send to services
        sendPanTiltToServices(pan: newPan, tilt: newTilt, joystickIndex: joystickIndex)
        
        print("🎹 Keyboard position: pan=\(String(format: "%.2f", newPan)), tilt=\(String(format: "%.2f", newTilt))")
    }
    
    private func resetJoystickToCenter() {
        guard numberOfJoysticks > 0 else { return }
        
        let joystickIndex = 0
        panTiltValues[joystickIndex] = (pan: 0.0, tilt: 0.0)
        
        // Reset keyboard controlled position for UI
        if joystickIndex < keyboardControlledPositions.count {
            keyboardControlledPositions[joystickIndex] = CGPoint.zero
        }
        
        // Send reset to services
        sendPanTiltToServices(pan: 0.0, tilt: 0.0, joystickIndex: joystickIndex)
        
        print("🎹 Keyboard reset to center")
    }
    
    // MARK: - Joystick Movement
    private enum MoveDirection {
        case up, down, left, right
    }
    
    private func moveJoystick(direction: MoveDirection) {
        guard numberOfJoysticks > 0 else { return }
        
        let joystickIndex = 0 // For now, control the first joystick
        let currentPosition = panTiltValues[joystickIndex]
        let moveAmount = 0.1 // Movement speed
        
        var newPan = currentPosition.pan
        var newTilt = currentPosition.tilt
        
        switch direction {
        case .up:
            newTilt = min(1.0, currentPosition.tilt + moveAmount)
        case .down:
            newTilt = max(-1.0, currentPosition.tilt - moveAmount)
        case .left:
            newPan = max(-1.0, currentPosition.pan - moveAmount)
        case .right:
            newPan = min(1.0, currentPosition.pan + moveAmount)
        }
        
        // Update position
        panTiltValues[joystickIndex] = (pan: newPan, tilt: newTilt)
        
        // Update keyboard controlled position for UI
        let normalizedPosition = CGPoint(x: newPan, y: newTilt)
        if joystickIndex < keyboardControlledPositions.count {
            keyboardControlledPositions[joystickIndex] = normalizedPosition
        }
        
        // Send to services
        sendPanTiltToServices(pan: newPan, tilt: newTilt, joystickIndex: joystickIndex)
        
        print("🎹 Moved joystick \(joystickIndex) to pan: \(newPan), tilt: \(newTilt)")
    }
    
    private func resetJoystick() {
        guard numberOfJoysticks > 0 else { return }
        
        let joystickIndex = 0 // For now, reset the first joystick
        panTiltValues[joystickIndex] = (pan: 0.0, tilt: 0.0)
        
        // Reset keyboard controlled position for UI
        if joystickIndex < keyboardControlledPositions.count {
            keyboardControlledPositions[joystickIndex] = CGPoint.zero
        }
        
        // Send reset to services
        sendPanTiltToServices(pan: 0.0, tilt: 0.0, joystickIndex: joystickIndex)
        
        print("🎹 Reset joystick \(joystickIndex) to center")
    }
    
    // MARK: - Private Helper Methods
    private func sendPanTiltToServices(pan: Double, tilt: Double, joystickIndex: Int) {
        guard joystickIndex < joystickInstances.count else { return }
        
        let joystick = joystickInstances[joystickIndex]
        
        // Send via OSC if enabled
        if let oscService = oscService as? OSCService, oscService.isEnabled {
            oscService.sendPanTilt(
                pan: pan,
                tilt: tilt,
                panAddress: joystick.oscPanAddress,
                tiltAddress: joystick.oscTiltAddress
            )
        }
        
        // Send via MIDI if enabled
        if let midiService = midiService as? MIDIService, midiService.isEnabled {
            let midiConfig = JoystickMIDIConfig(
                name: joystick.name,
                panChannel: joystick.midiChannel,
                panController: joystick.midiCCPan,
                tiltChannel: joystick.midiChannel,
                tiltController: joystick.midiCCTilt
            )
            midiService.sendPanTilt(pan: pan, tilt: tilt, config: midiConfig)
        }
    }
    
    // MARK: - Lifecycle Methods
    func onViewAppear() {
        print("🎹 ContentView onAppear: Number of joysticks = \(numberOfJoysticks)")
        
        // Sätt initial fönster-storlek baserat på antal joysticks
        DispatchQueue.main.async {
            self.adjustWindowSizeForJoysticks(count: self.numberOfJoysticks)
        }
    }
    
    deinit {
        stopKeyboardTimer()
    }
    
    func onNumberOfJoysticksChanged(newCount: Int) {
        print("🎹 ContentView: Number of joysticks changed to \(newCount)")
        updateJoystickInstances(count: newCount)
        initializePanTiltValues()
        
        // Update the configuration to match
        virtualJoystickConfig.joystickInstances = joystickInstances
        
        // Anpassa fönster-storlek för att förhindra beskärning
        DispatchQueue.main.async {
            self.adjustWindowSizeForJoysticks(count: newCount)
        }
    }
    
    // MARK: - Layout Helpers (Public)
    func calculateColumns(for joystickCount: Int) -> Int {
        switch joystickCount {
        case 1: return 1
        case 2: return 2
        case 3...4: return 2
        case 5...6: return 3
        case 7...9: return 3
        default: return 4
        }
    }
    
    // MARK: - Layout Helpers
    func calculateJoystickSize(for windowSize: CGSize) -> CGFloat {
        let enabledCount = getEnabledJoysticks().count
        
        if enabledCount == 1 {
            // Ge joysticken mer plats när det bara finns en
            let maxPossibleSize = min(windowSize.width - 80, windowSize.height - 100) // Mindre säkerhetsmarginal
            return min(maxPossibleSize * 0.85, 220) // 85% av tillgängligt utrymme, max 220px
        } else {
            let columns = calculateColumns(for: enabledCount, aspectRatio: windowSize.width / windowSize.height)
            let availableWidth = windowSize.width - 60 // Mindre padding för mer plats åt joysticken
            let availableHeight = windowSize.height - 100 // Mindre padding
            
            let maxWidth = availableWidth / CGFloat(columns) - 25 // Minska grid spacing
            let rows = ceil(Double(enabledCount) / Double(columns))
            let maxHeight = availableHeight / CGFloat(rows) - 25 // Minska vertikala marginalerna
            
            return min(maxWidth, maxHeight, 200) // Samma max-storlek för multi-joysticks
        }
    }
    
    private func calculateColumns(for count: Int, aspectRatio: Double) -> Int {
        switch count {
        case 1: return 1
        case 2: return aspectRatio > 1.5 ? 2 : 1
        case 3: return aspectRatio > 1.5 ? 3 : 2
        case 4: return 2
        case 5...6: return aspectRatio > 1.3 ? 3 : 2
        case 7...8: return aspectRatio > 1.8 ? 4 : 3
        default: return min(count, 4)
        }
    }
    
    // MARK: - Window Management
    func calculateMinimumWindowSize(for joystickCount: Int) -> CGSize {
        let columns = calculateColumns(for: joystickCount)
        let rows = Int(ceil(Double(joystickCount) / Double(columns)))
        
        // Optimal joystick-storlek med mer konservativ padding
        let minJoystickSize: CGFloat = 160 // Behåll rimlig storlek för joysticken
        let shadowPadding: CGFloat = 40 // Minska padding för shadows + layout
        let spacing: CGFloat = 15 // Matcha ContentView spacing
        
        let minWidth = CGFloat(columns) * minJoystickSize + CGFloat(columns - 1) * spacing + shadowPadding
        let minHeight = CGFloat(rows) * minJoystickSize + CGFloat(rows - 1) * spacing + shadowPadding + 50 // Mindre UI space
        
        return CGSize(width: max(minWidth, 480), height: max(minHeight, 380)) // Mindre minimum men fortfarande säkert
    }
    
    func adjustWindowSizeForJoysticks(count: Int) {
        guard let window = NSApplication.shared.windows.first else { return }
        
        let currentSize = window.frame.size
        let minSize = calculateMinimumWindowSize(for: count)
        
        // Sätt ny minimum storlek - detta förhindrar användaren från att göra fönstret för litet
        window.minSize = minSize
        print("📏 ContentViewModel: Set minimum window size to \(minSize.width)x\(minSize.height) for \(count) joysticks")
        
        // ALLTID förstora fönstret om det är för litet för att rymma innehållet ordentligt
        let requiredWidth = max(currentSize.width, minSize.width + 40) // Mindre säkerhetsmarginal
        let requiredHeight = max(currentSize.height, minSize.height + 40) // Mindre säkerhetsmarginal
        
        if currentSize.width < requiredWidth || currentSize.height < requiredHeight {
            let newSize = CGSize(width: requiredWidth, height: requiredHeight)
            
            let currentFrame = window.frame
            let newFrame = NSRect(
                x: currentFrame.origin.x,
                y: currentFrame.origin.y - (newSize.height - currentSize.height), // Behåll top-left position
                width: newSize.width,
                height: newSize.height
            )
            
            window.setFrame(newFrame, display: true, animate: true)
            print("🔧 ContentViewModel: Resized window to \(newSize.width)x\(newSize.height) to fit \(count) joysticks")
        }
        
        // Extra säkerhetscheck - sätt maxSize om fönstret är extremt litet
        if window.frame.size.width < minSize.width || window.frame.size.height < minSize.height {
            let safeSize = CGSize(width: minSize.width + 40, height: minSize.height + 40)
            let safeFrame = NSRect(
                x: window.frame.origin.x,
                y: window.frame.origin.y - (safeSize.height - window.frame.size.height),
                width: safeSize.width,
                height: safeSize.height
            )
            window.setFrame(safeFrame, display: true, animate: false)
            print("🚨 ContentViewModel: Emergency resize to \(safeSize.width)x\(safeSize.height)")
        }
    }
}
