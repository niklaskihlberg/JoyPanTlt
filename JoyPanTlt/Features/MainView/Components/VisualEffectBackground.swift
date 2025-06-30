//
//  VisualEffectBackground.swift
//  JoyPanTlt
//
//  Created by Niklas Kihlberg on 2025-06-29.
//

import SwiftUI
import AppKit

// MARK: - Visual Effect Background
struct VisualEffectBackground: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    let isEmphasized: Bool
    
    init(
        material: NSVisualEffectView.Material = .hudWindow,
        blendingMode: NSVisualEffectView.BlendingMode = .behindWindow,
        emphasized: Bool = false
    ) {
        self.material = material
        self.blendingMode = blendingMode
        self.isEmphasized = emphasized
    }
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.isEmphasized = isEmphasized
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.isEmphasized = isEmphasized
    }
}

// MARK: - Preview
struct VisualEffectBackground_Previews: PreviewProvider {
    static var previews: some View {
        VisualEffectBackground()
    }
}
