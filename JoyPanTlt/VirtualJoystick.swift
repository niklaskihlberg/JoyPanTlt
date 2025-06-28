//
//  VirtualJoystick.swift
//  JoyPanTlt
//
//  Created by Niklas Kihlberg on 2025-06-25.
//

import SwiftUI

// MARK: - Input Method Enum
enum InputMethod {
  case none
  case mouse
  case keyboard
}

struct VirtualJoystick: View {
  @StateObject private var virtualJoystickManager = VirtualJoystickManager.shared
  @State private var knobPosition: CGPoint = .zero
  @State private var isDragging: Bool = false
  @State private var timer: Timer?
  
  // Keyboard control states
  @State private var keyboardPosition: CGPoint = .zero
  @State private var lastInputMethod: InputMethod = .none
  @State private var pressedKeys: Set<KeyEquivalent> = []
  @State private var keyboardTimer: Timer?
  
  // Callbacks
  let onPositionChanged: (CGPoint) -> Void
  let onInputMethodChanged: ((InputMethod) -> Void)?
  
  // Computed properties for appearance
  private var size: CGFloat { virtualJoystickManager.configuration.joystickSize }
  private var knobSize: CGFloat { virtualJoystickManager.configuration.knobSize }
  private var backgroundColor: Color { Color.gray.opacity(virtualJoystickManager.configuration.backgroundOpacity) }
  private var knobColor: Color { Color.gray.opacity(virtualJoystickManager.configuration.knobOpacity) }
  private var snapBackSpeed: Double { virtualJoystickManager.configuration.snapBackSpeed }
  private var updateInterval: TimeInterval { virtualJoystickManager.configuration.updateInterval }
  
  private var radius: CGFloat { size / 2 }
  private var knobRadius: CGFloat { knobSize / 2 }
  private var maxDistance: CGFloat { radius - knobRadius }
  
  // Current normalized position
  private var normalizedPosition: CGPoint {
    if lastInputMethod == .keyboard && keyboardPosition != .zero {
      return keyboardPosition // Keyboard position är redan normalized
    }
    return CGPoint(
      x: knobPosition.x / maxDistance,
      y: knobPosition.y / maxDistance
    )
  }
  
  // Effective knob position for rendering
  private var effectiveKnobPosition: CGPoint {
    if lastInputMethod == .keyboard && keyboardPosition != .zero {
      // Konvertera normalized keyboard position (-1...1) till pixel offset
      return CGPoint(
        x: keyboardPosition.x * maxDistance,
        y: keyboardPosition.y * maxDistance
      )
    }
    return knobPosition
  }
  
  init(
    onPositionChanged: @escaping (CGPoint) -> Void = { _ in },
    onInputMethodChanged: ((InputMethod) -> Void)? = nil
  ) {
    self.onPositionChanged = onPositionChanged
    self.onInputMethodChanged = onInputMethodChanged
  }
  
  var body: some View {
    VStack(spacing: 15) {
      if virtualJoystickManager.configuration.visualFeedback {
        Text("X: \(normalizedPosition.x, specifier: "%.1f") Y: \(normalizedPosition.y, specifier: "%.1f")")}
      ZStack {
        // Outer circle (background)
        Circle()
          .fill(backgroundColor)
          .overlay(
            Circle()
              .stroke(Color.gray, lineWidth: 0)
          )
          .frame(width: size, height: size)
        
        // Inner circle (knob)
        Circle()
          .fill(knobColor)
          .frame(width: knobSize, height: knobSize)
          .offset(x: effectiveKnobPosition.x, y: effectiveKnobPosition.y)
          .scaleEffect(isDragging ? 1.125 : 1.0)
          .animation(.easeInOut(duration: 0.125), value: isDragging)
          .shadow(color: Color.black.opacity(0.32), radius: 24, x: 4, y: 4) // SKugga
      }
      .gesture(
        DragGesture(minimumDistance: 0)
          .onChanged { value in
            handleMouseInput(value)
          }
          .onEnded { _ in
            handleMouseEnd()
          }
      )
      //      .focusable(true)
      .focusable(false)
      .onKeyPress(phases: .all) { keyPress in
        return handleKeyPress(keyPress)
      }
    }
    .onAppear {
      startContinuousUpdates()
    }
    .onDisappear {
      stopContinuousUpdates()
      stopKeyboardTimer()
    }
  }
  
  // MARK: - Mouse Input Handling
  private func handleMouseInput(_ value: DragGesture.Value) {
    // Sätt input method till mouse
    if lastInputMethod != .mouse {
      lastInputMethod = .mouse
      onInputMethodChanged?(.mouse)
    }
    
    if !isDragging {
      isDragging = true
      
      // På första touch/click - flytta joysticken dit användaren klickade
      let clickLocation = value.location
      let centerOffset = CGPoint(
        x: clickLocation.x - size/2,
        y: clickLocation.y - size/2
      )
      
      let distance = sqrt(pow(centerOffset.x, 2) + pow(centerOffset.y, 2))
      
      if distance <= maxDistance {
        knobPosition = centerOffset
      } else {
        let angle = atan2(centerOffset.y, centerOffset.x)
        knobPosition = CGPoint(
          x: cos(angle) * maxDistance,
          y: sin(angle) * maxDistance
        )
      }
    } else {
      // Vanlig drag-funktionalitet - FIX: använd .width och .height från CGSize
      let translationPoint = CGPoint(x: value.translation.width, y: value.translation.height)
      let distance = sqrt(pow(translationPoint.x, 2) + pow(translationPoint.y, 2))
      
      if distance <= maxDistance {
        let dampingFactor = virtualJoystickManager.configuration.damping
        knobPosition = CGPoint(
          x: knobPosition.x + (translationPoint.x - knobPosition.x) * dampingFactor,
          y: knobPosition.y + (translationPoint.y - knobPosition.y) * dampingFactor
        )
      } else {
        let angle = atan2(translationPoint.y, translationPoint.x)
        knobPosition = CGPoint(
          x: cos(angle) * maxDistance,
          y: sin(angle) * maxDistance
        )
      }
    }
  }
  
