//
//  OpenClawAXElementAccessor.swift
//  SenseFlow
//

import AppKit
import ApplicationServices

struct OpenClawAXTraversalContext {
    let rootElement: AXUIElement
    let focusedElement: AXUIElement?
}

protocol OpenClawAXElementAccessing: Sendable {
    func makeTraversalContext(processID: pid_t) -> OpenClawAXTraversalContext
    func role(of element: AXUIElement) -> String
    func primaryName(of element: AXUIElement) -> String
    func frame(of element: AXUIElement) -> CGRect?
    func children(of element: AXUIElement) -> [AXUIElement]
}

final class OpenClawAXElementAccessor: OpenClawAXElementAccessing, @unchecked Sendable {
    func makeTraversalContext(processID: pid_t) -> OpenClawAXTraversalContext {
        let appElement = AXUIElementCreateApplication(processID)
        let rootElement = resolveFocusedWindow(processID: processID) ?? appElement
        return OpenClawAXTraversalContext(
            rootElement: rootElement,
            focusedElement: resolveFocusedElement(processID: processID)
        )
    }

    func role(of element: AXUIElement) -> String {
        let rawRole = axStringValue(of: kAXRoleAttribute as CFString, from: element) ?? "AXUnknown"
        return normalizeAXRole(rawRole)
    }

    func primaryName(of element: AXUIElement) -> String {
        let candidates: [String?] = [
            axStringValue(of: kAXTitleAttribute as CFString, from: element),
            axStringValue(of: "AXPlaceholderValue" as CFString, from: element),
            axStringValue(of: kAXDescriptionAttribute as CFString, from: element),
            axStringValue(of: kAXValueAttribute as CFString, from: element)
        ]

        for candidate in candidates.compactMap({ $0 }) {
            let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return String(trimmed.prefix(80))
            }
        }
        return ""
    }

    func frame(of element: AXUIElement) -> CGRect? {
        guard let origin = axPointValue(of: kAXPositionAttribute as CFString, from: element),
              let size = axSizeValue(of: kAXSizeAttribute as CFString, from: element),
              size.width > 0,
              size.height > 0 else {
            return nil
        }
        return CGRect(origin: origin, size: size)
    }

    func children(of element: AXUIElement) -> [AXUIElement] {
        var value: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value)
        guard status == .success,
              let array = value as? [Any] else {
            return []
        }

        return array.compactMap { item in
            guard CFGetTypeID(item as CFTypeRef) == AXUIElementGetTypeID() else {
                return nil
            }
            return (item as! AXUIElement)
        }
    }

    private func resolveFocusedElement(processID: pid_t) -> AXUIElement? {
        let appElement = AXUIElementCreateApplication(processID)
        for attempt in 0..<2 {
            var focusedElementValue: CFTypeRef?
            let focusedStatus = AXUIElementCopyAttributeValue(
                appElement,
                kAXFocusedUIElementAttribute as CFString,
                &focusedElementValue
            )

            if focusedStatus == .success,
               let focusedElementValue,
               CFGetTypeID(focusedElementValue) == AXUIElementGetTypeID() {
                return (focusedElementValue as! AXUIElement)
            }

            if attempt == 0 {
                Thread.sleep(forTimeInterval: 0.03)
            }
        }
        return nil
    }

    private func resolveFocusedWindow(processID: pid_t) -> AXUIElement? {
        let appElement = AXUIElementCreateApplication(processID)
        var focusedWindowValue: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedWindowAttribute as CFString,
            &focusedWindowValue
        )

        guard status == .success,
              let focusedWindowValue,
              CFGetTypeID(focusedWindowValue) == AXUIElementGetTypeID() else {
            return nil
        }
        return (focusedWindowValue as! AXUIElement)
    }

    private func normalizeAXRole(_ role: String) -> String {
        var normalized = role.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.hasPrefix("AX") {
            normalized.removeFirst(2)
        }
        return normalized.lowercased()
    }

    private func axSizeValue(of attribute: CFString, from element: AXUIElement) -> CGSize? {
        var value: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard status == .success,
              let value,
              CFGetTypeID(value) == AXValueGetTypeID() else {
            return nil
        }

        let axValue = unsafeBitCast(value, to: AXValue.self)
        guard AXValueGetType(axValue) == .cgSize else { return nil }
        var size = CGSize.zero
        guard AXValueGetValue(axValue, .cgSize, &size) else { return nil }
        return size
    }

    private func axPointValue(of attribute: CFString, from element: AXUIElement) -> CGPoint? {
        var value: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard status == .success,
              let value,
              CFGetTypeID(value) == AXValueGetTypeID() else {
            return nil
        }

        let axValue = unsafeBitCast(value, to: AXValue.self)
        guard AXValueGetType(axValue) == .cgPoint else { return nil }
        var point = CGPoint.zero
        guard AXValueGetValue(axValue, .cgPoint, &point) else { return nil }
        return point
    }

    private func axStringValue(of attribute: CFString, from element: AXUIElement) -> String? {
        var value: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard status == .success, let value else {
            return nil
        }

        let candidate: String?
        if let stringValue = value as? String {
            candidate = stringValue
        } else if let attributed = value as? NSAttributedString {
            candidate = attributed.string
        } else if let number = value as? NSNumber {
            candidate = number.stringValue
        } else {
            candidate = nil
        }

        guard let candidate else { return nil }
        let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
