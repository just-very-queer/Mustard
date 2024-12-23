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
    
    /// Two @StateObject properties for our authentication & timeline.
    @StateObject private var authViewModel: AuthenticationViewModel
    @StateObject private var timelineViewModel: TimelineViewModel

    let container: ModelContainer

    init() {
        // 1) Initialize your ModelContainer in a local variable first.
        let localContainer: ModelContainer
        do {
            localContainer = try ModelContainer(for: Account.self, MediaAttachment.self, Post.self)
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error)")
        }
        container = localContainer

        // 2) Create the MastodonService in a local variable
        let service = MastodonService()

        // 3) Construct your view models in local variables, using that service
        let localAuthVM = AuthenticationViewModel(mastodonService: service)
        let localTimelineVM = TimelineViewModel(mastodonService: service)

        // 4) Assign them to the StateObject wrappers
        _authViewModel = StateObject(wrappedValue: localAuthVM)
        _timelineViewModel = StateObject(wrappedValue: localTimelineVM)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authViewModel)
                .environmentObject(timelineViewModel)
                .modelContainer(container)
        }
    }
}

/// Minimal AppDelegate, mostly for handling any universal links or OAuth callbacks
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey : Any] = [:]
    ) -> Bool {
        // Handle OAuth callback URLs, if any
        return true
    }
}

