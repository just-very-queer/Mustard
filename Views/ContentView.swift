//
//  ContentView.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 14/09/24.
//

import SwiftUI
import Foundation

struct ContentView: View {
    @EnvironmentObject var authViewModel: AuthenticationViewModel
    @EnvironmentObject var timelineViewModel: TimelineViewModel

    // Removed the redundant @State property for selectedFilter
    // @State private var selectedFilter: TimelineViewModel.TimeFilter = .day

    var body: some View {
        TabView {
            NavigationStack {
                if authViewModel.isAuthenticated {
                    // Home Feed with Filters
                    VStack {
                        // Filter Picker bound directly to TimelineViewModel's selectedFilter
                        Picker("Filter", selection: $timelineViewModel.selectedFilter) {
                            ForEach(TimelineViewModel.TimeFilter.allCases) { filter in
                                Text(filter.rawValue).tag(filter)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding()

                        // Timeline View without passing selectedFilter as a parameter
                        TimelineView()
                    }
                    .navigationTitle("Home")
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button(action: {
                                Task {
                                    await timelineViewModel.fetchTimeline()
                                }
                            }) {
                                Image(systemName: "arrow.clockwise")
                            }
                            .accessibilityLabel("Refresh Timeline")
                        }
                    }
                } else {
                    // Show the authentication screen
                    AuthenticationView()
                }
            }
            .tabItem {
                Label("Home", systemImage: "house")
            }

            // Accounts Management Tab
            NavigationStack {
                AccountsView()
            }
            .tabItem {
                Label("Accounts", systemImage: "person.2")
            }
        }
        .onAppear {
            // Fetch timeline if authenticated
            if authViewModel.isAuthenticated {
                Task {
                    await timelineViewModel.fetchTimeline()
                }
            }
        }
        // Specify the type for the alert error so Swift can infer
        .alert(item: $timelineViewModel.alertError) { (error: AppError) in
            Alert(
                title: Text("Error"),
                message: Text(error.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        // Initialize PreviewService with default mock posts
        let previewService = PreviewService()
        let authViewModel = AuthenticationViewModel(mastodonService: previewService)
        let timelineViewModel = TimelineViewModel(mastodonService: previewService)
        let accountsViewModel = AccountsViewModel(mastodonService: previewService)

        // Create a sample account
        let sampleAccount = Account(
            id: "a1",
            username: "user1",
            displayName: "User One",
            avatar: URL(string: "https://example.com/avatar1.png")!,
            acct: "user1",
            instanceURL: URL(string: "https://mastodon.social")!,
            accessToken: "testToken"
        )
        accountsViewModel.accounts = [sampleAccount]
        accountsViewModel.selectedAccount = sampleAccount

        // Simulate authenticated state
        authViewModel.isAuthenticated = true
        authViewModel.instanceURL = previewService.baseURL

        return ContentView()
            .environmentObject(authViewModel)
            .environmentObject(timelineViewModel)
            .environmentObject(accountsViewModel)
    }
}

