//
//  KeyCommandSettingsView.swift
//  JoyPanTlt
//
//  Created by Niklas Kihlberg on 2025-06-29.
//

import SwiftUI

struct KeyCommandSettingsView: View {
    @StateObject private var keyCommandConfig = KeyCommandConfiguration()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Keyboard Controls")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Use arrow keys to control the active joystick. Press space to reset to center.")
                .font(.body)
                .foregroundColor(.secondary)
            
            Divider()
            
            // Keyboard Settings
            VStack(alignment: .leading, spacing: 16) {
                Text("Settings")
                    .font(.headline)
                
                HStack {
                    Text("Movement Speed:")
                    Spacer()
                    Slider(value: $keyCommandConfig.keyboardSensitivity, in: 0.1...2.0, step: 0.1)
                        .frame(width: 150)
                    Text(String(format: "%.1f", keyCommandConfig.keyboardSensitivity))
                        .font(.system(.body, design: .monospaced))
                        .frame(width: 30, alignment: .trailing)
                }
                
                Toggle("Enable Keyboard Control", isOn: $keyCommandConfig.isKeyboardInputEnabled)
            }
            
            Divider()
            
            // Key Mappings
            VStack(alignment: .leading, spacing: 16) {
                Text("Key Mappings")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 8) {
                    keyMappingRow("Up", key: "↑")
                    keyMappingRow("Down", key: "↓") 
                    keyMappingRow("Left", key: "←")
                    keyMappingRow("Right", key: "→")
                    keyMappingRow("Reset to Center", key: "Space")
                }
            }
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func keyMappingRow(_ action: String, key: String) -> some View {
        HStack {
            Text(action)
                .frame(width: 120, alignment: .leading)
            Spacer()
            Text(key)
                .font(.system(.body, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(4)
        }
    }
}

#Preview {
    KeyCommandSettingsView()
        .frame(width: 400, height: 500)
}
