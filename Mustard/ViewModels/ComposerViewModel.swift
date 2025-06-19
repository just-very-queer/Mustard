// Mustard/ViewModels/ComposerViewModel.swift
import SwiftUI
import Combine // Required for ObservableObject and @Published

@MainActor // Ensures that @Published properties are updated on the main thread
final class ComposerViewModel: ObservableObject {
    @Published var text: AttributedString = ""
    @Published var isPosting = false
    // Optional: To publish errors to the view
    // @Published var errorMessage: String?

    private let processor = ComposerTextProcessor()

    // It's important to correctly access the MastodonAPIService.
    // Assuming it's a singleton accessible via .shared, as is common.
    // If it's normally injected via EnvironmentObject or initializer,
    // this might need adjustment when integrated.
    private let mastodonAPIService: MastodonAPIServiceProtocol

    // Initializer allowing for dependency injection, useful for previews and tests
    init(mastodonAPIService: MastodonAPIServiceProtocol = MastodonAPIService.shared) {
        self.mastodonAPIService = mastodonAPIService

        // Initialize with a default font if text is empty,
        // because processText() applies font only after first edit.
        if text.characters.isEmpty {
            var initialText = AttributedString("")
            initialText.swiftUI.font = .body
            self.text = initialText
        }
    }

    func processText() {
        // This check can prevent processing if the view calls it excessively
        // though onChange in View should be the primary guard.
        // Guard !isPosting else { return }
        processor.process(text: &text)
    }

    func postStatus() async {
        guard !isPosting else { return }
        guard !text.characters.isEmpty else { return } // Don't post empty content

        isPosting = true
        // self.errorMessage = nil // Clear previous errors

        let content = String(text.characters) // Extract plain text for the API

        do {
            // Updated to include inReplyToId: nil to match the protocol
            _ = try await mastodonAPIService.postStatus(status: content, visibility: .public, inReplyToId: nil)
            // Consider success feedback, e.g., a notification or event
            // Or perhaps the view handles dismissal and timeline refresh directly
        } catch {
            // Handle error, maybe show an alert to the user
            print("Error posting status: \(error)")
            // self.errorMessage = "Failed to post: \(error.localizedDescription)"
        }

        isPosting = false
    }
}

// Note: Added MastodonAPIServiceProtocol for better testability and injection.
// The actual MastodonAPIService.swift should conform to this protocol.
// If MastodonAPIService.shared doesn't exist or uses a different pattern,
// this will need to be adjusted during integration or by checking MastodonAPIService.swift.
// Also added a default visibility parameter to postStatus, assuming it's needed.
// If not, it can be removed.
