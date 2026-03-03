//
//  CompatiblePhaseAnimator.swift
//  SenseFlow
//
//  Created on 2026-01-30.
//  Backward compatibility wrapper for PhaseAnimator (macOS 14+)
//

import SwiftUI

// MARK: - Compatible Phase Animator

/// A compatibility wrapper for PhaseAnimator that works on macOS 13+
///
/// This wrapper provides phase-based animations on macOS 14+ using the native
/// PhaseAnimator API, and falls back to simple .animation() on macOS 13.
///
/// **Usage:**
/// ```swift
/// CompatiblePhaseAnimator([false, true]) { phase in
///     CardView()
///         .scaleEffect(phase ? 1.0 : 0.8)
///         .opacity(phase ? 1.0 : 0.0)
/// } animation: { phase in
///     .snappy(duration: 0.5, extraBounce: 0.15)
/// }
/// ```
///
/// **Behavior:**
/// - macOS 14+: Uses native PhaseAnimator with full phase control
/// - macOS 13: Simulates phase animation with .animation() modifier
///
/// **Limitations on macOS 13:**
/// - Only supports boolean phases (false → true)
/// - No multi-phase support
/// - extraBounce parameter ignored (not available in .snappy on macOS 13)
struct CompatiblePhaseAnimator<Phase: Equatable, Content: View>: View {
    let phases: [Phase]
    let content: (Phase) -> Content
    let animation: ((Phase) -> Animation)?

    @State private var currentPhase: Phase

    /// Creates a compatible phase animator
    ///
    /// - Parameters:
    ///   - phases: Array of phases to animate through
    ///   - content: View builder that receives the current phase
    ///   - animation: Optional animation for each phase transition
    init(
        _ phases: [Phase],
        @ViewBuilder content: @escaping (Phase) -> Content,
        animation: ((Phase) -> Animation)? = nil
    ) {
        self.phases = phases
        self.content = content
        self.animation = animation
        self._currentPhase = State(initialValue: phases.first!)
    }

    var body: some View {
        if #available(macOS 14, *) {
            // Use native PhaseAnimator on macOS 14+
            PhaseAnimator(phases) { phase in
                content(phase)
            } animation: { phase in
                animation?(phase) ?? .snappy(duration: 0.5)
            }
        } else {
            // Fallback for macOS 13: simple animation
            content(currentPhase)
                .animation(
                    animation?(currentPhase) ?? .snappy(duration: 0.5),
                    value: currentPhase
                )
                .onAppear {
                    // Trigger phase transition on appear
                    if phases.count > 1 {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            currentPhase = phases[1]
                        }
                    }
                }
        }
    }
}

// MARK: - Convenience Initializer for Boolean Phases

extension CompatiblePhaseAnimator where Phase == Bool {
    /// Convenience initializer for boolean phase animations (false → true)
    ///
    /// This is the most common use case for entrance animations.
    ///
    /// - Parameters:
    ///   - content: View builder that receives the current phase
    ///   - animation: Animation to use for the transition
    init(
        @ViewBuilder content: @escaping (Bool) -> Content,
        animation: Animation = .snappy(duration: 0.5)
    ) {
        self.init([false, true], content: content) { _ in animation }
    }
}

// MARK: - Usage Examples

/*
 Example 1: Card entrance animation (boolean phases)
 ```swift
 CompatiblePhaseAnimator { phase in
     CardView()
         .scaleEffect(phase ? 1.0 : 0.8)
         .opacity(phase ? 1.0 : 0.0)
 } animation: {
     .snappy(duration: 0.5, extraBounce: 0.15)
 }
 ```

 Example 2: Multi-phase animation (macOS 14+ only)
 ```swift
 CompatiblePhaseAnimator([0, 1, 2]) { phase in
     Circle()
         .fill(phase == 0 ? .red : phase == 1 ? .green : .blue)
 } animation: { phase in
     .smooth(duration: 0.3)
 }
 ```

 Example 3: Custom phases
 ```swift
 enum AnimationPhase {
     case initial, active, complete
 }

 CompatiblePhaseAnimator([.initial, .active, .complete]) { phase in
     MyView()
         .offset(y: phase == .initial ? 20 : 0)
         .opacity(phase == .complete ? 1.0 : 0.5)
 } animation: { _ in
     .spring(response: 0.4, dampingFraction: 0.8)
 }
 ```

 **Note on macOS 13 limitations:**
 - Multi-phase animations will only show first → second phase
 - extraBounce parameter in .snappy() is not available
 - Use .spring() for bounce effects on macOS 13
 */
