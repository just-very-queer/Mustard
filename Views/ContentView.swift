//
//  ContentView.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 30/12/24.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @EnvironmentObject var authViewModel: AuthenticationViewModel
    @EnvironmentObject var timelineViewModel: TimelineViewModel
    @EnvironmentObject var accountsViewModel: AccountsViewModel

    var body: some View {
        Group {
            if authViewModel.isAuthenticated {
                TabView {
                    // Home Tab
                    NavigationStack {
                        TimelineView()
                            .environmentObject(authViewModel)
                            .environmentObject(timelineViewModel)
                            // Removed .modelContainer(accountsViewModel.modelContainer)
                    }
                    .tabItem {
                        Label("Home", systemImage: "house")
                    }

                    // Accounts Management Tab
                    NavigationStack {
                        AccountsView()
                            .environmentObject(accountsViewModel)
                            .environmentObject(authViewModel)
                            .environmentObject(timelineViewModel)
                    }
                    .tabItem {
                        Label("Accounts", systemImage: "person.2")
                    }
                }
                .onOpenURL { url in
                    NotificationCenter.default.post(
                        name: .didReceiveOAuthCallback,
                        object: nil,
                        userInfo: ["url": url]
                    )
                }
                .alert(item: $timelineViewModel.alertError) { error in
                    Alert(
                        title: Text("Error"),
                        message: Text(error.message),
                        dismissButton: .default(Text("OK"))
                    )
                }
            } else {
                NavigationStack {
                    AuthenticationView()
                        .environmentObject(authViewModel)
                        .environmentObject(accountsViewModel)
                        .navigationTitle("Sign In")
                }
                .onOpenURL { url in
                    NotificationCenter.default.post(
                        name: .didReceiveOAuthCallback,
                        object: nil,
                        userInfo: ["url": url]
                    )
                }
                .alert(item: $authViewModel.alertError) { error in
                    Alert(
                        title: Text("Authentication Error"),
                        message: Text(error.message),
                        dismissButton: .default(Text("OK"))
                    )
                }
            }
        }
        .onAppear {
            Task {
                await authViewModel.validateAuthentication()
            }
        }
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
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

        return ContentView()
            .environmentObject(authViewModel)
            .environmentObject(timelineViewModel)
            .environmentObject(accountsViewModel)
            .modelContainer(container)
    }
}

