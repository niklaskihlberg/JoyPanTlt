//
//  AppCoordinator.swift
//  JoyPanTlt
//
//  Created by Niklas Kihlberg on 2025-06-29.
//

import Foundation

// MARK: - App Coordinator
class AppCoordinator {
    // MARK: - Services (Lazy-loaded singletons)
    lazy var oscService: any OSCServiceProtocol = OSCService()
    lazy var midiService: any MIDIServiceProtocol = MIDIService()
    lazy var configService: any ConfigurationServiceProtocol = UserDefaultsConfigurationService()
    
    // MARK: - Configuration Managers (Will be migrated gradually)
    lazy var virtualJoystickManager = VirtualJoystickManager.shared
    lazy var gamepadManager = GamepadManager.shared
    
    // MARK: - Shared Configuration Objects
    lazy var virtualJoystickConfig = VirtualJoystickConfiguration() // Ändra namn för bättre tillgänglighet
    lazy var sharedVirtualJoystickConfig = virtualJoystickConfig // Behåll bakåtkompatibilitet
    
    // MARK: - View Model Factories
    func makeContentViewModel() -> ContentViewModel {
        return ContentViewModel(
            oscService: oscService,
            midiService: midiService,
            configService: configService,
            virtualJoystickConfig: sharedVirtualJoystickConfig
        )
    }
    
    func makeConfigurationViewModel() -> ConfigurationViewModel {
        return ConfigurationViewModel(
            oscService: oscService,
            midiService: midiService,
            configService: configService,
            virtualJoystickConfig: sharedVirtualJoystickConfig
        )
    }
    
    func makeHelpViewModel() -> HelpViewModel {
        return HelpViewModel()
    }
}
