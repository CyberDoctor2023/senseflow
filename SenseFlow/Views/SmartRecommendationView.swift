//
//  SmartRecommendationView.swift
//  SenseFlow
//
//  Created by Claude on 2026-01-22.
//

import SwiftUI

/// Smart recommendation presentation view
/// Shows AI-recommended tool with confirmation actions
struct SmartRecommendationView: View {
    let recommendation: SmartRecommendation
    let onExecute: () -> Void
    let onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            // Header
            HStack {
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundStyle(.blue)
                Text(Strings.SmartRecommendation.title)
                    .font(.headline)
            }

            Divider()

            // Tool Info
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                // Tool Name
                HStack {
                    Text(Strings.SmartRecommendation.toolLabel)
                        .foregroundStyle(.secondary)
                    Text(recommendation.toolName)
                        .fontWeight(.semibold)
                }

                // Reason
                HStack(alignment: .top) {
                    Text(Strings.SmartRecommendation.reasonLabel)
                        .foregroundStyle(.secondary)
                    Text(recommendation.reason)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Confidence
                HStack {
                    Text(Strings.SmartRecommendation.confidenceLabel)
                        .foregroundStyle(.secondary)
                    Text("\(Int(recommendation.confidence * Double(BusinessRules.SmartRecommendation.percentageMultiplier)))%")
                        .fontWeight(.medium)
                        .foregroundStyle(confidenceColor)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            // Actions
            HStack(spacing: DesignSystem.Spacing.md) {
                Button(Strings.Buttons.cancel) {
                    onCancel()
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button(Strings.Buttons.execute) {
                    onExecute()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(Constants.spacing24)
        .frame(
            width: Constants.DialogWindow.smartRecommendation.width,
            height: Constants.DialogWindow.smartRecommendation.height
        )
    }

    // MARK: - Helpers

    private var confidenceColor: Color {
        if recommendation.confidence >= BusinessRules.SmartRecommendation.highConfidenceThreshold {
            return .green
        } else if recommendation.confidence >= BusinessRules.SmartRecommendation.mediumConfidenceThreshold {
            return .orange
        } else {
            return .red
        }
    }
}

// MARK: - Preview

#Preview {
    SmartRecommendationView(
        recommendation: SmartRecommendation(
            toolID: UUID(),
            toolName: "Translate to English",
            reason: "You're working in a code editor with Chinese text in clipboard.",
            confidence: 0.85,
            responseTime: 1.2
        ),
        onExecute: {},
        onCancel: {}
    )
}
