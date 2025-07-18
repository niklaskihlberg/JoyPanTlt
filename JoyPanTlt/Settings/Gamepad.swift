import Foundation
import SwiftUI
import Combine
import IOKit.hid

// D-pad-riktning
public enum DpadDirection: Hashable {
    case neutral, up, down, left, right, upLeft, upRight, downLeft, downRight, unknown
}

func dpadDirection(from value: Int) -> DpadDirection {
    switch value {
    case 0: return .up
    case 1: return .upRight
    case 2: return .right
    case 3: return .downRight
    case 4: return .down
    case 5: return .downLeft
    case 6: return .left
    case 7: return .upLeft
    case 8, 15: return .neutral
    default: return .unknown
    }
}

public enum GamepadInput: Hashable {
    case button(Int)
    case dpad(Int)
}

public enum GamepadInputEvent {
    case pressed(GamepadInput)
    case released(GamepadInput)
}

public enum JoystickAction: String, CaseIterable, Identifiable {
    case moveUp, moveDown, moveLeft, moveRight, reset
    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .moveUp: return "Up"
        case .moveDown: return "Down"
        case .moveLeft: return "Left"
        case .moveRight: return "Right"
        case .reset: return "Position reset"
        }
    }
}

enum GamepadMappingMode {
    case none, up, down, left, right, reset
}

class GAMEPAD: ObservableObject {
    @Published var isConnected = false
    @Published var mappingMode: GamepadMappingMode = .none
    @Published var lastMappedButtonName: String = ""
    @Published var inputMappings: [GamepadInput: JoystickAction] = [:]
    let inputEventPublisher = PassthroughSubject<GamepadInputEvent, Never>()
    @Published var isActive: Bool = false
    @Published var axes: [Float] = []
    @Published var buttons: [Bool] = []
    private var hidManager: IOHIDManager?
    private var device: IOHIDDevice?

    init() {
        #if !TARGET_INTERFACE_BUILDER
        self.hidManager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        setupHID()
        #endif
    }

    deinit {
        if let hidManager = hidManager {
            IOHIDManagerClose(hidManager, 0)
        }
    }

    private func setupHID() {
        guard let hidManager = hidManager else { return }
        let matching: [String: Any] = [:]
        IOHIDManagerSetDeviceMatching(hidManager, matching as CFDictionary)
        IOHIDManagerRegisterInputValueCallback(hidManager, { context, _, _, value in
            let mySelf = Unmanaged<GAMEPAD>.fromOpaque(context!).takeUnretainedValue()
            mySelf.handleInputValue(value: value)
        }, UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()))
        IOHIDManagerScheduleWithRunLoop(hidManager, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
        IOHIDManagerOpen(hidManager, 0)
        if let devices = IOHIDManagerCopyDevices(hidManager) as? Set<IOHIDDevice>, let dev = devices.first {
            device = dev
            isConnected = true
        } else {
            isConnected = false
        }
    }

