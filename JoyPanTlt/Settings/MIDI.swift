//
//  MIDIConfiguration.swift
//  JoyPanTlt
//
//  Created by Niklas Kihlberg on 2025-06-27.
//

import CoreMIDI
import Combine
import SwiftUI

// MARK: - MIDI Backend
class MIDI: ObservableObject {
    private var midiClient: MIDIClientRef = 0
    private var outputPort: MIDIPortRef = 0
    private var virtualPort: MIDIPortRef = 0
    private let queue = DispatchQueue(label: "JoyPanTlt.MIDIBackend")
    private var hasAutoSelectedInternalDestination = false

    @Published var isInitialized: Bool = false
    @Published var availableDestinations: [(name: String, endpoint: MIDIEndpointRef)] = []
    @Published var selectedDestination: MIDIEndpointRef = 0
    @Published var hasVirtualPort: Bool = false
    @Published var lastError: String? = nil

    var onStatusChanged: ((Bool, String) -> Void)?

    init() {
        DispatchQueue.main.async { [weak self] in
            self?.initializeMIDI()
            self?.createVirtualPort()
            self?.scanForDestinations()
        }
    }

    deinit {
        cleanupOldJoyPanTltPorts()
        if virtualPort != 0 { MIDIPortDispose(virtualPort); virtualPort = 0 }
        if outputPort != 0 { MIDIPortDispose(outputPort); outputPort = 0 }
        if midiClient != 0 { MIDIClientDispose(midiClient); midiClient = 0 }
    }

    private func cleanupOldJoyPanTltPorts() {
        let client: MIDIClientRef = {
            var ref: MIDIClientRef = 0
            let status = MIDIClientCreate("JoyPanTlt-Cleanup" as CFString, nil, nil, &ref)
            guard status == noErr else { return 0 }
            return ref
        }()
        guard client != 0 else { return }
        MIDIClientDispose(client)
    }

    private func initializeMIDI() {
        MIDIRestart()
        cleanupOldJoyPanTltPorts()
        let status = MIDIClientCreate(
            "JoyPanTlt-Client" as CFString,
            midiNotifyProc,
            Unmanaged.passUnretained(self).toOpaque(),
            &midiClient
        )
        if status == noErr {
            let portStatus = MIDIOutputPortCreate(midiClient, "JoyPanTlt-Output" as CFString, &outputPort)
            DispatchQueue.main.async {
                self.isInitialized = (portStatus == noErr)
                self.lastError = portStatus == noErr ? nil : "Failed to create MIDI output port (status: \(portStatus))"
                self.onStatusChanged?(self.isInitialized, self.lastError ?? "")
            }
        } else {
            DispatchQueue.main.async {
                self.isInitialized = false
                self.lastError = "Failed to create MIDI client (status: \(status)). Check app permissions."
                self.onStatusChanged?(false, self.lastError ?? "")
            }
        }
    }

    private func createVirtualPort() {
        guard midiClient != 0 else {
            DispatchQueue.main.async {
                self.hasVirtualPort = false
                self.lastError = "Cannot create virtual port: MIDI client not initialized"
            }
            return
        }
        let status = MIDISourceCreate(midiClient, "JoyPanTlt" as CFString, &virtualPort)
        DispatchQueue.main.async {
            self.hasVirtualPort = (status == noErr)
            if self.hasVirtualPort {
                self.availableDestinations.append((name: "JoyPanTlt (Internal)", endpoint: self.virtualPort))
            } else {
                self.lastError = "Failed to create virtual MIDI port (status: \(status))"
                self.onStatusChanged?(false, self.lastError ?? "")
            }
        }
    }

    public func scanForDestinations() {
        DispatchQueue.main.async {
            let previousDestination = self.selectedDestination
            let virtualDestination = self.availableDestinations.first { $0.name.contains("JoyPanTlt") }
            self.availableDestinations.removeAll()
            if let virtual = virtualDestination { self.availableDestinations.append(virtual) }
            let numDestinations = MIDIGetNumberOfDestinations()
            for i in 0..<numDestinations {
                let endpoint = MIDIGetDestination(i)
                var cfName: Unmanaged<CFString>?
                let status = MIDIObjectGetStringProperty(endpoint, kMIDIPropertyName, &cfName)
                if status == noErr, let name = cfName?.takeRetainedValue() as String? {
                    self.availableDestinations.append((name: name, endpoint: endpoint))
                }
            }
            if !self.hasAutoSelectedInternalDestination || self.selectedDestination == 0 {
                if let internalDest = self.availableDestinations.first(where: { $0.name.contains("JoyPanTlt") }) {
                    self.selectedDestination = internalDest.endpoint
                } else if let first = self.availableDestinations.first {
                    self.selectedDestination = first.endpoint
                } else {
                    self.selectedDestination = 0
                }
                self.hasAutoSelectedInternalDestination = true
            } else if self.availableDestinations.contains(where: { $0.endpoint == previousDestination }) {
                self.selectedDestination = previousDestination
            } else if let first = self.availableDestinations.first {
                self.selectedDestination = first.endpoint
            } else {
                self.selectedDestination = 0
            }
        }
    }

