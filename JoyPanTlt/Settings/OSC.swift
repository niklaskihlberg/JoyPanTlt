//
//  OSCConfiguration.swift
//  JoyPanTlt
//
//  Created by Niklas Kihlberg on 2025-06-25.
//
/*
 TODO (optional/future):
  
 • Unit testability
 No protocol or mock for OSC logic. Consider extracting a protocol for OSCBackend and providing a mock implementation for tests.
 
 • Support for more OSC types
 Only float messages are supported. Add support for int, string, bool, arrays, etc. if needed.
 
 */

import Foundation
import Combine
import Network
import SwiftUI

let OSC_DEBUG = true

enum OSCError: Error {
  case invalidPort
  case notConnected
  case sendFailed(Error)
  case connectionFailed(Error)
  case unknown
}

struct OSCStatusEvent {
  let isConnected: Bool
  let status: String
  let error: OSCError?
}

class OSC: ObservableObject {
  @Published var host: String = "127.0.0.1"
  @Published var port: Int = 21600
  @Published var isConnected: Bool = false
  @Published var connectionStatus: String = "Disconnected"
  @Published var usesTCP: Bool = false
  
  @Published var autoConnectEnabled: Bool = true
  @Published var retryInterval: TimeInterval = 5.0
  @Published var maxRetryAttempts: Int = 10
  
  private var currentRetryAttempt: Int = 0
  private var retryTimer: Timer?
  private var shouldAutoConnect: Bool = false
  
  let statusPublisher = PassthroughSubject<OSCStatusEvent, Never>()
  
  private var connection: NWConnection?
  private let queue = DispatchQueue(label: "JoyPanTlt.OSCBackend")
  private var cancellables = Set<AnyCancellable>()
  
  init() {
    if autoConnectEnabled {
      DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
        self?.startAutoConnect()
      }
    }
  }
  
  deinit {
    stopAutoConnect()
    disconnect()
    cancellables.forEach { $0.cancel() }
  }
  
  func startAutoConnect() {
    shouldAutoConnect = true
    currentRetryAttempt = 0
    connect(host: host, port: port, usesTCP: usesTCP)
  }
  
  func stopAutoConnect() {
    shouldAutoConnect = false
    retryTimer?.invalidate()
    retryTimer = nil
    currentRetryAttempt = 0
  }
  
  func connect(host: String, port: Int, usesTCP: Bool, completion: ((Result<Void, OSCError>) -> Void)? = nil) {
    queue.async { [weak self] in
      self?.disconnect()
      self?.queue.asyncAfter(deadline: .now() + 0.1) {
        guard let self = self else { return }
        guard port > 0 && port <= 65535 else {
          self.notifyStatus(isConnected: false, status: "Invalid port: \(port)", error: .invalidPort)
          completion?(.failure(.invalidPort))
          return
        }
        let nwHost = NWEndpoint.Host(host)
        let nwPort = NWEndpoint.Port(integerLiteral: UInt16(port))
        let parameters: NWParameters = usesTCP ? .tcp : .udp
        let connection = NWConnection(host: nwHost, port: nwPort, using: parameters)
        self.connection = connection
        
        connection.stateUpdateHandler = { [weak self] state in
          self?.queue.async {
            self?.handleConnectionState(state, completion: completion)
          }
        }
        connection.start(queue: self.queue)
        self.notifyStatus(isConnected: false, status: "Connecting to \(host):\(port) via \(usesTCP ? "TCP" : "UDP")...", error: nil)
      }
    }
  }
  
  func disconnect() {
    queue.async { [weak self] in
      self?.connection?.cancel()
      self?.connection = nil
      DispatchQueue.main.async {
        self?.isConnected = false
      }
      self?.notifyStatus(isConnected: false, status: "Disconnected", error: nil)
    }
  }
  
  private func scheduleRetry() {
    guard shouldAutoConnect && autoConnectEnabled else { return }
    if maxRetryAttempts > 0 && currentRetryAttempt >= maxRetryAttempts {
      DispatchQueue.main.async { [weak self] in
        self?.notifyStatus(isConnected: false, status: "Max retry attempts reached", error: .connectionFailed(NSError(domain: "OSC", code: -1, userInfo: [NSLocalizedDescriptionKey: "Max retries exceeded"])))
        self?.shouldAutoConnect = false
      }
      return
    }
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      self.currentRetryAttempt += 1
      self.notifyStatus(
        isConnected: false,
        status: "Retry \(self.currentRetryAttempt)/\(self.maxRetryAttempts == 0 ? "∞" : "\(self.maxRetryAttempts)") in \(Int(self.retryInterval))s...",
        error: nil
      )
      self.retryTimer = Timer.scheduledTimer(withTimeInterval: self.retryInterval, repeats: false) { [weak self] _ in
        guard let self = self else { return }
        self.connect(host: self.host, port: self.port, usesTCP: self.usesTCP)
      }
    }
  }
  
  private func handleConnectionState(_ state: NWConnection.State, completion: ((Result<Void, OSCError>) -> Void)?) {
    switch state {
    case .ready:
      DispatchQueue.main.async { [weak self] in
        self?.isConnected = true
        self?.currentRetryAttempt = 0
      }
      notifyStatus(isConnected: true, status: "Connected", error: nil)
      completion?(.success(()))
    case .failed(let error):
      DispatchQueue.main.async { [weak self] in
        self?.isConnected = false
      }
      notifyStatus(isConnected: false, status: "Failed: \(error.localizedDescription)", error: .connectionFailed(error))
      completion?(.failure(.connectionFailed(error)))
      if autoConnectEnabled {
        scheduleRetry()
      }
    case .cancelled:
      DispatchQueue.main.async { [weak self] in
        self?.isConnected = false
      }
      notifyStatus(isConnected: false, status: "Disconnected", error: nil)
    case .waiting(let error):
      DispatchQueue.main.async { [weak self] in
        self?.isConnected = false
      }
      notifyStatus(isConnected: false, status: "Waiting: \(error.localizedDescription)", error: .connectionFailed(error))
    case .setup, .preparing:
      break
    @unknown default:
      break
    }
  }
  
  private func notifyStatus(isConnected: Bool, status: String, error: OSCError?) {
    DispatchQueue.main.async { [weak self] in
      self?.isConnected = isConnected
      self?.connectionStatus = status
      self?.statusPublisher.send(OSCStatusEvent(isConnected: isConnected, status: status, error: error))
    }
  }
  
  func sendPanTilt(panAddress: String, panValue: Double, tiltAddress: String, tiltValue: Double, completion: ((Result<Void, OSCError>) -> Void)? = nil) {
    queue.async { [weak self] in
      guard let self = self, self.isConnected, let connection = self.connection else {
        completion?(.failure(.notConnected))
        self?.notifyStatus(isConnected: false, status: "OSC not connected!", error: .notConnected)
        return
      }
      let panMessage = self.createOSCMessage(address: panAddress, value: Float(panValue))
      connection.send(
        content: panMessage,
        completion: .contentProcessed { error in
          if let error = error {
            self.notifyStatus(isConnected: self.isConnected, status: "Failed to send pan: \(error)", error: .sendFailed(error))
            completion?(.failure(.sendFailed(error)))
            return
          }
          self.queue.asyncAfter(deadline: .now() + 0.01) {
            let tiltMessage = self.createOSCMessage(address: tiltAddress, value: Float(tiltValue))
            connection.send(
              content: tiltMessage,
              completion: .contentProcessed { error in
                if let error = error {
                  self.notifyStatus(isConnected: self.isConnected, status: "Failed to send tilt: \(error)", error: .sendFailed(error))
                  completion?(.failure(.sendFailed(error)))
                } else {
                  self.notifyStatus(isConnected: self.isConnected, status: "Pan & Tilt sent!", error: nil)
                  completion?(.success(()))
                }
              })
          }
        })
    }
  }
  
  func createOSCMessage(address: String, value: Float) -> Data {
    var data = Data()
    let addressData = address.data(using: .utf8)!
    data.append(addressData)
    data.append(0)
    let addressPadding = (4 - (data.count % 4)) % 4
    for _ in 0..<addressPadding { data.append(0) }
    let typeTag = ",f".data(using: .utf8)!
    data.append(typeTag)
    data.append(0)
    let typePadding = (4 - (data.count % 4)) % 4
    for _ in 0..<typePadding { data.append(0) }
    var bigEndianValue = value.bitPattern.bigEndian
    let floatData = Data(bytes: &bigEndianValue, count: MemoryLayout<UInt32>.size)
    data.append(floatData)
    return data
  }
}

