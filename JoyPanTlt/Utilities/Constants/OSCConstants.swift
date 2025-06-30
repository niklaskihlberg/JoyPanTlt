//
//  OSCConstants.swift
//  JoyPanTlt
//
//  Created by Niklas Kihlberg on 2025-06-29.
//

import Foundation

// MARK: - OSC Constants
enum OSCConstants {
    // Default connection settings
    static let defaultHost = "127.0.0.1"
    static let defaultPort = 21600
    
    // Common OSC ports
    static let commonPorts = [8000, 9000, 7001, 21600, 53000, 3333, 7777]
    
    // Default addresses
    static let defaultPanAddress = "/fixture/selected/overrides/panAngle"
    static let defaultTiltAddress = "/fixture/selected/overrides/tiltAngle"
    
    // Lightkey specific
    enum Lightkey {
        static let host = "127.0.0.1"
        static let port = 21600
        static let panAddress = "/fixture/selected/overrides/panAngle"
        static let tiltAddress = "/fixture/selected/overrides/tiltAngle"
        
        static func layerAddress(layer: Int, parameter: String) -> String {
            return "/lightkey/layers/layer\(layer)/\(parameter)"
        }
    }
    
    // QLab specific
    enum QLab {
        static let host = "127.0.0.1"
        static let port = 53000
        static let panAddress = "/cue/selected/pan"
        static let tiltAddress = "/cue/selected/tilt"
    }
    
    // GrandMA3 specific
    enum GrandMA3 {
        static let host = "127.0.0.1"
        static let port = 8000
        static let panAddress = "/grandma3/fixture/pan"
        static let tiltAddress = "/grandma3/fixture/tilt"
    }
}