  private func handleMouseEnd() {
    isDragging = false
    
    // Snap back med konfigurerbar hastighet
    withAnimation(.easeOut(duration: snapBackSpeed)) {
      knobPosition = .zero
    }
  }
  
  // MARK: - Keyboard Input Handling
  private func handleKeyPress(_ keyPress: KeyPress) -> KeyPress.Result {
    switch keyPress.phase {
    case .down:
      pressedKeys.insert(keyPress.key)
      
      // Hantera space separat
      if keyPress.key == .space {
        resetPosition()
        return .handled
      }
      
      // Hantera arrow keys
      if [.upArrow, .downArrow, .leftArrow, .rightArrow].contains(keyPress.key) {
        if lastInputMethod != .keyboard {
          lastInputMethod = .keyboard
          onInputMethodChanged?(.keyboard)
        }
        
        updateKeyboardPositionFromPressedKeys()
        startKeyboardTimer()
        return .handled
      }
      
    case .up:
      pressedKeys.remove(keyPress.key)
      
      if pressedKeys.isEmpty {
        // Inga tangenter tryckta - reset
        keyboardPosition = .zero
        lastInputMethod = .none
        stopKeyboardTimer()
        onInputMethodChanged?(.none)
      } else {
        // Uppdatera position baserat på kvarvarande tangenter
        updateKeyboardPositionFromPressedKeys()
      }
      
      if [.upArrow, .downArrow, .leftArrow, .rightArrow, .space].contains(keyPress.key) {
        return .handled
      }
      
    default:
      break
    }
    
    return .ignored
  }
  
  // MARK: - Keyboard Timer Functions
  private func startKeyboardTimer() {
    stopKeyboardTimer()
    
    // Skicka omedelbart
    notifyPositionChange()
    
    // Sedan kontinuerligt varje 50ms (20 Hz)
    keyboardTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
      if !pressedKeys.isEmpty && lastInputMethod == .keyboard {
        notifyPositionChange()
      }
    }
  }
  
  private func stopKeyboardTimer() {
    keyboardTimer?.invalidate()
    keyboardTimer = nil
  }
  
  // MARK: - Update keyboard position from pressed keys
  private func updateKeyboardPositionFromPressedKeys() {
    var x: Double = 0
    var y: Double = 0
    
    // Beräkna x-position (höger/vänster)
    if pressedKeys.contains(.rightArrow) {
      x += 1.0
    }
    if pressedKeys.contains(.leftArrow) {
      x -= 1.0
    }
    
    // Beräkna y-position (upp/ner)
    if pressedKeys.contains(.upArrow) {
      y -= 1.0
    }
    if pressedKeys.contains(.downArrow) {
      y += 1.0
    }
    
    // Normalisera diagonal movement
    if x != 0 && y != 0 {
      let length = sqrt(x * x + y * y)
      x = x / length
      y = y / length
    }
    
    keyboardPosition = CGPoint(x: x, y: y)
    print("🎹 Keyboard position updated: \(keyboardPosition)")
  }
  
  // MARK: - Utility Functions
  private func resetPosition() {
    knobPosition = .zero
    keyboardPosition = .zero
    lastInputMethod = .none
    pressedKeys.removeAll()
    stopKeyboardTimer()
    onInputMethodChanged?(.none)
    notifyPositionChange()
  }
  
  private func notifyPositionChange() {
    onPositionChanged(normalizedPosition)
  }
  
  private func startContinuousUpdates() {
    stopContinuousUpdates()
    
    timer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { _ in
      if lastInputMethod == .mouse {
        notifyPositionChange()
      }
    }
  }
  
  private func stopContinuousUpdates() {
    timer?.invalidate()
    timer = nil
  }
}

// MARK: - Helper Extensions
extension CGPoint {
  var magnitude: CGFloat {
    sqrt(x * x + y * y)
  }
  
  func normalized() -> CGPoint {
    let mag = magnitude
    return mag > 0 ? CGPoint(x: x / mag, y: y / mag) : .zero
  }
}

// MARK: - Preview
struct VirtualJoystick_Previews: PreviewProvider {
  static var previews: some View {
    VStack(spacing: 30) {
      Text("Virtual Joystick Demo")
        .font(.title)
        .padding()
      
      VirtualJoystick { position in
        print("Joystick position: x=\(position.x), y=\(position.y)")
      }
      
      Spacer()
    }
    .padding()
  }
}

