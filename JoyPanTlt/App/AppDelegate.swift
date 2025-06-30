//
//  AppDelegate.swift
//  JoyPanTlt
//
//  Created by Niklas Kihlberg on 2025-06-29.
//

import SwiftUI
import Cocoa

// MARK: - App Delegate för Lifecycle Management
class AppDelegate: NSObject, NSApplicationDelegate {
    
    // MARK: - Static Coordinator Reference
    static var coordinator: AppCoordinator?
    
    // MARK: - App Lifecycle
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("🚀 AppDelegate: Application did finish launching")
        
        // Sätt minimum fönsterstorlek för att förhindra beskärning av joysticks
        if let window = NSApplication.shared.windows.first {
            window.minSize = NSSize(width: 480, height: 380) // Matcha ContentViewModel minimum
            print("📏 AppDelegate: Set minimum window size to 480x380")
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        print("🔄 AppDelegate: Application will terminate - resetting joystick count to 1")
        
        // Nollställ antal joysticks till 1 vid avslut för ren start nästa gång
        if let coordinator = AppDelegate.coordinator {
            coordinator.virtualJoystickConfig.numberOfJoysticks = 1
            print("✅ AppDelegate: Joystick count reset to 1")
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true // Avsluta appen när sista fönstret stängs
    }
}
