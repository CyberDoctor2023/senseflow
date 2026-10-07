//
//  OpenClawUITreeOverlayRenderer.swift
//  SenseFlow
//

import AppKit

final class OpenClawUITreeOverlayRenderer: SystemContextCollector.UITreeOverlayRendering, @unchecked Sendable {
    private struct OverlayVisualStyle {
        let stroke: NSColor
        let fill: NSColor
        let lineWidth: CGFloat
    }

    private struct OverlayCoordinateMapper {
        let displayFrame: CGRect
        let imageSize: NSSize
        let scaleX: CGFloat
        let scaleY: CGFloat

        init?(displayFrame: CGRect, imageSize: NSSize) {
            guard displayFrame.width > 0, displayFrame.height > 0 else {
                return nil
            }
            self.displayFrame = displayFrame
            self.imageSize = imageSize
            self.scaleX = imageSize.width / displayFrame.width
            self.scaleY = imageSize.height / displayFrame.height
        }

        func mapRect(_ globalRect: CGRect) -> CGRect? {
            let intersection = globalRect.intersection(displayFrame)
            guard !intersection.isNull, intersection.width > 0, intersection.height > 0 else {
                return nil
            }

            let x = (intersection.minX - displayFrame.minX) * scaleX
            let y = (displayFrame.maxY - intersection.maxY) * scaleY
            let width = intersection.width * scaleX
            let height = intersection.height * scaleY

            guard width >= 2, height >= 2 else { return nil }
            return CGRect(x: x, y: y, width: width, height: height)
        }

        func mapPoint(_ globalPoint: CGPoint) -> CGPoint? {
            guard displayFrame.contains(globalPoint) else {
                return nil
            }
            return CGPoint(
                x: (globalPoint.x - displayFrame.minX) * scaleX,
                y: (displayFrame.maxY - globalPoint.y) * scaleY
            )
        }
    }

    func render(
        baseImage: CGImage,
        displayFrame: CGRect,
        cursorLocation: CGPoint?,
        annotations: [SystemContextCollector.UITreeOverlayAnnotation]
    ) -> CGImage? {
        let size = NSSize(width: baseImage.width, height: baseImage.height)
        let base = NSImage(cgImage: baseImage, size: size)
        let canvas = NSImage(size: size)
        canvas.lockFocus()

        base.draw(in: NSRect(origin: .zero, size: size))
        let mapper = OverlayCoordinateMapper(displayFrame: displayFrame, imageSize: size)

        drawAnnotations(
            annotations,
            mapper: mapper,
            imageSize: size
        )

        if let cursorLocation,
           let cursorPoint = mapper?.mapPoint(cursorLocation) {
            drawCursorMarker(at: cursorPoint, imageSize: size)
        }

        if !annotations.isEmpty {
            drawOverlayLegend(
                imageSize: size,
                totalCount: annotations.count
            )
        }

        canvas.unlockFocus()
        return canvas.cgImage(forProposedRect: nil, context: nil, hints: nil)
    }

    private func drawAnnotations(
        _ annotations: [SystemContextCollector.UITreeOverlayAnnotation],
        mapper: OverlayCoordinateMapper?,
        imageSize: NSSize
    ) {
        guard let mapper else { return }

        for annotation in annotations {
            guard let rawRect = mapper.mapRect(annotation.frame) else {
                continue
            }

            let rect = rawRect.integral
            let style = overlayStyle(for: annotation)
            let box = NSBezierPath(roundedRect: rect, xRadius: 6, yRadius: 6)
            style.fill.setFill()
            box.fill()
            style.stroke.setStroke()
            box.lineWidth = style.lineWidth
            box.stroke()

            drawOverlayLabel(
                overlayLabelText(for: annotation),
                anchorRect: rect,
                imageSize: imageSize,
                backgroundColor: style.stroke
            )
        }
    }

    private func overlayStyle(for annotation: SystemContextCollector.UITreeOverlayAnnotation) -> OverlayVisualStyle {
        if annotation.isFocused {
            return OverlayVisualStyle(
                stroke: NSColor(calibratedRed: 0.95, green: 0.23, blue: 0.31, alpha: 0.95),
                fill: NSColor(calibratedRed: 0.95, green: 0.23, blue: 0.31, alpha: 0.15),
                lineWidth: 3.2
            )
        }
        return OverlayVisualStyle(
            stroke: NSColor(calibratedRed: 0.17, green: 0.76, blue: 0.95, alpha: 0.92),
            fill: NSColor(calibratedRed: 0.17, green: 0.76, blue: 0.95, alpha: 0.08),
            lineWidth: 2.0
        )
    }