    private func handleInputValue(value: IOHIDValue) {
        DispatchQueue.main.async {
            let element = IOHIDValueGetElement(value)
            let type = IOHIDElementGetType(element)
            let intValue = IOHIDValueGetIntegerValue(value)
            let usagePage = IOHIDElementGetUsagePage(element)
            let usage = IOHIDElementGetUsage(element)
            // let logicalMin = IOHIDElementGetLogicalMin(element)
            // let logicalMax = IOHIDElementGetLogicalMax(element)

            var triggeredInput: GamepadInput? = nil
            var isPressed: Bool? = nil

            if type == kIOHIDElementTypeInput_Button {
                let buttonIndex = Int(usage) - 1
                if buttonIndex >= 0 {
                    if self.buttons.count <= buttonIndex {
                        self.buttons += Array(repeating: false, count: buttonIndex - self.buttons.count + 1)
                    }
                    self.buttons[buttonIndex] = (intValue != 0)
                    triggeredInput = .button(buttonIndex)
                    isPressed = intValue != 0
                }
            } else if usagePage == 0x01 && usage >= 0x39 && usage <= 0x3C {
                let dpadValue = intValue
                let dir = dpadDirection(from: dpadValue)
                
                // Auto-map D-pad directions
                let dpadMappings: [(Int, JoystickAction)] = [
                    (1, .moveUp),
                    (2, .moveRight),
                    (4, .moveDown),
                    (6, .moveLeft)
                ]
                for (val, action) in dpadMappings {
                    let key = GamepadInput.dpad(val)
                    if self.inputMappings[key] == nil {
                        self.inputMappings[key] = action
                    }
                }
                if dir == .neutral {
                    let allDirs = [1, 2, 4, 6]
                    for d in allDirs {
                        self.inputEventPublisher.send(.released(.dpad(d)))
                    }
                    self.processInput()
                    return
                } else {
                    triggeredInput = .dpad(dpadValue)
                    isPressed = true
                }
            }

            // Mapping-läge
            if let input = triggeredInput, self.mappingMode != .none, let pressed = isPressed, pressed {
                let action: JoystickAction?
                var mappedInput = input
                if case .dpad(let val) = input {
                    let dir = dpadDirection(from: val)
                    switch self.mappingMode {
                    case .up: if dir == .up { mappedInput = .dpad(1) } else { return }
                    case .down: if dir == .down { mappedInput = .dpad(4) } else { return }
                    case .left: if dir == .left { mappedInput = .dpad(6) } else { return }
                    case .right: if dir == .right { mappedInput = .dpad(2) } else { return }
                    default: break
                    }
                }
                switch self.mappingMode {
                case .up: action = .moveUp
                case .down: action = .moveDown
                case .left: action = .moveLeft
                case .right: action = .moveRight
                case .reset: action = .reset
                default: action = nil
                }
                if let action = action {
                    self.inputMappings[mappedInput] = action
                    self.lastMappedButtonName = "\(action.displayName): \(mappedInput)"
                }
                self.mappingMode = .none
            }

            // Publicera event
            if let input = triggeredInput, let pressed = isPressed {
                if case .dpad(let val) = input {
                    let dir = dpadDirection(from: val)
                    switch dir {
                      case .up: self.inputEventPublisher.send(pressed ? .pressed(.dpad(1)) : .released(.dpad(1)))
                      case .upRight: self.inputEventPublisher.send(pressed ? .pressed(.dpad(1)) : .released(.dpad(1))); self.inputEventPublisher.send(pressed ? .pressed(.dpad(2)) : .released(.dpad(2)))
                      case .right: self.inputEventPublisher.send(pressed ? .pressed(.dpad(2)) : .released(.dpad(2)))
                      case .downRight: self.inputEventPublisher.send(pressed ? .pressed(.dpad(3)) : .released(.dpad(3))); self.inputEventPublisher.send(pressed ? .pressed(.dpad(2)) : .released(.dpad(2))); self.inputEventPublisher.send(pressed ? .pressed(.dpad(4)) : .released(.dpad(4)))
                      case .down: self.inputEventPublisher.send(pressed ? .pressed(.dpad(4)) : .released(.dpad(4)))
                      case .downLeft: self.inputEventPublisher.send(pressed ? .pressed(.dpad(4)) : .released(.dpad(4))); self.inputEventPublisher.send(pressed ? .pressed(.dpad(6)) : .released(.dpad(6)))
                      case .left: self.inputEventPublisher.send(pressed ? .pressed(.dpad(6)) : .released(.dpad(6)))
                      case .upLeft: self.inputEventPublisher.send(pressed ? .pressed(.dpad(1)) : .released(.dpad(1))); self.inputEventPublisher.send(pressed ? .pressed(.dpad(6)) : .released(.dpad(6)))
                      default: break
                    }
                } else {
                    self.inputEventPublisher.send(pressed ? .pressed(input) : .released(input))
                }
            }

            self.processInput()
        }
    }

    func startMapping(_ mode: GamepadMappingMode) {
        mappingMode = mode
        lastMappedButtonName = ""
    }

    func processInput() {
        // Endast HID-data och mapping, ingen joystick-manipulation här längre
    }
}

// --- SwiftUI Settings View ---

