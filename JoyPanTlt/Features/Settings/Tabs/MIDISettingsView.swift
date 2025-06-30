//
//  MIDISettingsView.swift
//  JoyPanTlt
//
//  Created by Niklas Kihlberg on 2025-06-29.
//

import SwiftUI

struct MIDISettingsView: View {
    @StateObject private var midiConfig = MIDIConfiguration()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("MIDI Settings")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Configure MIDI output for controlling external devices and software.")
                .font(.body)
                .foregroundColor(.secondary)
            
            Divider()
            
            // MIDI Settings
            VStack(alignment: .leading, spacing: 16) {
                Text("MIDI Output")
                    .font(.headline)
                
                Toggle("Enable MIDI", isOn: $midiConfig.isEnabled)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Available Destinations:")
                        .font(.subheadline)
                    
                    if midiConfig.backend.availableDestinations.isEmpty {
                        Text("No MIDI destinations found")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        ForEach(midiConfig.backend.availableDestinations, id: \.endpoint) { destination in
                            HStack {
                                Image(systemName: destination.name == midiConfig.selectedDestinationName ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(destination.name == midiConfig.selectedDestinationName ? .blue : .secondary)
                                Text(destination.name)
                                    .font(.caption)
                                Spacer()
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                midiConfig.selectedDestinationName = destination.name
                            }
                        }
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
    MIDISettingsView()
        .frame(width: 400, height: 300)
}