    private func overlayLabelText(for annotation: SystemContextCollector.UITreeOverlayAnnotation) -> String {
        var text = "\(annotation.ref) \(annotation.role)"
        if let name = annotation.name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            text += " \"\(sanitizeLabelText(String(name.prefix(34))))\""
        }
        return text
    }

    private func sanitizeLabelText(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\"", with: "'")
    }

    private func drawOverlayLabel(
        _ text: String,
        anchorRect: CGRect,
        imageSize: NSSize,
        backgroundColor: NSColor
    ) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor(calibratedWhite: 0.08, alpha: 0.98)
        ]
        let nsText = NSString(string: text)
        let textSize = nsText.size(withAttributes: attributes)
        let tagPaddingX: CGFloat = 5
        let tagHeight: CGFloat = max(16, textSize.height + 2)
        let tagWidth: CGFloat = min(imageSize.width - 8, textSize.width + tagPaddingX * 2)

        let proposedY = anchorRect.maxY + 3
        let y = min(proposedY, imageSize.height - tagHeight - 4)
        let x = min(max(4, anchorRect.minX), imageSize.width - tagWidth - 4)
        let tagRect = NSRect(x: x, y: y, width: tagWidth, height: tagHeight)

        let tagPath = NSBezierPath(roundedRect: tagRect, xRadius: 4, yRadius: 4)
        backgroundColor.setFill()
        tagPath.fill()

        let textRect = NSRect(
            x: tagRect.minX + tagPaddingX,
            y: tagRect.minY + (tagRect.height - textSize.height) / 2 - 0.5,
            width: tagRect.width - tagPaddingX * 2,
            height: textSize.height + 1
        )
        nsText.draw(in: textRect, withAttributes: attributes)
    }

    private func drawCursorMarker(at point: CGPoint, imageSize: NSSize) {
        let outerRadius: CGFloat = 18
        let innerRadius: CGFloat = 5
        let crosshair: CGFloat = 34

        let horizontal = NSBezierPath()
        horizontal.move(to: NSPoint(x: point.x - crosshair, y: point.y))
        horizontal.line(to: NSPoint(x: point.x + crosshair, y: point.y))
        NSColor(calibratedRed: 1.0, green: 0.36, blue: 0.22, alpha: 0.86).setStroke()
        horizontal.lineWidth = 1.6
        horizontal.stroke()

        let vertical = NSBezierPath()
        vertical.move(to: NSPoint(x: point.x, y: point.y - crosshair))
        vertical.line(to: NSPoint(x: point.x, y: point.y + crosshair))
        NSColor(calibratedRed: 1.0, green: 0.36, blue: 0.22, alpha: 0.86).setStroke()
        vertical.lineWidth = 1.6
        vertical.stroke()

        let halo = NSBezierPath(
            ovalIn: NSRect(
                x: point.x - outerRadius,
                y: point.y - outerRadius,
                width: outerRadius * 2,
                height: outerRadius * 2
            )
        )
        NSColor(calibratedRed: 1.0, green: 0.22, blue: 0.18, alpha: 0.18).setFill()
        halo.fill()

        let ring = NSBezierPath(
            ovalIn: NSRect(
                x: point.x - outerRadius,
                y: point.y - outerRadius,
                width: outerRadius * 2,
                height: outerRadius * 2
            )
        )
        NSColor(calibratedRed: 1.0, green: 0.24, blue: 0.18, alpha: 0.98).setStroke()
        ring.lineWidth = 3.0
        ring.stroke()

        let core = NSBezierPath(
            ovalIn: NSRect(
                x: point.x - innerRadius,
                y: point.y - innerRadius,
                width: innerRadius * 2,
                height: innerRadius * 2
            )
        )
        NSColor(calibratedRed: 1.0, green: 0.24, blue: 0.18, alpha: 1.0).setFill()
        core.fill()

        drawCursorLabel(anchor: point, imageSize: imageSize)
    }

    private func drawCursorLabel(anchor: CGPoint, imageSize: NSSize) {
        let labelText = "CURSOR"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 11),
            .foregroundColor: NSColor.white
        ]

        let text = NSString(string: labelText)
        let textSize = text.size(withAttributes: attributes)
        let paddingX: CGFloat = 6
        let paddingY: CGFloat = 3
        let tagWidth = textSize.width + paddingX * 2
        let tagHeight = textSize.height + paddingY * 2

        let rawX = anchor.x + 12
        let rawY = anchor.y + 14
        let x = min(max(4, rawX), imageSize.width - tagWidth - 4)
        let y = min(max(4, rawY), imageSize.height - tagHeight - 4)
        let rect = NSRect(x: x, y: y, width: tagWidth, height: tagHeight)

        NSColor(calibratedRed: 0.12, green: 0.12, blue: 0.12, alpha: 0.92).setFill()
        NSBezierPath(roundedRect: rect, xRadius: 5, yRadius: 5).fill()
        NSColor(calibratedRed: 1.0, green: 0.24, blue: 0.18, alpha: 0.98).setStroke()
        let border = NSBezierPath(roundedRect: rect, xRadius: 5, yRadius: 5)
        border.lineWidth = 1.4
        border.stroke()

        text.draw(
            in: NSRect(
                x: rect.minX + paddingX,
                y: rect.minY + paddingY - 0.5,
                width: textSize.width,
                height: textSize.height
            ),
            withAttributes: attributes
        )
    }

    private func drawOverlayLegend(imageSize: NSSize, totalCount: Int) {
        let panelWidth: CGFloat = 280
        let panelHeight: CGFloat = 66
        let panelRect = NSRect(
            x: 12,
            y: max(10, imageSize.height - panelHeight - 12),
            width: min(panelWidth, imageSize.width - 20),
            height: panelHeight
        )

        NSColor(calibratedWhite: 0.08, alpha: 0.78).setFill()
        NSBezierPath(roundedRect: panelRect, xRadius: 7, yRadius: 7).fill()

        let title = "UI Tree Labels"
        title.draw(
            at: NSPoint(x: panelRect.minX + 10, y: panelRect.maxY - 21),
            withAttributes: [
                .font: NSFont.boldSystemFont(ofSize: 12),
                .foregroundColor: NSColor.white
            ]
        )

        let detail = "elements: \(totalCount)"
        detail.draw(
            at: NSPoint(x: panelRect.minX + 10, y: panelRect.minY + 8),
            withAttributes: [
                .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular),
                .foregroundColor: NSColor(calibratedWhite: 0.94, alpha: 0.95)
            ]
        )
    }

}
