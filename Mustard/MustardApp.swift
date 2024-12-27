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

    /// ViewModels for authentication, timeline, and accounts.
    @StateObject private var authViewModel: AuthenticationViewModel
    @StateObject private var timelineViewModel: TimelineViewModel
    @StateObject private var accountsViewModel: AccountsViewModel

    /// The data model container.
    let container: ModelContainer

    init() {
        // Initialize the ModelContainer
        do {
            container = try ModelContainer(for: Account.self, MediaAttachment.self, Post.self)
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error)")
        }

        // Initialize the MastodonService
        let mastodonService = MastodonService()

        // Initialize the ViewModels with dependency injection
        let localAuthVM = AuthenticationViewModel(mastodonService: mastodonService)
        let localTimelineVM = TimelineViewModel(mastodonService: mastodonService)
        let localAccountsVM = AccountsViewModel(mastodonService: mastodonService)

        // Assign to StateObject wrappers
        _authViewModel = StateObject(wrappedValue: localAuthVM)
        _timelineViewModel = StateObject(wrappedValue: localTimelineVM)
        _accountsViewModel = StateObject(wrappedValue: localAccountsVM)
    }

    var body: some Scene {
        WindowGroup {
            // Prepare for a TabView with multiple tabs
            TabView {
                // Home Tab
                NavigationStack {
                    ContentView()
                        .environmentObject(authViewModel)
                        .environmentObject(timelineViewModel)
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
                // Post a notification to handle the OAuth callback
                NotificationCenter.default.post(name: .didReceiveOAuthCallback, object: nil, userInfo: ["url": url])
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
        // Notify the AuthenticationViewModel about the received URL.
        NotificationCenter.default.post(name: .didReceiveOAuthCallback, object: nil, userInfo: ["url": url])
        return true
    }
}

