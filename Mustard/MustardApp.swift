//
//  MustardApp.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 14/09/24.
//

import SwiftUI
import SwiftData

@main
struct MustardApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // MARK: - ViewModels
    @StateObject private var authViewModel: AuthenticationViewModel
    @StateObject private var timelineViewModel: TimelineViewModel
    @StateObject private var accountsViewModel: AccountsViewModel

    // MARK: - SwiftData container
    let container: ModelContainer

    // MARK: - Singleton MastodonService Instance
    let mastodonService = MastodonService.shared // Use the shared instance

    // MARK: - Sample Servers (Use your actual server list)
    let servers: [Server] = SampleServers.servers

    init() {
        // 1) Initialize the ModelContainer with your @Model types
        do {
            container = try ModelContainer(for: Account.self, MediaAttachment.self, Post.self)
            print("[MustardApp] ModelContainer initialized successfully.")
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error)")
        }

        // 2) Remove manual Keychain retrieval and setting of baseURL
        // MastodonService.shared handles loading credentials internally

        // 3) Create local instances of the view models with the shared MastodonService
        let localAuthVM = AuthenticationViewModel(mastodonService: mastodonService)
        let localTimelineVM = TimelineViewModel(mastodonService: mastodonService)
        let localAccountsVM = AccountsViewModel(
            mastodonService: mastodonService,
            modelContext: container.mainContext
        )

        // 4) Wrap them in StateObjects
        _authViewModel = StateObject(wrappedValue: localAuthVM)
        _timelineViewModel = StateObject(wrappedValue: localTimelineVM)
        _accountsViewModel = StateObject(wrappedValue: localAccountsVM)
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if authViewModel.isAuthenticated {
                    // Main App with Tabs
                    TabView {
                        // Home Tab
                        NavigationStack {
                            TimelineView()
                                .environmentObject(authViewModel)
                                .environmentObject(timelineViewModel)
                                .environmentObject(accountsViewModel)
                                .modelContainer(container)
                        }
                        .tabItem {
                            Label("Home", systemImage: "house")
                        }

                        // Accounts Management Tab (Retained for future use)
                        NavigationStack {
                            AccountsView()
                                .environmentObject(accountsViewModel)
                                .environmentObject(authViewModel)
                                .environmentObject(timelineViewModel)
                                .modelContainer(container)
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
                        print("[MustardApp] Received URL via onOpenURL: \(url.absoluteString)")
                    }
                    .alert(item: $timelineViewModel.alertError) { error in
                        Alert(
                            title: Text("Error"),
                            message: Text(error.message),
                            dismissButton: .default(Text("OK"))
                        )
                    }
                } else {
                    // Authentication Flow: Authentication View
                    AuthenticationView()
                        .environmentObject(authViewModel)
                        .environmentObject(timelineViewModel)
                        .environmentObject(accountsViewModel)
                        .modelContainer(container)
                        .navigationTitle("Authentication")
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
                print("[MustardApp] App appeared. Validating authentication.")
            }
        }
    }
}

/// AppDelegate class to handle application-level events, such as OAuth callbacks.
class AppDelegate: NSObject, UIApplicationDelegate {
    /// Handles incoming URLs (e.g., OAuth callback URLs).
    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey : Any] = [:]
    ) -> Bool {
        print("Received OAuth callback URL: \(url.absoluteString)")
        // Notify about received URL for OAuth callback
        NotificationCenter.default.post(
            name: .didReceiveOAuthCallback,
            object: nil,
            userInfo: ["url": url]
        )
        return true
    }
}

