//
//  VirtualJoystickSettingsView.swift
//  JoyPanTlt
//
//  Created by Niklas Kihlberg on 2025-06-29.
//

import SwiftUI

struct VirtualJoystickSettingsView: View {
    @ObservedObject var virtualJoystickConfig: VirtualJoystickConfiguration
    
    init(virtualJoystickConfig: VirtualJoystickConfiguration) {
        self.virtualJoystickConfig = virtualJoystickConfig
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Virtual Joystick Settings")
                .font(.title2)
                .fontWeight(.semibold)
            
            Divider()
            
            // Number of Joysticks
            VStack(alignment: .leading, spacing: 16) {
                Text("Layout")
                    .font(.headline)
                
                HStack {
                    Text("Number of Joysticks:")
                    Spacer()
                    Stepper(value: $virtualJoystickConfig.numberOfJoysticks, in: 1...8) {
                        Text("\(virtualJoystickConfig.numberOfJoysticks)")
                            .font(.system(.body, design: .monospaced))
                            .frame(width: 30, alignment: .trailing)
                    }
                }
                
                Text("Each joystick can be configured independently with its own OSC/MIDI settings.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            // Performance Settings
            VStack(alignment: .leading, spacing: 16) {
                Text("Performance")
                    .font(.headline)
                
                HStack {
                    Text("Update Interval:")
                    Spacer()
                    Slider(value: $virtualJoystickConfig.updateInterval, in: 0.01...0.2, step: 0.01)
                        .frame(width: 150)
                    Text(String(format: "%.2fs", virtualJoystickConfig.updateInterval))
                        .font(.system(.body, design: .monospaced))
                        .frame(width: 50, alignment: .trailing)
                }
                
                Text("Lower values = smoother movement, higher CPU usage")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            // Joystick Instances List
            VStack(alignment: .leading, spacing: 16) {
                Text("Joystick Configuration")
                    .font(.headline)
                
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(Array(virtualJoystickConfig.joystickInstances.enumerated()), id: \.element.id) { index, joystick in
                            joystickInstanceRow(joystick: joystick, index: index)
                        }
                    }
                }
                .frame(maxHeight: 200)
            }
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func joystickInstanceRow(joystick: JoystickInstance, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(joystick.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text("Joystick \(index + 1)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("OSC: \(joystick.oscPanAddress)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("MIDI: Ch\(joystick.midiChannel) CC\(joystick.midiCCPan)/\(joystick.midiCCTilt)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(6)
    }
}

#Preview {
    VirtualJoystickSettingsView(virtualJoystickConfig: VirtualJoystickConfiguration())
        .frame(width: 400, height: 500)
}
