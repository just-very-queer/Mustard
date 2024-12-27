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
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                TextField("Enter Mastodon Instance URL (e.g., https://mastodon.social)", text: $instanceURL)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                    .padding()

                if isLoading {
                    ProgressView("Adding Account...")
                }

                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                }

                Spacer()
            }
            .navigationTitle("Add Account")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        addAccount()
                    }
                    .disabled(instanceURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                }
            }
        }
    }

    private func addAccount() {
        guard let url = URL(string: instanceURL.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            errorMessage = "Please enter a valid URL."
            return
        }

        isLoading = true
        errorMessage = nil

        // Here, implement the actual authentication logic.
        // For demonstration, we'll mock the successful addition after a delay.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            // Mock successful authentication and access token retrieval
            let newAccount = Account(
                id: UUID().uuidString,
                username: "newuser",
                displayName: "New User",
                avatar: URL(string: "https://example.com/avatar_new.png")!,
                acct: "newuser",
                instanceURL: url,
                accessToken: "newAccessToken123"
            )

            viewModel.accounts.append(newAccount)
            viewModel.selectedAccount = newAccount
            authViewModel.instanceURL = url
            timelineViewModel.posts = []

            isLoading = false
            presentationMode.wrappedValue.dismiss()
        }
    }
}

// MARK: - Preview
struct AddAccountView_Previews: PreviewProvider {
    static var previews: some View {
        // 1) Create a mock MastodonService (PreviewService)
        let previewService = PreviewService()
        
        // 2) Create a ModelContainer for SwiftData (with your @Model types)
        let container: ModelContainer
        do {
            container = try ModelContainer(for: Account.self, MediaAttachment.self, Post.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
        
        // 3) Obtain the modelContext
        let modelContext = container.mainContext
        
        // 4) Initialize your ViewModels with the previewService and modelContext
        let accountsViewModel = AccountsViewModel(mastodonService: previewService,
                                                  modelContext: modelContext)
        let authViewModel = AuthenticationViewModel(mastodonService: previewService)
        let timelineViewModel = TimelineViewModel(mastodonService: previewService)
        
        // 5) Optionally add some mock data
        accountsViewModel.accounts = [previewService.sampleAccount1, previewService.sampleAccount2]
        accountsViewModel.selectedAccount = previewService.sampleAccount1
        timelineViewModel.posts = previewService.mockPosts
        
        // 6) Present AddAccountView with environment objects
        return NavigationStack {
            AddAccountView()
                .environmentObject(accountsViewModel)
                .environmentObject(authViewModel)
                .environmentObject(timelineViewModel)
        }
        // 7) Attach the model container for SwiftData
        .modelContainer(container)
    }
}

