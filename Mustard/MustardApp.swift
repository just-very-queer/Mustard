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

    init() {
        // 1) Initialize the ModelContainer with your @Model types
        do {
            container = try ModelContainer(for: Account.self, MediaAttachment.self, Post.self)
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error)")
        }

        // 2) Initialize the MastodonService (or real service)
        let mastodonService = MastodonService()

        // 3) Create local instances of the view models
        let localAuthVM = AuthenticationViewModel(mastodonService: mastodonService)
        let localTimelineVM = TimelineViewModel(mastodonService: mastodonService)
        // -- Provide the container's mainContext to AccountsViewModel
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
            if authViewModel.isAuthenticated {
                // Show the main app (Tabs)
                TabView {
                    // Home Tab
                    NavigationStack {
                        TimelineView()
                            .environmentObject(authViewModel)
                            .environmentObject(timelineViewModel)
                            // Attach model container for SwiftData usage
                            .modelContainer(container)
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
                    // Post a notification to handle OAuth callback
                    NotificationCenter.default.post(
                        name: .didReceiveOAuthCallback,
                        object: nil,
                        userInfo: ["url": url]
                    )
                }
                // Show timeline errors in an alert
                .alert(item: $timelineViewModel.alertError) { error in
                    Alert(
                        title: Text("Error"),
                        message: Text(error.message),
                        dismissButton: .default(Text("OK"))
                    )
                }
            } else {
                // Show the Authentication flow if not authenticated
                NavigationStack {
                    AuthenticationView()
                        .environmentObject(authViewModel)
                        .environmentObject(timelineViewModel)
                        .environmentObject(accountsViewModel)
                        // SwiftData container for SwiftData usage
                        .modelContainer(container)
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
                        title: Text("Error"),
                        message: Text(error.message),
                        dismissButton: .default(Text("OK"))
                    )
                }
            }
        }
    }
}

/// Minimal AppDelegate, mostly for handling any universal links or OAuth callbacks.
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey : Any] = [:]
    ) -> Bool {
        // Notify the AuthenticationViewModel (or other) about the received URL.
        NotificationCenter.default.post(
            name: .didReceiveOAuthCallback,
            object: nil,
            userInfo: ["url": url]
        )
        return true
    }
}
