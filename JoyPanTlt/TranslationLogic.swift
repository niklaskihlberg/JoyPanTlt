//
//  TranslationLogic.swift
//  JoyPanTlt
//
//  Created by Niklas Kihlberg on 2025-06-25.
//

import Foundation
import CoreGraphics
import SwiftUI

struct PanTiltResult {
  let pan: Double    // -180° to +180°
  let tilt: Double   // 0° to 90°
}

class TranslationLogic {
  
  // Statiska variabler för ackumulering
  private static var accumulatedX: Double = 0.0
  private static var accumulatedY: Double = 0.0
  
  // Temporary sensitivity storage
  private static var currentSensitivity: Double = 0.5
  
  /// Sätt sensitivity från extern källa
  static func setSensitivity(_ value: Double) {
    currentSensitivity = value
  }
  
  /// Konverterar joystick-input (x, y) till pan/tilt-värden
  /// - Parameter joystickPosition: CGPoint med x,y värden mellan -1.0 och 1.0
  /// - Returns: PanTiltResult med pan och tilt i grader
  static func convertJoystickToPanTilt(_ joystickPosition: CGPoint) -> PanTiltResult {
    // Hämta sensitivity och invert-inställningar från VirtualJoystickManager
    let joystickManager = VirtualJoystickManager.shared
    let sensitivity = joystickManager.getSensitivity()
    
    let x = Double(joystickPosition.x)
    let y = Double(joystickPosition.y)
    
    // Applicera invert-inställningar INNAN beräkning
    let adjustedX = joystickManager.configuration.invertPan ? -x : x
    let adjustedY = joystickManager.configuration.invertTilt ? -y : y
    
    // Använd de justerade värdena för delta-beräkning
    let deltaX = adjustedX * sensitivity
    let deltaY = adjustedY * sensitivity
    
    // Ackumulera värdena
    accumulatedX += deltaX
    accumulatedY += deltaY
    
    // Clampa värdena mellan -1.0 och +1.0
    accumulatedX = max(-1.0, min(1.0, accumulatedX))
    accumulatedY = max(-1.0, min(1.0, accumulatedY))
    
    // Beräkna pan med atan2 (negativ för korrekt riktning)
    let pan = -atan2(accumulatedX, accumulatedY) * 180.0 / .pi
    
    // Beräkna magnitude och begränsa till 1.0
    var magnitude = sqrt(accumulatedX * accumulatedX + accumulatedY * accumulatedY)
    if magnitude > 1.0 { magnitude = 1.0 }
    
    // Konvertera magnitude till tilt (0-90°)
    let tilt = magnitude * 90.0
    
    return PanTiltResult(pan: pan, tilt: tilt)
  }
  
  /// Återställer ackumulerade värden till noll
  static func resetAccumulation() {
    accumulatedX = 0.0
    accumulatedY = 0.0
  }
  
  /// Returnerar aktuella ackumulerade värden
  static func getAccumulatedValues() -> (x: Double, y: Double) {
    return (accumulatedX, accumulatedY)
  }
}

// MARK: - Extensions för enkelare användning
extension CGPoint {
  /// Konverterar denna punkt till pan/tilt-värden
  func toPanTilt() -> PanTiltResult {
    return TranslationLogic.convertJoystickToPanTilt(self)
  }
}
