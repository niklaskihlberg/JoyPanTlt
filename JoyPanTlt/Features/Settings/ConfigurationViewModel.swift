//
//  ConfigurationViewModel.swift
//  JoyPanTlt
//
//  Created by Niklas Kihlberg on 2025-06-29.
//

import Foundation
import Combine

// MARK: - Configuration View Model
class ConfigurationViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var selectedTab: SettingsTab = .virtualJoystick
    
    // OSC Settings
    @Published var oscHost: String = "127.0.0.1"
    @Published var oscPort: Int = 21600
    @Published var oscIsEnabled: Bool = false
    @Published var oscIsConnected: Bool = false
    
    // MIDI Settings
    @Published var midiIsEnabled: Bool = false
    @Published var midiDestinations: [(name: String, id: String)] = []
    @Published var selectedMIDIDestination: String = ""
    
    // MARK: - Dependencies
    private let oscService: any OSCServiceProtocol
    private let midiService: any MIDIServiceProtocol
    private let configService: any ConfigurationServiceProtocol
    let virtualJoystickConfig: VirtualJoystickConfiguration
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Settings Tabs
    enum SettingsTab: String, CaseIterable {
        case virtualJoystick = "Virtual Joystick"
        case osc = "OSC"
        case midi = "MIDI"
        case gamepad = "Gamepad"
        case keyCommand = "Key Commands"
        
        var icon: String {
            switch self {
            case .virtualJoystick:
                return "dot.circle.and.hand.point.up.left.fill"
            case .osc:
                return "network"
            case .midi:
                return "pianokeys"
            case .gamepad:
                return "gamecontroller.fill"
            case .keyCommand:
                return "keyboard"
            }
        }
    }
    
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
        // Load OSC settings
        oscHost = configService.string(forKey: "OSC_Host") ?? "127.0.0.1"
        oscPort = configService.integer(forKey: "OSC_Port") != 0 ? configService.integer(forKey: "OSC_Port") : 21600
        oscIsEnabled = configService.bool(forKey: "OSC_IsEnabled")
        
        // Load MIDI settings
        midiIsEnabled = configService.bool(forKey: "MIDI_IsEnabled")
        selectedMIDIDestination = configService.string(forKey: "MIDI_SelectedDestination") ?? ""
        
        // Refresh MIDI destinations
        midiService.refreshDestinations()
    }
    
    private func setupBindings() {
        // OSC bindings
        $oscHost
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] host in
                self?.configService.set(host, forKey: "OSC_Host")
            }
            .store(in: &cancellables)
        
        $oscPort
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] port in
                self?.configService.set(port, forKey: "OSC_Port")
            }
            .store(in: &cancellables)
        
        $oscIsEnabled
            .sink { [weak self] enabled in
                self?.configService.set(enabled, forKey: "OSC_IsEnabled")
                // Enable/disable service
                if let oscService = self?.oscService as? OSCService {
                    oscService.isEnabled = enabled
                }
                
                if enabled {
                    Task {
                        await self?.connectOSC()
                    }
                } else {
                    self?.oscService.disconnect()
                }
            }
            .store(in: &cancellables)
        
        // MIDI bindings
        $midiIsEnabled
            .sink { [weak self] enabled in
                self?.configService.set(enabled, forKey: "MIDI_IsEnabled")
                // Enable/disable service
                if let midiService = self?.midiService as? MIDIService {
                    midiService.isEnabled = enabled
                }
            }
            .store(in: &cancellables)
        
        $selectedMIDIDestination
            .sink { [weak self] destination in
                self?.configService.set(destination, forKey: "MIDI_SelectedDestination")
                self?.midiService.selectDestination(id: destination)
            }
            .store(in: &cancellables)
        
        // Note: Service state updates would be handled here
        // when concrete implementations expose @Published properties
    }
    
    // MARK: - Public Methods
    func connectOSC() async {
        let success = await oscService.connect(host: oscHost, port: oscPort)
        if !success {
            // Handle connection failure
            print("❌ Failed to connect to OSC server")
        }
    }
    
    func disconnectOSC() {
        oscService.disconnect()
    }
    
    func testOSC() {
        oscService.sendTestMessage(to: "/test", value: 1.0)
    }
    
    func refreshMIDIDestinations() {
        midiService.refreshDestinations()
    }
    
    func testMIDI() {
        midiService.sendTestMessage()
    }
    
    func resetOSCToDefaults() {
        oscHost = "127.0.0.1"
        oscPort = 21600
        oscIsEnabled = false
    }
    
    func resetMIDIToDefaults() {
        midiIsEnabled = false
        selectedMIDIDestination = ""
    }
}
