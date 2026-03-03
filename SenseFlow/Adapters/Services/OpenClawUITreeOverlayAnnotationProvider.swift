//
//  OpenClawUITreeOverlayAnnotationProvider.swift
//  SenseFlow
//

import AppKit

final class OpenClawUITreeOverlayAnnotationProvider: SystemContextCollector.UITreeOverlayAnnotationProviding, @unchecked Sendable {
    private let axAccessor: any OpenClawAXElementAccessing
    private let candidateBuilder: any OpenClawUITreeCandidateBuilding
    private let annotationMapper: any OpenClawUITreeAnnotationMapping

    init(
        axAccessor: any OpenClawAXElementAccessing = OpenClawAXElementAccessor(),
        candidateBuilder: any OpenClawUITreeCandidateBuilding = OpenClawUITreeCandidateBuilder(),
        annotationMapper: any OpenClawUITreeAnnotationMapping = OpenClawUITreeAnnotationMapper()
    ) {
        self.axAccessor = axAccessor
        self.candidateBuilder = candidateBuilder
        self.annotationMapper = annotationMapper
    }

    func buildAnnotations(
        processID: pid_t,
        displayFrame: CGRect
    ) -> [SystemContextCollector.UITreeOverlayAnnotation] {
        guard displayFrame.width > 0, displayFrame.height > 0 else {
            return []
        }

        let candidates = candidateBuilder.buildCandidates(
            processID: processID,
            displayFrame: displayFrame,
            axAccessor: axAccessor
        )

        return annotationMapper.map(candidates)
    }
}