    func sendControlChange(channel: Int, controller: Int, value: Int) {
        let safeChannel: UInt8 = UInt8(max(0, min(channel, 15)))
        let safeController: UInt8 = UInt8(max(0, min(controller, 127)))
        let safeValue: UInt8 = UInt8(max(0, min(value, 127)))
        queue.async { [weak self] in
            guard let self = self else { return }
            guard self.isInitialized else {
                DispatchQueue.main.async {
                    self.lastError = "MIDI not initialized"
                    self.onStatusChanged?(false, self.lastError ?? "")
                }
                return
            }
            let statusByte: UInt8 = 0xB0 + (safeChannel & 0x0F)
            let midiData: [UInt8] = [statusByte, safeController & 0x7F, safeValue & 0x7F]
            var packetList = MIDIPacketList()
            var packet = MIDIPacketListInit(&packetList)
            packet = MIDIPacketListAdd(&packetList, 1024, packet, 0, midiData.count, midiData)
            var sendError = false
            if self.selectedDestination != 0 {
                let sendStatus = MIDISend(self.outputPort, self.selectedDestination, &packetList)
                if sendStatus != noErr {
                    self.lastError = "Failed to send MIDI message"
                    self.onStatusChanged?(false, self.lastError ?? "")
                    sendError = true
                }
            }
            if self.hasVirtualPort {
                MIDIReceived(self.virtualPort, &packetList)
            }
            if !sendError {
                self.onStatusChanged?(true, "MIDI message sent")
            }
        }
    }

    func refreshDestinations() {
        queue.async { [weak self] in
            self?.scanForDestinations()
        }
    }
}

private func midiNotifyProc(
    message: UnsafePointer<MIDINotification>, refCon: UnsafeMutableRawPointer?
) {
    guard let refCon = refCon else { return }
    let backend = Unmanaged<MIDI>.fromOpaque(refCon).takeUnretainedValue()
    DispatchQueue.main.async {
        backend.scanForDestinations()
        backend.onStatusChanged?(true, "MIDI device list updated")
    }
}

struct MIDISettingsView: View {
    @EnvironmentObject var midi: MIDI
    @EnvironmentObject var virtualjoysticks: VIRTUALJOYSTICKS

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("MIDI Settings")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Configure MIDI output for controlling external devices and software.")
                .font(.body)
                .foregroundColor(.secondary)
            Divider()
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("MIDI Output")
                        .font(.headline)
                    Picker("", selection: $midi.selectedDestination) {
                        ForEach(midi.availableDestinations, id: \.endpoint) { destination in
                            Text(destination.name).tag(destination.endpoint)
                        }
                    }
                    .onTapGesture { midi.refreshDestinations() }
                    .pickerStyle(MenuPickerStyle())
                    .frame(width: 256)
                }
                .padding(.bottom, 56.0)
            }
            VStack(alignment: .leading, spacing: 16) {
                TabView {
                    ForEach(virtualjoysticks.joystickInstances.indices, id: \.self) { index in
                        joystickMidiTab(for: index)
                            .tabItem { Text("Joy \(index + 1)") }
                    }
                }
                .frame(height: 32)
                .tabViewStyle(DefaultTabViewStyle())
                Spacer()
            }
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func joystickMidiTab(for index: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("X/Pan MIDI CC:")
                    .frame(width: 112, alignment: .leading)
                TextField(
                    "1",
                    text: Binding<String>(
                        get: { String(virtualjoysticks.joystickInstances[index].midiCCX) },
                        set: { newValue in
                            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                            let intValue: Int?
                            if trimmed.hasPrefix("0x") || trimmed.hasPrefix("0X") {
                                intValue = Int(trimmed.dropFirst(2), radix: 16)
                            } else {
                                intValue = Int(trimmed)
                            }
                            if let value = intValue {
                                virtualjoysticks.joystickInstances[index].midiCCX = min(max(value, 0), 127)
                            }
                        }
                    )
                )
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .monospaced()
                .frame(width: 56)
                Spacer()
            }
            HStack {
                Text("Y/Tilt MIDI CC:")
                    .frame(width: 112, alignment: .leading)
                TextField(
                    "2",
                    text: Binding<String>(
                        get: { String(virtualjoysticks.joystickInstances[index].midiCCY) },
                        set: { newValue in
                            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                            let intValue: Int?
                            if trimmed.hasPrefix("0x") || trimmed.hasPrefix("0X") {
                                intValue = Int(trimmed.dropFirst(2), radix: 16)
                            } else {
                                intValue = Int(trimmed)
                            }
                            if let value = intValue {
                                virtualjoysticks.joystickInstances[index].midiCCY = min(max(value, 0), 127)
                            }
                        }
                    )
                )
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .monospaced()
                .frame(width: 56)
                Spacer()
            }
        }
        .padding()
        .cornerRadius(8)
    }
}

#Preview {
  MIDISettingsView()
    .environmentObject(MIDI())
    .environmentObject(VIRTUALJOYSTICKS())
    .frame(width: 500, height: 500)
}
