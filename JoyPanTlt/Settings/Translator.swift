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
    
    // Hämta invert-inställningar och applicera INNAN beräkning och invertera x redan från början ...DOUBLE INVERSION!
    let adjustedX = joystick.invertX ? x : -x 
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
    let panDegree = -atan2(joystick.X, joystick.Y) * 180.0 / .pi // Konvertera till grader
    let rotationPan = panDegree + joystick.rotationOffset // Lägg till rotation offset
    var delta = rotationPan - joystick.deltaPan // Räkna ut skillnaden mot förra pan-värdet
    joystick.deltaPan = rotationPan // Spara aktuellt pan-värde för nästa gång
    if delta > 180.0 { delta -= 360.0 } // Justera för wrap över -180/+180
    else if delta < -180.0 { delta += 360.0 } // Justera för wrap över -180/+180
    joystick.accumulatedPan += delta // Ackumulera pan
    var pan = joystick.accumulatedPan // Använd accumulatedPan som pan-värde
    let prevPan = joystick.lastPan // Spara förra panOut
    joystick.lastPan = pan // Spara aktuellt pan-värde för nästa gång

    // FOLDOVER STATE-MASCHINE // Normalt läge
    if !joystick.flip {
        if pan < joystick.minPan && prevPan >= joystick.minPan { // Gå in i flip om vi går under minPan (medsols)
            joystick.accumulatedPan += 360.0
            pan = joystick.accumulatedPan
            joystick.flip = true
        }
        else if pan > joystick.maxPan && prevPan <= joystick.maxPan { // Gå in i flip om vi går över maxPan (motsols)
            joystick.accumulatedPan -= 360.0
            pan = joystick.accumulatedPan
            joystick.flip = true
        }
    } 

    // FOLDOVER STATE-MASCHINE // Flip-läge:
    else {
        if pan < joystick.minPan && prevPan >= joystick.minPan { // Gå ur flip om vi går under minPan (motsols)
            joystick.accumulatedPan += 360.0
            pan = joystick.accumulatedPan
            joystick.flip = false
        }
        else if pan > joystick.maxPan && prevPan <= joystick.maxPan { // Gå ur flip om vi går över maxPan (medsols)
            joystick.accumulatedPan -= 360.0
            pan = joystick.accumulatedPan
            joystick.flip = false
        }
    }

    // TILT:
    var magnitude = sqrt(joystick.X * joystick.X + joystick.Y * joystick.Y)
    if magnitude > 1.0 { magnitude = 1.0 }
    var tilt = joystick.minTilt + magnitude * (joystick.maxTilt - joystick.minTilt)
    if joystick.flip { tilt = -tilt } // Invertera tilt om vi är i foldover-mode  
    
    // Returnera...
    return PanTiltResult(pan: pan, tilt: tilt)
  
  }
}
