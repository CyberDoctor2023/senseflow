//
//  OpenClawUITreeAnnotationMapper.swift
//  SenseFlow
//

import AppKit

protocol OpenClawUITreeAnnotationMapping: Sendable {
    func map(_ candidates: [OpenClawUITreeCandidate]) -> [SystemContextCollector.UITreeOverlayAnnotation]
}

final class OpenClawUITreeAnnotationMapper: OpenClawUITreeAnnotationMapping, @unchecked Sendable {
    private let maxAnnotations = 40

    func map(_ candidates: [OpenClawUITreeCandidate]) -> [SystemContextCollector.UITreeOverlayAnnotation] {
        let selected = Array(candidates.prefix(maxAnnotations))
        guard !selected.isEmpty else { return [] }

        return selected.map { candidate in
            return SystemContextCollector.UITreeOverlayAnnotation(
                ref: candidate.ref,
                frame: candidate.frame,
                role: candidate.role,
                name: candidate.name,
                isFocused: candidate.isFocused,
                isInteractive: candidate.isInteractive,
                isNearCursor: false
            )
        }
    }
}
