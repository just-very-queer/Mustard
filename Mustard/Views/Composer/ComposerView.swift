// Mustard/Views/Composer/ComposerView.swift
import SwiftUI

struct ComposerView: View {
    @Environment(\.dismiss) private var dismiss

    // Use @StateObject to create and manage the lifecycle of ComposerViewModel
    // within this view's scope.
    @StateObject private var viewModel: ComposerViewModel

    // Initializer to allow injecting the ViewModel, especially useful for previews
    // or if the ViewModel needs specific setup from the parent.
    // If MastodonAPIService.shared is reliable, this could be simplified
    // to @StateObject private var viewModel = ComposerViewModel() directly.
    init(viewModel: ComposerViewModel = ComposerViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        // Using NavigationView to provide a navigation bar for title and buttons.
        // This is typical for modal sheets.
        NavigationView {
            VStack(spacing: 0) { // Use spacing: 0 if no default spacing is desired
                TextEditor(text: $viewModel.text)
                    // Apply the custom formatting definition to enable live styling.
                    .attributedTextFormattingDefinition(ComposerFormattingDefinition())
                    .padding(.horizontal) // Standard padding for text editors
                    .padding(.top)
                    .frame(maxHeight: .infinity) // Allow TextEditor to expand
                    .onChange(of: viewModel.text) { oldValue, newValue in
                        // Call processText whenever the attributed string changes.
                        // The "rebuild-on-keystroke" logic happens here.
                        viewModel.processText()
                    }

                Spacer() // Pushes TextEditor to the top
            }
            .navigationTitle("New Post")
            .navigationBarTitleDisplayMode(.inline) // Common style for modal views
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss() // Dismiss the sheet
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Post") {
                        Task { // Perform async operation
                            await viewModel.postStatus()
                            // Assuming successful post, dismiss the view.
                            // Error handling (e.g., alerts) would be inside viewModel.postStatus
                            // or could be triggered here based on a result from postStatus.
                            if !viewModel.isPosting { // Only dismiss if not still posting (e.g. error occurred but didn't block)
                                dismiss()
                            }
                        }
                    }
                    // Disable button if posting is in progress or if text is empty.
                    .disabled(viewModel.isPosting || viewModel.text.characters.isEmpty)
                }
            }
            .overlay { // Overlay for progress indicator
                if viewModel.isPosting {
                    // Simple progress view; could be customized.
                    ProgressView("Posting...")
                        .padding()
                        .background(Material.regular) // Use Material for a blurred background effect
                        .cornerRadius(8)
                        .shadow(radius: 5)
                }
            }
            // .alert if you want to show alerts from the ViewModel
            // .alert("Error", isPresented: Binding(get: { viewModel.errorMessage != nil }, set: { _ in viewModel.errorMessage = nil })) {
            //     Button("OK", role: .cancel) { }
            // } message: {
            //     Text(viewModel.errorMessage ?? "An unknown error occurred.")
            // }
        }
    }
}

// Preview provider for ComposerView
struct ComposerView_Previews: PreviewProvider {
    static var previews: some View {
        // Example of injecting a specific service for preview if needed
        // let previewApiService = PreviewMastodonAPIService()
        // ComposerView(viewModel: ComposerViewModel(mastodonAPIService: previewApiService))

        ComposerView(viewModel: ComposerViewModel())
    }
}

// If you want to use a preview-specific API service for testing:
// struct PreviewMastodonAPIService: MastodonAPIServiceProtocol {
// func postStatus(status: String, visibility: PostVisibility) async throws -> Post {
// print("Preview API: Posting status - \(status)")
// try await Task.sleep(nanoseconds: 1_000_000_000) // Simulate network delay
// return Post.sample // Assuming you have a Post.sample for previews
// }
// // Implement other protocol methods if necessary for more complex previews
// }
