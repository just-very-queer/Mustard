//
//  ContentView.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 14/09/24.
//

import SwiftUI

struct ContentView: View {
    // Use the shared environment objects from MustardApp
    @EnvironmentObject var authViewModel: AuthenticationViewModel
    @EnvironmentObject var timelineViewModel: TimelineViewModel
    
    @State private var showingServerList = false

    var body: some View {
        NavigationView {
            if authViewModel.isAuthenticated {
                // Already authenticated, show timeline
                TimelineView()
                    .navigationTitle("Home")
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Logout") {
                                authViewModel.logout()
                                // Clear timeline, etc., if desired
                                timelineViewModel.posts.removeAll()
                            }
                        }
                    }
                    .onAppear {
                        // Make sure TimelineViewModel has the same instanceURL
                        timelineViewModel.instanceURL = authViewModel.instanceURL
                        
                        Task {
                            await timelineViewModel.loadTimeline()
                        }
                    }
            } else {
                // Not authenticated, show "Welcome" screen
                VStack(spacing: 20) {
                    Text("Welcome to Mustard")
                        .font(.largeTitle)
                        .padding()

                    Button(action: {
                        showingServerList = true
                    }) {
                        Text("Select Server")
                            .font(.headline)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
                .sheet(isPresented: $showingServerList) {
                    ServerListView(
                        servers: SampleServers.servers,
                        onSelect: { selectedServer in
                            // IMPORTANT: set instanceURL for auth (and maybe timeline)
                            authViewModel.instanceURL = selectedServer.url
                            timelineViewModel.instanceURL = selectedServer.url
                            
                            Task {
                                await authViewModel.authenticate()
                            }
                            showingServerList = false
                        },
                        onCancel: {
                            showingServerList = false
                        }
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

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        // For preview, we can set up mock view models
        let mockService = MastodonService()
        let authVM = AuthenticationViewModel(mastodonService: mockService)
        let timelineVM = TimelineViewModel(mastodonService: mockService)
        
        return ContentView()
            .environmentObject(authVM)
            .environmentObject(timelineVM)
    }
}

