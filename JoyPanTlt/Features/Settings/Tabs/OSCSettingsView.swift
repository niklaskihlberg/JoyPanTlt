//
//  OSCSettingsView.swift
//  JoyPanTlt
//
//  Created by Niklas Kihlberg on 2025-06-29.
//

import SwiftUI

struct OSCSettingsView: View {
    @StateObject private var oscConfig = OSCConfiguration()
    @ObservedObject var virtualJoystickConfig: VirtualJoystickConfiguration
    
    // MARK: - Initialization
    init(virtualJoystickConfig: VirtualJoystickConfiguration? = nil) {
        self.virtualJoystickConfig = virtualJoystickConfig ?? VirtualJoystickConfiguration()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("OSC Settings")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Configure Open Sound Control protocol for communicating with external applications.")
                .font(.body)
                .foregroundColor(.secondary)
            
            Divider()
            
            // Connection Settings
            VStack(alignment: .leading, spacing: 16) {
                Text("Connection")
                    .font(.headline)
                
                Toggle("Enable OSC", isOn: $oscConfig.isEnabled)
                
                HStack {
                    Text("Host:")
                    TextField("127.0.0.1", text: $oscConfig.host)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 120)
                }
                
                HStack {
                    Text("Port:")
                    TextField("21600", value: $oscConfig.port, format: .number)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 80)
                }
                
                HStack {
                    Circle()
                        .fill(oscConfig.isConnected ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    Text(oscConfig.isConnected ? "Connected" : "Disconnected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            // Joystick OSC Addresses
            if !virtualJoystickConfig.joystickInstances.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Joystick OSC Addresses")
                        .font(.headline)
                    
                    TabView {
                        ForEach(virtualJoystickConfig.joystickInstances.indices, id: \.self) { index in
                            joystickAddressTab(for: index)
                                .tabItem {
                                    Text("Joystick \(index + 1)")
                                }
                        }
                    }
                    .frame(height: 150)
                    .tabViewStyle(DefaultTabViewStyle())
                }
            }
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    @ViewBuilder
    private func joystickAddressTab(for index: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Joystick \(index + 1)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { virtualJoystickConfig.joystickInstances[index].isEnabled },
                    set: { virtualJoystickConfig.joystickInstances[index].isEnabled = $0 }
                ))
                .labelsHidden()
            }
            
            HStack {
                Text("Pan (X) Address:")
                    .frame(width: 110, alignment: .leading)
                TextField("/joystick\(index + 1)/pan", text: Binding(
                    get: { virtualJoystickConfig.joystickInstances[index].oscPanAddress },
                    set: { virtualJoystickConfig.joystickInstances[index].oscPanAddress = $0 }
                ))
                .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            HStack {
                Text("Tilt (Y) Address:")
                    .frame(width: 110, alignment: .leading)
                TextField("/joystick\(index + 1)/tilt", text: Binding(
                    get: { virtualJoystickConfig.joystickInstances[index].oscTiltAddress },
                    set: { virtualJoystickConfig.joystickInstances[index].oscTiltAddress = $0 }
                ))
                .textFieldStyle(RoundedBorderTextFieldStyle())
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

#Preview {
    OSCSettingsView()
        .frame(width: 500, height: 500)
}
