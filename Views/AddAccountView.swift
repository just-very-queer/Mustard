//
//  AddAccountView.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 26/04/25.
//

import SwiftUI
import SwiftData

struct AddAccountView: View {
    @EnvironmentObject var viewModel: AccountsViewModel
    @EnvironmentObject var authViewModel: AuthenticationViewModel
    @EnvironmentObject var timelineViewModel: TimelineViewModel
    @Environment(\.presentationMode) var presentationMode

    @State private var instanceURL: String = ""
    // Removed username and password fields
    @State private var isLoading: Bool = false
    @State private var error: AppError? = nil

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Instance URL Input
                TextField("Enter Mastodon Instance URL (e.g., https://mastodon.social)", text: $instanceURL)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                    .padding()

                // Loading Indicator
                if isLoading {
                    ProgressView("Adding Account...")
                        .padding()
                }

                Spacer()
            }
            .navigationTitle("Add Account")
            .toolbar {
                // Cancel Button
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                // Add Button
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        addAccount()
                    }
                    .disabled(
                        instanceURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                        isLoading
                    )
                }
            }
            .alert(item: $error) { error in
                Alert(
                    title: Text("Error"),
                    message: Text(error.message),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }

    /// Handles the account addition process.
    private func addAccount() {
        // Validate Instance URL
        guard let url = URL(string: instanceURL.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            error = AppError(message: "Please enter a valid URL.")
            return
        }

        // Indicate Loading State
        isLoading = true
        error = nil

        // Create Server object
        let server = Server(name: url.host ?? "Unknown", url: url, description: "Mastodon Instance")

        // Perform Authentication Asynchronously
        Task {
            do {
                try await authViewModel.authenticate(with: server)
                
                // Clear the timeline
                timelineViewModel.posts = []

                // Reset Loading State and Dismiss View
                isLoading = false
                presentationMode.wrappedValue.dismiss()
            } catch {
                // Handle Errors
                isLoading = false
                self.error = AppError(message: "Failed to add account: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Preview
struct AddAccountView_Previews: PreviewProvider {
    static var previews: some View {
        // Initialize Mock Service for Preview
        let mockService = MockMastodonService(shouldSucceed: true)
        
        // Initialize Model Container with Required Models
        let container: ModelContainer
        do {
            container = try ModelContainer(for: Account.self, MediaAttachment.self, Post.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }

        let modelContext = container.mainContext

        // Initialize ViewModels with Mock Service and Context
        let accountsViewModel = AccountsViewModel(mastodonService: mockService, modelContext: modelContext)
        let authViewModel = AuthenticationViewModel(mastodonService: mockService)
        let timelineViewModel = TimelineViewModel(mastodonService: mockService)

        // Populate ViewModels with Mock Data
        accountsViewModel.accounts = mockService.mockAccounts
        accountsViewModel.selectedAccount = mockService.mockAccounts.first
        timelineViewModel.posts = mockService.mockPosts

        return NavigationView {
            AddAccountView()
                .environmentObject(accountsViewModel)
                .environmentObject(authViewModel)
                .environmentObject(timelineViewModel)
        }
        .modelContainer(container)
    }
}

