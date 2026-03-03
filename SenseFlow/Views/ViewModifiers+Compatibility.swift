//
//  ViewModifiers+Compatibility.swift
//  SenseFlow
//
//  Created on 2026-01-30.
//  Backward compatibility layer for macOS 13+
//

import SwiftUI

// MARK: - Glass Effect Compatibility

extension View {
    /// Applies glass effect on macOS 26+ or thin material on macOS 13-25
    ///
    /// This modifier provides backward compatibility for the Liquid Glass effect.
    /// - On macOS 26+: Uses `.glassEffect(.regular)` for dynamic blur
    /// - On macOS 13-25: Falls back to `.thinMaterial` for static blur
    ///
    /// - Parameters:
    ///   - shape: The shape to apply the effect to (default: RoundedRectangle with 20pt radius)
    ///   - cornerRadius: Corner radius for the shape (default: 20)
    ///
    /// - Returns: A view with version-appropriate glass/material effect
    @ViewBuilder
    func compatibleGlassEffect<S: Shape>(
        in shape: S,
        cornerRadius: CGFloat = 20
    ) -> some View {
        if #available(macOS 26, *) {
            self.glassEffect(.regular, in: shape)
        } else {
            self.background(.thinMaterial, in: shape)
        }
    }

    /// Convenience method for rounded rectangle glass effect
    ///
    /// - Parameter cornerRadius: Corner radius for the rounded rectangle (default: 20)
    /// - Returns: A view with version-appropriate glass/material effect
    @ViewBuilder
    func compatibleGlassEffect(cornerRadius: CGFloat = 20) -> some View {
        if #available(macOS 26, *) {
            self.glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius))
        } else {
            self.background(.thinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
        }
    }
}

// MARK: - Material Compatibility

extension View {
    /// Applies a compatible material background
    ///
    /// This modifier provides a consistent way to apply material backgrounds
    /// across different macOS versions.
    ///
    /// - Parameters:
    ///   - material: The material style to apply
    ///   - shape: The shape to apply the material to
    ///
    /// - Returns: A view with the specified material background
    @ViewBuilder
    func compatibleMaterial<S: Shape>(
        _ material: Material = .thinMaterial,
        in shape: S
    ) -> some View {
        self.background(material, in: shape)
    }

    /// Convenience method for rounded rectangle material
    ///
    /// - Parameters:
    ///   - material: The material style to apply (default: .thinMaterial)
    ///   - cornerRadius: Corner radius for the rounded rectangle (default: 20)
    ///
    /// - Returns: A view with the specified material background
    @ViewBuilder
    func compatibleMaterial(
        _ material: Material = .thinMaterial,
        cornerRadius: CGFloat = 20
    ) -> some View {
        self.background(material, in: RoundedRectangle(cornerRadius: cornerRadius))
    }
}

// MARK: - Animation Compatibility

extension Animation {
    /// Snappy animation with backward compatibility
    ///
    /// - On macOS 14+: Uses `.snappy()` for quick, responsive animations
    /// - On macOS 13: Falls back to spring animation with similar feel
    ///
    /// - Parameters:
    ///   - duration: Animation duration in seconds (default: 0.4)
    ///   - extraBounce: Additional bounce amount 0-1 (default: 0.0)
    ///
    /// - Returns: Platform-appropriate animation
    static func compatibleSnappy(duration: TimeInterval = 0.4, extraBounce: Double = 0.0) -> Animation {
        if #available(macOS 14, *) {
            return .snappy(duration: duration, extraBounce: extraBounce)
        } else {
            // Approximate snappy with spring: quick response, minimal bounce
            return .spring(response: duration, dampingFraction: 1.0 - extraBounce * 0.3)
        }
    }

    /// Smooth animation with backward compatibility
    ///
    /// - On macOS 14+: Uses `.smooth()` for fluid, no-bounce animations
    /// - On macOS 13: Falls back to easeInOut for similar smoothness
    ///
    /// - Parameters:
    ///   - duration: Animation duration in seconds (default: 0.3)
    ///   - extraBounce: Additional bounce amount 0-1 (default: 0.0)
    ///
    /// - Returns: Platform-appropriate animation
    static func compatibleSmooth(duration: TimeInterval = 0.3, extraBounce: Double = 0.0) -> Animation {
        if #available(macOS 14, *) {
            return .smooth(duration: duration, extraBounce: extraBounce)
        } else {
            // Smooth animations use easeInOut on older systems
            return .easeInOut(duration: duration)
        }
    }

    /// Bouncy animation with backward compatibility
    ///
    /// - On macOS 14+: Uses `.bouncy()` for playful, elastic animations
    /// - On macOS 13: Falls back to spring with more bounce
    ///
    /// - Parameters:
    ///   - duration: Animation duration in seconds (default: 0.5)
    ///   - extraBounce: Additional bounce amount 0-1 (default: 0.15)
    ///
    /// - Returns: Platform-appropriate animation
    static func compatibleBouncy(duration: TimeInterval = 0.5, extraBounce: Double = 0.15) -> Animation {
        if #available(macOS 14, *) {
            return .bouncy(duration: duration, extraBounce: extraBounce)
        } else {
            // Bouncy uses spring with lower damping for more bounce
            return .spring(response: duration, dampingFraction: 0.7 - extraBounce * 0.3)
        }
    }
}

// MARK: - Control Style Compatibility

extension View {
    /// Applies large control size for better touch targets and readability
    ///
    /// - Returns: A view with large control size
    func compatibleControlSize() -> some View {
        self.controlSize(.large)
    }

    /// Applies modern button style with backward compatibility
    ///
    /// - On macOS 26+: Uses `.glass` or `.glassProminent` for Liquid Glass effect
    /// - On macOS 13-25: Falls back to `.bordered` or `.borderedProminent`
    ///
    /// - Parameter prominent: Whether to use prominent style (default: false)
    /// - Returns: A view with appropriate button style
    @ViewBuilder
    func compatibleButtonStyle(prominent: Bool = false) -> some View {
        if #available(macOS 26, *) {
            if prominent {
                self.buttonStyle(.glassProminent)
            } else {
                self.buttonStyle(.glass)
            }
        } else {
            if prominent {
                self.buttonStyle(.borderedProminent)
            } else {
                self.buttonStyle(.bordered)
            }
        }
    }
}

// MARK: - Usage Examples

/*
 Example 1: Basic glass effect
 ```swift
 VStack {
     Text("Hello")
 }
 .compatibleGlassEffect()
 ```

 Example 2: Custom corner radius
 ```swift
 VStack {
     Text("Hello")
 }
 .compatibleGlassEffect(cornerRadius: 12)
 ```

 Example 3: Custom shape
 ```swift
 VStack {
     Text("Hello")
 }
 .compatibleGlassEffect(in: Circle())
 ```

 Example 4: Material fallback
 ```swift
 VStack {
     Text("Hello")
 }
 .compatibleMaterial(.regularMaterial, cornerRadius: 16)
 ```

 Example 5: Compatible animations
 ```swift
 Button("Save") { }
     .scaleEffect(isPressed ? 0.95 : 1.0)
     .animation(.compatibleSnappy(), value: isPressed)

 VStack { }
     .opacity(isVisible ? 1.0 : 0.0)
     .animation(.compatibleSmooth(), value: isVisible)
 ```

 Example 6: Modern control styles
 ```swift
 Form {
     Toggle("Option", isOn: $enabled)
     Button("Save") { }
         .compatibleButtonStyle(prominent: true)
 }
 .compatibleControlSize()
 ```
 */
