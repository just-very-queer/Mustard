// ContentView.swift
// Mustard
//
// Created by VAIBHAV SRIVASTAVA on 14/09/24.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authViewModel: AuthenticationViewModel
    @EnvironmentObject var timelineViewModel: TimelineViewModel
    @State private var showingServerList = false

    var body: some View {
        NavigationView {
            if authViewModel.isAuthenticated {
                TimelineView()
                    .environmentObject(timelineViewModel)
                    .navigationTitle("Home")
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Logout") {
                                authViewModel.logout()
                            }
                        }
                    }
            } else {
                VStack {
                    Text("Welcome to Mustard")
                        .font(.largeTitle)
                        .padding()

                    Button("Select Server") {
                        showingServerList = true
                    }
                    .padding()
                }
                .sheet(isPresented: $showingServerList) {
                    ServerListView(servers: sampleServers) { selectedServer in
                        authViewModel.instanceURL = selectedServer.url
                        Task {
                            await authViewModel.authenticate()
                        }
                        showingServerList = false
                    }
                }
                .alert(item: $authViewModel.alertError) { error in
                    Alert(title: Text("Error"), message: Text(error.message), dismissButton: .default(Text("OK")))
                }
            }
        }
    }

    // Sample servers for demonstration
    private var sampleServers: [Server] {
        [
            Server(name: "Mastodon Social", url: URL(string: "https://mastodon.social")!, description: "Official Mastodon instance."),
            Server(name: "Mastodon Cloud", url: URL(string: "https://mastodon.cloud")!, description: "Cloud-hosted Mastodon instance."),
            // Add more servers as needed
        ]
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(AuthenticationViewModel(mastodonService: MastodonService()))
            .environmentObject(TimelineViewModel(mastodonService: MastodonService()))
    }
}

