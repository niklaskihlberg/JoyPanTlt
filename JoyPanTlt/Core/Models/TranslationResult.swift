//
//  TranslationResult.swift
//  JoyPanTlt
//
//  Created by Niklas Kihlberg on 2025-06-29.
//

import Foundation
import CoreGraphics

// MARK: - Translation Result
struct TranslationResult {
    let pan: Double   // -180° to +180°
    let tilt: Double  // -90° to +90°
    let normalizedX: Double  // -1.0 to 1.0
    let normalizedY: Double  // -1.0 to 1.0
    
    init(pan: Double, tilt: Double, normalizedX: Double, normalizedY: Double) {
        self.pan = pan
        self.tilt = tilt
        self.normalizedX = normalizedX
        self.normalizedY = normalizedY
    }
}

// MARK: - Input Method
enum InputMethod {
    case none
    case mouse
    case keyboard
    case gamepad
}

// MARK: - Extensions
extension TranslationResult {
    /// Skapa från normalized CGPoint
    static func from(normalizedPosition: CGPoint, sensitivity: Double = 1.0) -> TranslationResult {
        let adjustedX = normalizedPosition.x * sensitivity
        let adjustedY = normalizedPosition.y * sensitivity
        
        // Clamp values
        let clampedX = max(-1.0, min(1.0, adjustedX))
        let clampedY = max(-1.0, min(1.0, adjustedY))
        
        // Convert to degrees
        let pan = clampedX * 180.0  // -180° to +180°
        let tilt = clampedY * 90.0  // -90° to +90°
        
        return TranslationResult(
            pan: pan,
            tilt: tilt,
            normalizedX: clampedX,
            normalizedY: clampedY
        )
    }
    
    /// Är denna position "center" (nära noll)?
    var isCenter: Bool {
        return abs(normalizedX) < 0.01 && abs(normalizedY) < 0.01
    }
}
