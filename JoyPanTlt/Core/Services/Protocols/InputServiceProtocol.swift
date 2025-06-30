//
//  InputServiceProtocol.swift
//  JoyPanTlt
//
//  Created by Niklas Kihlberg on 2025-06-29.
//

import Foundation
import CoreGraphics
import Combine

// MARK: - Input Service Protocol
protocol InputServiceProtocol: ObservableObject {
    var isActive: Bool { get }
    var inputMethod: InputMethod { get }
    
    /// Starta input listening
    func startInput()
    
    /// Stoppa input listening  
    func stopInput()
    
    /// Callback när input ändras (normalized -1...1)
    var onInputChanged: ((CGPoint) -> Void)? { get set }
    
    /// Callback när input method ändras
    var onInputMethodChanged: ((InputMethod) -> Void)? { get set }
}

// MARK: - Gamepad Service Protocol
protocol GamepadServiceProtocol: InputServiceProtocol {
    var isGamepadConnected: Bool { get }
    var availableGamepads: [String] { get }
    var selectedGamepadIndex: Int { get set }
    var sensitivity: Double { get set }
    var deadzone: Double { get set }
    
    /// Uppdatera tillgängliga gamepads
    func refreshGamepads()
    
    /// Välj gamepad
    func selectGamepad(index: Int)
}

// MARK: - Configuration Service Protocol  
protocol ConfigurationServiceProtocol {
    /// Spara Codable objekt
    func save<T: Codable>(_ value: T, forKey key: String)
    
    /// Ladda Codable objekt
    func load<T: Codable>(_ type: T.Type, forKey key: String) -> T?
    
    /// Spara bastyper
    func set(_ value: Any?, forKey key: String)
    
    /// Ladda bastyper
    func object(forKey key: String) -> Any?
    func string(forKey key: String) -> String?
    func bool(forKey key: String) -> Bool
    func integer(forKey key: String) -> Int
    func double(forKey key: String) -> Double
}
