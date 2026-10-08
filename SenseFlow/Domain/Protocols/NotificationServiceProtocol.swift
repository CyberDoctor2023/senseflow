import Foundation

/// Sends tool progress, completion, and failure notifications.
/// Authorization and presentation are owned by the platform adapter.
protocol NotificationServiceProtocol: Sendable {
    /// Reports that tool processing has started.
    func showInProgress(title: String, body: String)

    /// Reports successful completion.
    func showSuccess(title: String, body: String)

    /// Reports a failure the user can act on.
    func showError(title: String, body: String)
}
