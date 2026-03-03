//
//  SystemContextSignalProviders.swift
//  SenseFlow
//

import AppKit

extension SystemContextCollector {
    struct FrontmostApplicationSnapshot {
        let applicationName: String
        let bundleID: String
    }

    protocol FrontmostApplicationResolving: Sendable {
        func resolve() throws -> FrontmostApplicationSnapshot
    }

    final class DefaultFrontmostApplicationResolver: FrontmostApplicationResolving, @unchecked Sendable {
        func resolve() throws -> FrontmostApplicationSnapshot {
            guard let frontApp = NSWorkspace.shared.frontmostApplication else {
                throw ContextError.noActiveApplication
            }

            return FrontmostApplicationSnapshot(
                applicationName: frontApp.localizedName ?? "Unknown",
                bundleID: frontApp.bundleIdentifier ?? "unknown"
            )
        }
    }

    struct ClipboardSnapshot {
        let text: String?
        let hasImage: Bool
    }

    protocol ClipboardSnapshotCollecting: Sendable {
        func collect(from reader: any ClipboardReader) -> ClipboardSnapshot
    }

    struct DefaultClipboardSnapshotCollector: ClipboardSnapshotCollecting {
        func collect(from reader: any ClipboardReader) -> ClipboardSnapshot {
            let content = reader.readContent()
            return ClipboardSnapshot(
                text: reader.readText(),
                hasImage: !content.asImage.isNil
            )
        }
    }
}

private extension Optional {
    var isNil: Bool {
        self == nil
    }
}