// SETTINGS VIEW FOR OSC
struct OSCSettingsView: View {
  @EnvironmentObject var osc: OSC
  @EnvironmentObject var virtualjoysticks: VIRTUALJOYSTICKS
  
  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      Text("Open Sound Control Settings")
        .font(.title2)
        .fontWeight(.semibold)
      Text("Configure Open Sound Control protocol for communicating with external applications.")
        .font(.body)
        .foregroundColor(.secondary)
      Divider()
      
      VStack(alignment: .leading, spacing: 16) {
        HStack {
          Text("Host:")
          TextField("127.0.0.1", text: $osc.host)
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .frame(width: 156)
            .monospaced()
        }
        HStack {
          Text("Port:")
          TextField("21600", value: $osc.port, formatter: noGroupingNumberFormatter)
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .frame(width: 156)
            .monospaced()
        }
      }
      .padding(.bottom, 56.0)
      
      
      // OSC Joystick Tabs
      if !virtualjoysticks.joystickInstances.isEmpty {
        VStack(alignment: .leading, spacing: 16) {
          TabView {
            ForEach(virtualjoysticks.joystickInstances.indices, id: \.self) { index in
              joystickAddressTab(for: index)
                .tabItem {
                  Text("Joy \(index + 1)")
                }
            }
          }
          .frame(height: 64)
          .tabViewStyle(DefaultTabViewStyle())
          Spacer()
        }
      }
      Spacer()
    }
    .padding()
    .frame(maxWidth: .infinity, alignment: .leading)
  }
  
  let noGroupingNumberFormatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.groupingSeparator = ""
    formatter.usesGroupingSeparator = false
    formatter.maximumFractionDigits = 0
    return formatter
  }()
  
  @ViewBuilder
  private func joystickAddressTab(for index: Int) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      
      
          Text("X/Pan OSC Address:")
            .frame(width: 125, alignment: .leading)
          
          TextField("/joystick\(index + 1)/pan", text: Binding(
            get: { virtualjoysticks.joystickInstances[index].oscPanAddress },
            set: { virtualjoysticks.joystickInstances[index].oscPanAddress = $0 }
          ))
          .textFieldStyle(RoundedBorderTextFieldStyle())
          .monospaced()
          .padding(.bottom, 16.0)

      
      
          Text("Y/Tilt OSC Address:")
            .frame(width: 125, alignment: .leading)
          TextField("/joystick\(index + 1)/tilt", text: Binding(
            get: { virtualjoysticks.joystickInstances[index].oscTiltAddress },
            set: { virtualjoysticks.joystickInstances[index].oscTiltAddress = $0 }
          ))
          .textFieldStyle(RoundedBorderTextFieldStyle())
          .monospaced()

    }
    .padding()
    .cornerRadius(8)
  }
}

