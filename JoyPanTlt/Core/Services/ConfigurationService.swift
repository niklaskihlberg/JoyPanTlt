//
//  ConfigurationService.swift
//  JoyPanTlt
//
//  Created by Niklas Kihlberg on 2025-06-29.
//

import Foundation

// MARK: - UserDefaults Configuration Service
class UserDefaultsConfigurationService: ConfigurationServiceProtocol {
    private let userDefaults = UserDefaults.standard
    
    // MARK: - Codable Objects
    func save<T: Codable>(_ value: T, forKey key: String) {
        do {
            let encoded = try JSONEncoder().encode(value)
            userDefaults.set(encoded, forKey: key)
            print("💾 Saved \(T.self) to key: \(key)")
        } catch {
            print("❌ Failed to save \(T.self) to key \(key): \(error)")
        }
    }
    
    func load<T: Codable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = userDefaults.data(forKey: key) else {
            print("⚠️ No data found for key: \(key)")
            return nil
        }
        
        do {
            let decoded = try JSONDecoder().decode(type, from: data)
            print("📖 Loaded \(T.self) from key: \(key)")
            return decoded
        } catch {
            print("❌ Failed to load \(T.self) from key \(key): \(error)")
            return nil
        }
    }
    
    // MARK: - Basic Types
    func set(_ value: Any?, forKey key: String) {
        userDefaults.set(value, forKey: key)
    }
    
    func object(forKey key: String) -> Any? {
        return userDefaults.object(forKey: key)
    }
    
    func string(forKey key: String) -> String? {
        return userDefaults.string(forKey: key)
    }
    
    func bool(forKey key: String) -> Bool {
        return userDefaults.bool(forKey: key)
    }
    
    func integer(forKey key: String) -> Int {
        return userDefaults.integer(forKey: key)
    }
    
    func double(forKey key: String) -> Double {
        return userDefaults.double(forKey: key)
    }
}
