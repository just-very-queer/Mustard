//
//  InterestHighlightViewModifier.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 30/12/24.
//
import SwiftUI

struct InterestHighlightViewModifier: ViewModifier {
    let isActive: Bool
    let score: Double // Optional: could vary effect based on score
    
    // Define a specific threshold for showing the badge
    private var showBadgeThreshold: Double = 7.0 // Example: Badge shows for scores > 7
    // Define a threshold for applying any glow
    private var glowThreshold: Double = 3.0 // Example: Glow starts for scores > 3

    // Explicitly define the initializer to ensure it's accessible
    init(isActive: Bool, score: Double) {
        self.isActive = isActive
        self.score = score
    }

    func body(content: Content) -> some View {
        // Apply effects only if isActive is true (i.e., score is above a general threshold defined by the caller)
        if isActive {
            content
                // Apply a base shadow (glow) if score is above the glowThreshold
                .shadow(color: .yellow.opacity(score > glowThreshold ? 0.6 : 0.0), // Conditional opacity
                        radius: score > 10 ? 7 : (score > glowThreshold ? 4 : 0), // Vary radius, or 0 if no glow
                        x: 0, y: 0)
                .overlay(
                    // Badge: Show only if score is above showBadgeThreshold
                    Group {
                        if score > showBadgeThreshold {
                            Circle()
                                .fill(Color.yellow.opacity(0.6))
                                .frame(width: 8, height: 8)
                                // Position badge more subtly, e.g., top-right corner of the content area
                                // This requires knowing the content's frame, using alignmentGuide or GeometryReader
                                // For simplicity, let's use a fixed offset that might work for PostView.
                                // This might need adjustment based on PostView's layout.
                                // Using an alignment guide is more robust.
                                // For now, a simple overlay at top-trailing.
                                .overlay(
                                    Circle().stroke(Color.orange.opacity(0.7), lineWidth: 1) // Add a border to the badge
                                )
                                .position(x: 15, y: 15) // Example: fixed position. This will be relative to the PostView's top-left.
                                                         // This might need adjustment.
                        }
                    }
                )

        } else {
            content
        }
    }
}

extension View {
    func interestHighlight(isActive: Bool, score: Double = 0) -> some View {
        self.modifier(InterestHighlightViewModifier(isActive: isActive, score: score))
    }
}
