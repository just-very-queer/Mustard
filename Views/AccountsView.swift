//
//  AccountsView.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 26/04/25.
//

import SwiftUI

struct AccountsView: View {
    @EnvironmentObject var viewModel: AccountsViewModel
    @EnvironmentObject var authViewModel: AuthenticationViewModel
    @EnvironmentObject var timelineViewModel: TimelineViewModel
    
    @State private var showingAddAccountSheet = false
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.accounts) { account in
                    // Determine if the current account is selected
                    let isSelected = isAccountSelected(account)
                    
                    // Render the AccountRowView with the determined selection state
                    AccountRowView(account: account, isSelected: isSelected)
                        .onTapGesture {
                            handleAccountSelection(account)
                        }
                }
                .onDelete(perform: viewModel.deleteAccounts)
            }
            .listStyle(PlainListStyle())
            .navigationTitle("Accounts")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddAccountSheet = true
                    }) {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add Account")
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
            }
            .sheet(isPresented: $showingAddAccountSheet) {
                AddAccountView()
                    .environmentObject(viewModel)
                    .environmentObject(authViewModel)
            }
            .alert(item: $viewModel.errorMessage) { error in
                Alert(
                    title: Text("Error"),
                    message: Text(error.message),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// Determines if the given account is the currently selected account.
    /// - Parameter account: The account to check.
    /// - Returns: A Boolean indicating whether the account is selected.
    private func isAccountSelected(_ account: Account) -> Bool {
        guard let selectedAccount = viewModel.selectedAccount else {
            return false
        }
        return selectedAccount.id == account.id
    }
    
    /// Handles the selection of an account.
    /// - Parameter account: The account that was selected.
    private func handleAccountSelection(_ account: Account) {
        viewModel.selectAccount(account)
        if let instanceURL = account.instanceURL {
            authViewModel.instanceURL = instanceURL // Assign URL directly
            print("AccountsView: Instance URL set to: \(instanceURL)")
        } else {
            authViewModel.alertError = AppError(message: "Selected account has an invalid instance URL.")
            print("AccountsView: Selected account has an invalid instance URL.")
            return
        }
        timelineViewModel.posts = []
        Task {
            await timelineViewModel.fetchTimeline()
        }
    }

}

struct AccountRowView: View {
    let account: Account
    let isSelected: Bool

    var body: some View {
        HStack {
            AsyncImage(url: account.avatar) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .frame(width: 50, height: 50)
                case .success(let image):
                    image.resizable()
                        .scaledToFill()
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())
                case .failure:
                    Image(systemName: "person.crop.circle.badge.exclamationmark")
                        .resizable()
                        .frame(width: 50, height: 50)
                        .foregroundColor(.gray)
                @unknown default:
                    EmptyView()
                }
            }
            .accessibilityLabel("\(account.displayName)'s avatar")

            VStack(alignment: .leading) {
                Text(account.displayName)
                    .font(.headline)
                Text("@\(account.acct)")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
            }
        }
        .contentShape(Rectangle())
    }
}

struct AccountsView_Previews: PreviewProvider {
    static var previews: some View {
        // Initialize MockMastodonService
        let mockService = MockMastodonService()
        
        // Initialize ViewModels with the mock service
        let authViewModel = AuthenticationViewModel(mastodonService: mockService)
        let timelineViewModel = TimelineViewModel(mastodonService: mockService)
        let accountsViewModel = AccountsViewModel(mastodonService: mockService)
        
        // Create sample accounts
        let sampleAccount1 = Account(
            id: "a1",
            username: "user1",
            displayName: "User One",
            avatar: URL(string: "https://example.com/avatar1.png")!,
            acct: "user1",
            instanceURL: URL(string: "https://mastodon.social")!,
            accessToken: "testToken1"
        )
        
        let sampleAccount2 = Account(
            id: "a2",
            username: "user2",
            displayName: "User Two",
            avatar: URL(string: "https://example.com/avatar2.png")!,
            acct: "user2",
            instanceURL: URL(string: "https://mastodon.social")!,
            accessToken: "testToken2"
        )
        
        // Assign sample accounts to the view model
        accountsViewModel.accounts = [sampleAccount1, sampleAccount2]
        accountsViewModel.selectedAccount = sampleAccount1
        
        // Simulate authenticated state
        authViewModel.isAuthenticated = true
        authViewModel.instanceURL = mockService.baseURL
        
        return NavigationStack {
            AccountsView()
                .environmentObject(accountsViewModel)
                .environmentObject(authViewModel)
                .environmentObject(timelineViewModel)
        }
    }
}

