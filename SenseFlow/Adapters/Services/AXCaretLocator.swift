//
//  AXCaretLocator.swift
//  SenseFlow
//

import ApplicationServices

extension SystemContextCollector {
    final class AXCaretLocator: CaretLocating, @unchecked Sendable {
        func locateCaret(
            processID: pid_t,
            targetFrame: CGRect
        ) -> CGPoint? {
            let appElement = AXUIElementCreateApplication(processID)
            guard let focusedElement = focusedElement(from: appElement),
                  let selectedRange = selectedTextRange(from: focusedElement),
                  let bounds = boundsForSelectedRange(
                    selectedRange,
                    in: focusedElement
                  ) else {
                return nil
            }

            let point: CGPoint
            if bounds.height > 0 {
                point = CGPoint(x: bounds.minX, y: bounds.midY)
            } else if bounds.width > 0 {
                point = CGPoint(x: bounds.midX, y: bounds.minY)
            } else {
                return nil
            }

            guard targetFrame.contains(point) else {
                return nil
            }
            return point
        }

        private func focusedElement(from appElement: AXUIElement) -> AXUIElement? {
            var focusedValue: CFTypeRef?
            let status = AXUIElementCopyAttributeValue(
                appElement,
                kAXFocusedUIElementAttribute as CFString,
                &focusedValue
            )
            guard status == .success,
                  let focusedValue,
                  CFGetTypeID(focusedValue) == AXUIElementGetTypeID() else {
                return nil
            }
            return (focusedValue as! AXUIElement)
        }

        private func selectedTextRange(from element: AXUIElement) -> AXValue? {
            var selectedRangeValue: CFTypeRef?
            let status = AXUIElementCopyAttributeValue(
                element,
                kAXSelectedTextRangeAttribute as CFString,
                &selectedRangeValue
            )
            guard status == .success,
                  let selectedRangeValue,
                  CFGetTypeID(selectedRangeValue) == AXValueGetTypeID() else {
                return nil
            }

            let axRangeValue = unsafeBitCast(selectedRangeValue, to: AXValue.self)
            guard AXValueGetType(axRangeValue) == .cfRange else {
                return nil
            }
            return axRangeValue
        }

        private func boundsForSelectedRange(
            _ selectedRange: AXValue,
            in element: AXUIElement
        ) -> CGRect? {
            var boundsValue: CFTypeRef?
            let status = AXUIElementCopyParameterizedAttributeValue(
                element,
                kAXBoundsForRangeParameterizedAttribute as CFString,
                selectedRange,
                &boundsValue
            )
            guard status == .success,
                  let boundsValue,
                  CFGetTypeID(boundsValue) == AXValueGetTypeID() else {
                return nil
            }

            let axRectValue = unsafeBitCast(boundsValue, to: AXValue.self)
            guard AXValueGetType(axRectValue) == .cgRect else {
                return nil
            }
            var rect = CGRect.zero
            guard AXValueGetValue(axRectValue, .cgRect, &rect) else {
                return nil
            }
            return rect
        }
    }
}