struct GamepadSettingsView: View {
    @EnvironmentObject var gamepad: GAMEPAD
    @EnvironmentObject var virtualjoysticks: VIRTUALJOYSTICKS

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Gamepad Settings")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Configure external joystick or gamepad mappings")
                .font(.body)
                .foregroundColor(.secondary)
                .padding(.bottom, 96)
            VStack(alignment: .leading, spacing: 16) {
                TabView {
                    ForEach(virtualjoysticks.joystickInstances.indices, id: \.self) { index in
                        joystickGamepadTab(for: index)
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
    func joystickGamepadTab(for index: Int) -> some View {
        HStack {
          ZStack {
            // Joystick-knappar
            DirectionalButton(direction: "left",  x: -110, y:   0 )
            DirectionalButton(direction: "right", x:  -30, y:   0 )
            DirectionalButton(direction: "up",    x:  -70, y: -40 )
            DirectionalButton(direction: "down",  x:  -70, y:  40 )
            
            Button(action: { gamepad.startMapping(.reset) }) {
              Image(systemName: "arrow.uturn.backward.circle.fill")
                .resizable()
                .frame(width: 21, height: 21, alignment: .center)
                .foregroundColor(gamepad.mappingMode == .reset ? .accentColor : .gray)
                .padding(.top, 6)
                .padding(.bottom, 6)
            }
            .frame(width: 32, height: 32, alignment: .center)
            .contentShape(Rectangle())
            .offset(CGSize(width: 30, height: 40))
          }
          .frame(width: 192, height:  128)

          HStack {
            VStack {
              HStack {
                Text("Action:").font(.caption.weight(.bold)).frame(width: 67, alignment: .center)
                Text("").frame(width: 8) // Arrow
                Text("Mapping:").font(.caption.weight(.bold)).frame(width: 96, alignment: .leading)
              }

              ForEach(JoystickAction.allCases) { action in
                let mappedInput = gamepad.inputMappings.first(where: { $0.value == action })?.key
                HStack {  
                  Text(action.displayName)
                    .font(.caption)
                    .frame(width: 67, alignment: .center)
                  
                  Image(systemName: "arrow.right")
                    .font(.caption)
                    .frame(width: 8, height: 8, alignment: .center)
                  
                  if let input = mappedInput {
                    Text(inputDescription(input))
                      .font(.caption)
                      .frame(width: 96, alignment: .leading)
                    Button(action: { gamepad.inputMappings.removeValue(forKey: input) }) {
                      Image(systemName: "minus.circle").foregroundColor(.pink)
                        .frame(width: 8, height: 8, alignment: .leading)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .frame(alignment: .leading)
                  } else {
                    Text("No mapping")
                      .font(.caption)
                      .foregroundColor(.secondary)
                      .frame(width: 96, alignment: .leading)
                  }
                }
              }
              Spacer()
            }
          }
          .padding(.top, 32)
          .padding(.bottom, 32)

        }
    }
}

func inputDescription(_ input: GamepadInput) -> String {
  switch input {
    case .button(let idx): return "Button #\(idx)"
    case .dpad(let val): return "D-pad value \(val)"
  }
}

struct DirectionalButton: View {

  let direction: String
  let x: CGFloat
  let y: CGFloat

  @EnvironmentObject var gamepad: GAMEPAD  
  var offset: CGSize { CGSize(width: x, height: y) }
  
  var mappingMode: GamepadMappingMode? {
    switch direction {
      case "up": return .up
      case "down": return .down
      case "left": return .left
      case "right": return .right
      default: return nil
    }
  }

  var body: some View {
    Button(action: {if let mode = mappingMode {gamepad.startMapping(mode)}}) {
      Image(systemName: "arrowshape.\(direction).fill")
        .resizable()
        .frame(width: 21, height: 21, alignment: .center)
        .foregroundColor(gamepad.mappingMode == mappingMode ? .accentColor : .secondary)
        .padding(.vertical, 6)
    }
    .frame(width: 32, height: 32, alignment: .center)
    .contentShape(Rectangle())
    .offset(offset)
  }
}

struct GamepadMappingPopup: View {
    let mappingMode: GamepadMappingMode
    let onCancel: () -> Void
    @State private var dotCount = 0
    private let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()
    var functionName: String {
        switch mappingMode {
        case .up: return "UP"
        case .down: return "DOWN"
        case .left: return "LEFT"
        case .right: return "RIGHT"
        case .reset: return "RESET"
        default: return ""
        }
    }
    var animatedDots: String {
        let maxDots = 3
        let dots = String(repeating: ".", count: dotCount)
        let spaces = String(repeating: " ", count: maxDots - dotCount)
        return dots + spaces
    }
    var body: some View {
        if mappingMode != .none {
            VStack(spacing: 16) {
                HStack(spacing: 0) {
                    Text("Press a button on your gamepad to map \(functionName)")
                    Text(animatedDots)
                        .font(.system(.body, design: .monospaced))
                        .frame(width: 32)
                        .animation(.easeInOut(duration: 0.2), value: dotCount)
                        .multilineTextAlignment(.leading)
                }
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.escape, modifiers: [])
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .shadow(radius: 64)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.gray, lineWidth: 2)
            )
            .frame(minWidth: 360, maxWidth: 400)
            .onReceive(timer) { _ in
                dotCount = (dotCount + 1) % 4
            }
            .transition(.scale)
            .zIndex(100)
        }
    }
}







#if DEBUG
struct GamepadSettingsView_Previews: PreviewProvider {
    class DummyOSC: ObservableObject {}
    class DummyMIDI: ObservableObject {}
    static var previews: some View {
        let gamepad = GAMEPAD()
        let virtualJoysticks = VIRTUALJOYSTICKS()
        let osc = DummyOSC()
        let midi = DummyMIDI()
        return GamepadSettingsView()
            .environmentObject(virtualJoysticks)
            .environmentObject(osc)
            .environmentObject(midi)
            .environmentObject(gamepad)
            .frame(width: 500, height: 400)
            .previewDisplayName("Gamepad Settings")
    }
}
#endif
