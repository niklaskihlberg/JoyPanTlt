//
//  JoyPanTltApp.swift
//  JoyPanTlt
//
//  Created by Niklas Kihlberg on 2025-06-25.
//  Refactored by Niklas Kihlberg on 2025-06-29.
//

import SwiftUI

@main
struct JoyPanTltApp: App {
    // MARK: - App Coordinator (Dependency Injection Container)
    let coordinator = AppCoordinator()
    
    // MARK: - App State Management
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
        // Injicera coordinator i AppDelegate för lifecycle-hantering
        AppDelegate.coordinator = coordinator
    }
    
    var body: some Scene {
        // Main Window with new MVVM architecture
        WindowGroup(content: {
            ContentView(viewModel: coordinator.makeContentViewModel())
        })
        .commands {
            CommandGroup(replacing: .help) {
                Button("JoyPanTlt Help") {
                    // Öppna hjälp-fönster
                    if let window = NSApplication.shared.windows.first(where: { $0.identifier?.rawValue == "help" }) {
                        window.makeKeyAndOrderFront(nil)
                    } else {
                        // Använd NotificationCenter för att be ContentView öppna hjälp
                        NotificationCenter.default.post(name: NSNotification.Name("OpenHelp"), object: nil)
                    }
                }
                .keyboardShortcut("?")
            }
        }
        
        // Settings Window with new MVVM architecture
        WindowGroup("Settings", id: "settings", content: {
            ConfigurationView(viewModel: coordinator.makeConfigurationViewModel())
        })
        .windowResizability(.contentSize)
        
        // Help Window with new MVVM architecture
        WindowGroup("Help", id: "help", content: {
            HelpView()
        })
        .windowResizability(.contentSize)
    }
}