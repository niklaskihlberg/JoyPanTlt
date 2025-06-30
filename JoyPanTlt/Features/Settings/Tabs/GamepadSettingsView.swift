//
//  GamepadSettingsView.swift
//  JoyPanTlt
//
//  Created by Niklas Kihlberg on 2025-06-29.
//

import SwiftUI

struct GamepadSettingsView: View {
    @StateObject private var gamepadConfig = GamepadConfiguration()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Gamepad Settings")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Configure physical gamepad controllers for joystick input.")
                .font(.body)
                .foregroundColor(.secondary)
            
            Divider()
            
            // Gamepad Settings
            VStack(alignment: .leading, spacing: 16) {
                Text("Controller")
                    .font(.headline)
                
                Toggle("Enable Gamepad Input", isOn: $gamepadConfig.isGamepadConnected)
                
                if gamepadConfig.availableGamepads.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("No controllers connected")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("Connect a gamepad or game controller to use this feature.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Connected Controllers:")
                            .font(.subheadline)
                        
                        ForEach(Array(gamepadConfig.availableGamepads.enumerated()), id: \.offset) { index, controller in
                            HStack {
                                Image(systemName: "gamecontroller.fill")
                                    .foregroundColor(.green)
                                Text(controller.vendorName ?? "Unknown Controller")
                                    .font(.caption)
                                Spacer()
                            }
                        }
                    }
                }
                
                // Sensitivity Settings
                if gamepadConfig.isGamepadConnected {
                    Divider()
                    
                    HStack {
                        Text("Sensitivity:")
                        Spacer()
                        Slider(value: $gamepadConfig.sensitivity, in: 0.1...2.0, step: 0.1)
                            .frame(width: 150)
                        Text(String(format: "%.1f", gamepadConfig.sensitivity))
                            .font(.system(.body, design: .monospaced))
                            .frame(width: 30, alignment: .trailing)
                    }
                }
            }
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    GamepadSettingsView()
        .frame(width: 400, height: 300)
}
