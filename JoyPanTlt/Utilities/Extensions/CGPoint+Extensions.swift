//
//  CGPoint+Extensions.swift
//  JoyPanTlt
//
//  Created by Niklas Kihlberg on 2025-06-29.
//

import CoreGraphics
import Foundation

// MARK: - CGPoint Extensions
extension CGPoint {
    /// Magnitude (length) of the point as a vector
    var magnitude: CGFloat {
        sqrt(x * x + y * y)
    }
    
    /// Normalized point (unit vector)
    func normalized() -> CGPoint {
        let mag = magnitude
        return mag > 0 ? CGPoint(x: x / mag, y: y / mag) : .zero
    }
    
    /// Normalize point to a specific maximum distance
    func normalized(maxDistance: CGFloat) -> CGPoint {
        let mag = magnitude
        return mag > maxDistance ? normalized() * maxDistance : self
    }
    
    /// Convert to degrees (pan/tilt)
    func toDegrees() -> (pan: Double, tilt: Double) {
        // Clamp values to -1...1 range
        let clampedX = max(-1.0, min(1.0, Double(x)))
        let clampedY = max(-1.0, min(1.0, Double(y)))
        
        // Convert to degrees
        let pan = clampedX * 180.0  // -180° to +180°
        let tilt = clampedY * 90.0  // -90° to +90°
        
        return (pan: pan, tilt: tilt)
    }
    
    /// Distance to another point
    func distance(to point: CGPoint) -> CGFloat {
        let dx = x - point.x
        let dy = y - point.y
        return sqrt(dx * dx + dy * dy)
    }
    
    /// Scale point by a factor
    static func * (lhs: CGPoint, rhs: CGFloat) -> CGPoint {
        return CGPoint(x: lhs.x * rhs, y: lhs.y * rhs)
    }
    
    /// Add points
    static func + (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        return CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }
    
    /// Subtract points
    static func - (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        return CGPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }
}
