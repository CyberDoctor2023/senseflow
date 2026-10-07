//
//  SmartRecommendation.swift
//  SenseFlow
//
//  Created by Claude on 2026-01-22.
//

import Foundation

/// AI recommendation result
struct SmartRecommendation: Codable {
    // MARK: - Recommended Tool

    /// Recommended tool ID
    let toolID: UUID

    /// Recommended tool name
    let toolName: String

    /// Recommendation reason
    let reason: String

    /// Confidence score (0.0 - 1.0)
    let confidence: Double

    // MARK: - Metadata

    /// Recommendation generation timestamp
    let timestamp: Date

    /// AI response time (seconds)
    let responseTime: TimeInterval

    // MARK: - Initialization

    init(toolID: UUID, toolName: String, reason: String, confidence: Double, responseTime: TimeInterval) {
        self.toolID = toolID
        self.toolName = toolName
        self.reason = reason
        self.confidence = confidence
        self.timestamp = Date()
        self.responseTime = responseTime
    }

    // MARK: - Validation

    /// Whether this is a high confidence recommendation
    var isHighConfidence: Bool {
        confidence >= 0.7
    }

    /// Whether this should be presented to user
    var shouldPresent: Bool {
        confidence >= 0.5
    }
}

/// AI recommendation response (from AI service)
struct SmartRecommendationResponse: Codable {
    let tool_id: String
    let tool_name: String
    let reason: String
    let confidence: Double
}
