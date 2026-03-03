//
//  OpenClawUITreeCandidateBuilder.swift
//  SenseFlow
//

import AppKit
import ApplicationServices

struct OpenClawUITreeCandidate {
    let ref: String
    let frame: CGRect
    let role: String
    let name: String?
    let isFocused: Bool
    let isInteractive: Bool
}

protocol OpenClawUITreeCandidateBuilding: Sendable {
    func buildCandidates(
        processID: pid_t,
        displayFrame: CGRect,
        axAccessor: any OpenClawAXElementAccessing
    ) -> [OpenClawUITreeCandidate]
}

final class OpenClawUITreeCandidateBuilder: OpenClawUITreeCandidateBuilding, @unchecked Sendable {
    private let maxDepth = 8
    private let maxNodes = 320

    func buildCandidates(
        processID: pid_t,
        displayFrame: CGRect,
        axAccessor: any OpenClawAXElementAccessing
    ) -> [OpenClawUITreeCandidate] {
        let context = axAccessor.makeTraversalContext(processID: processID)
        let displayArea = displayFrame.width * displayFrame.height

        var stack: [(element: AXUIElement, depth: Int)] = [(context.rootElement, 0)]
        var visited: Set<CFHashCode> = [CFHash(context.rootElement)]
        var dedupKeys: Set<String> = []
        var candidates: [OpenClawUITreeCandidate] = []
        var refCounter = 0

        while !stack.isEmpty, visited.count <= maxNodes {
            let current = stack.removeLast()
            let element = current.element
            let depth = current.depth
            guard depth <= maxDepth else { continue }

            let role = axAccessor.role(of: element)
            let name = axAccessor.primaryName(of: element)
            let isFocused = context.focusedElement.map { CFEqual($0, element) } ?? false

            guard shouldIncludeInRoleSnapshot(role: role, name: name, depth: depth, isFocused: isFocused) else {
                pushChildren(of: element, depth: depth, to: &stack, visited: &visited, axAccessor: axAccessor)
                continue
            }

            if let frame = axAccessor.frame(of: element),
               frame.intersects(displayFrame) {
                let frameArea = frame.width * frame.height
                let isInteractive = isInteractiveAXRole(role)

                guard shouldAssignRoleReference(
                    role: role,
                    name: name,
                    depth: depth
                ) else {
                    pushChildren(of: element, depth: depth, to: &stack, visited: &visited, axAccessor: axAccessor)
                    continue
                }

                if (frameArea > 0 && frameArea <= displayArea * 0.80) || isFocused {
                    let dedupKey = frameDedupKey(for: frame, role: role)
                    if dedupKeys.insert(dedupKey).inserted {
                        refCounter += 1
                        candidates.append(
                            OpenClawUITreeCandidate(
                                ref: "e\(refCounter)",
                                frame: frame,
                                role: role,
                                name: name.isEmpty ? nil : name,
                                isFocused: isFocused,
                                isInteractive: isInteractive
                            )
                        )
                    }
                }
            }

            pushChildren(of: element, depth: depth, to: &stack, visited: &visited, axAccessor: axAccessor)
        }

        return candidates
    }

    private func pushChildren(
        of element: AXUIElement,
        depth: Int,
        to stack: inout [(element: AXUIElement, depth: Int)],
        visited: inout Set<CFHashCode>,
        axAccessor: any OpenClawAXElementAccessing
    ) {
        let children = axAccessor.children(of: element)
        for child in children.reversed() {
            let key = CFHash(child)
            if visited.insert(key).inserted {
                stack.append((child, depth + 1))
            }
        }
    }

    private func shouldIncludeInRoleSnapshot(role: String, name: String, depth: Int, isFocused: Bool) -> Bool {
        if isFocused {
            return true
        }
        if isInteractiveAXRole(role) {
            return true
        }
        if isContentAXRole(role), !name.isEmpty {
            return true
        }
        if !isStructuralAXRole(role), !name.isEmpty, depth <= 4 {
            return true
        }
        return false
    }

    private func shouldAssignRoleReference(role: String, name: String, depth: Int) -> Bool {
        if isInteractiveAXRole(role) {
            return true
        }
        if isContentAXRole(role), !name.isEmpty {
            return true
        }
        if !isStructuralAXRole(role), !name.isEmpty, depth <= 4 {
            return true
        }
        return false
    }

    private func frameDedupKey(for frame: CGRect, role: String) -> String {
        let x = Int(frame.origin.x / 3.0)
        let y = Int(frame.origin.y / 3.0)
        let w = Int(frame.width / 3.0)
        let h = Int(frame.height / 3.0)
        return "\(role):\(x):\(y):\(w):\(h)"
    }

    private func isInteractiveAXRole(_ role: String) -> Bool {
        let interactiveRoles: Set<String> = [
            "button", "link", "textfield", "textarea", "textbox", "searchfield", "searchbox",
            "checkbox", "radiobutton", "popupbutton", "menuitem", "menuitemcheckbox",
            "menuitemradio", "combobox", "listbox", "option", "tab", "switch", "slider",
            "spinbutton", "treeitem"
        ]
        return interactiveRoles.contains(role)
    }

    private func isContentAXRole(_ role: String) -> Bool {
        let contentRoles: Set<String> = [
            "heading", "cell", "gridcell", "columnheader", "rowheader", "listitem",
            "article", "region", "main", "navigation", "statictext"
        ]
        return contentRoles.contains(role)
    }

    private func isStructuralAXRole(_ role: String) -> Bool {
        let structuralRoles: Set<String> = [
            "generic", "group", "list", "table", "row", "rowgroup", "grid", "treegrid",
            "menu", "menubar", "toolbar", "tablist", "tree", "directory", "document",
            "application", "presentation", "none", "window", "scrollarea"
        ]
        return structuralRoles.contains(role)
    }
}
