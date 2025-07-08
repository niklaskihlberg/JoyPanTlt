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
  
  /// Konverterar joystick-input (x, y) till pan/tilt-värden
  /// - Parameter joystickPosition: CGPoint med x,y värden mellan -1.0 och 1.0
  /// - Returns: PanTiltResult med pan och tilt i grader
  static func convertJoystickToPanTilt(_ position: CGPoint, for joystick: VIRTUALJOYSTICKS.JOY) -> PanTiltResult {
    
    let x = Double(position.x)
    let y = Double(position.y)
    
    // Hämta invert-inställningar och applicera INNAN beräkning
    let adjustedX = joystick.invertX ? x : -x // invertera x redan från början ...DOUBLE INVERSION!
    let adjustedY = joystick.invertY ? -y : y
    
    // Använd de justerade värdena för delta-beräkning, hämta sensitivity från VirtualJoystickManager
    let deltaX = adjustedX * joystick.sensitivity
    let deltaY = adjustedY * joystick.sensitivity
    
    // Ackumulera värdena
    joystick.X += deltaX
    joystick.Y += deltaY
    
    // Clampa värdena mellan -1.0 och +1.0
    joystick.X = max(-1.0, min(1.0, joystick.X))
    joystick.Y = max(-1.0, min(1.0, joystick.Y))
    
    // PAN:
    let pan = -atan2(joystick.X, joystick.Y) * 180.0 / .pi // Beräkna pan med atan2 (negativ för korrekt riktning)
    var magnitude = sqrt(joystick.X * joystick.X + joystick.Y * joystick.Y) // Beräkna magnitude och begränsa till 1.0
    if magnitude > 1.0 { magnitude = 1.0 }
    
    // TILT:
    let tilt = magnitude * 90.0 // Konvertera magnitude till tilt (0-90°)
    
    // Returnera...
    return PanTiltResult(pan: pan, tilt: tilt)
    
  }
}
