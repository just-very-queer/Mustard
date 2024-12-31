//
//  AccountsView.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 26/04/25.
//

import SwiftUI
import SwiftData

struct AccountsView: View {
    @EnvironmentObject var viewModel: AccountsViewModel
    @EnvironmentObject var authViewModel: AuthenticationViewModel
    @EnvironmentObject var timelineViewModel: TimelineViewModel

    @State private var showingAddAccountSheet = false
    @State private var isAuthenticating = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.accounts) { account in
                    let isSelected = viewModel.selectedAccount?.id == account.id
                    AccountRowView(account: account, isSelected: isSelected)
                        .contentShape(Rectangle()) // Makes entire row tappable
                        .onTapGesture {
                            viewModel.selectAccount(account)
                        }
                }
                .onDelete(perform: viewModel.deleteAccounts)
            }
            .listStyle(PlainListStyle())
            .navigationTitle("Accounts")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        initiateOAuthFlow()
                    }) {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add Account")
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
            }
            .alert(item: $viewModel.errorMessage) { error in
                Alert(
                    title: Text("Error"),
                    message: Text(error.message),
                    dismissButton: .default(Text("OK"))
                )
            }
            .overlay(
                Group {
                    if isAuthenticating {
                        Color.black.opacity(0.4)
                            .edgesIgnoringSafeArea(.all)
                        ProgressView("Authenticating...")
                            .padding()
                            .background(Color.white)
                            .cornerRadius(10)
                    }
                }
            )
            .onAppear {
                Task {
                    await viewModel.fetchAccounts()
                }
            }
        }
    }
    
    /// Initiates the OAuth authentication flow to add a new account.
    private func initiateOAuthFlow() {
        // Presenting an authentication sheet to handle OAuth
        showingAddAccountSheet = true
    }
    
    /// Handles the OAuth authentication result.
    private func handleOAuthResult() {
        // Observe for account addition via NotificationCenter
        NotificationCenter.default.addObserver(forName: .didAddAccount, object: nil, queue: .main) { _ in
            showingAddAccountSheet = false
            Task {
                await viewModel.fetchAccounts()
            }
        }
    }
}

// MARK: - AccountRowView
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
                    image
                        .resizable()
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
        .padding(.vertical, 8)
    }
}

// MARK: - Preview
struct AccountsView_Previews: PreviewProvider {
    static var previews: some View {
        let mockService = MockMastodonService()
        
        let container: ModelContainer
        do {
            container = try ModelContainer(for: Account.self, MediaAttachment.self, Post.self)
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error)")
        }
        
        let modelContext = container.mainContext
        
        let accountsViewModel = AccountsViewModel(mastodonService: mockService, modelContext: modelContext)
        let authViewModel = AuthenticationViewModel(mastodonService: mockService)
        let timelineViewModel = TimelineViewModel(mastodonService: mockService)
        
        // Pre-populate with mock accounts
        accountsViewModel.accounts = mockService.mockAccounts
        accountsViewModel.selectedAccount = mockService.mockAccounts.first
        timelineViewModel.posts = mockService.mockPosts
        
        return AccountsView()
            .environmentObject(accountsViewModel)
            .environmentObject(authViewModel)
            .environmentObject(timelineViewModel)
            .modelContainer(container)
    }
}

