//
//  ContentView.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 14/09/24.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authViewModel: AuthenticationViewModel
    @EnvironmentObject var timelineViewModel: TimelineViewModel

    var body: some View {
        Group {
            if authViewModel.isAuthenticated {
                // Timeline View is now directly managed by the TabView in MustardApp.swift
                TimelineView()
            } else {
                // Authentication View
                NavigationStack {
                    AuthenticationView()
                        .navigationTitle("Sign In")
                }
            }
        }
        .alert(item: $authViewModel.alertError) { (error: AppError) in
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
        // Initialize PreviewService
        let previewService = PreviewService()

        // Initialize AuthenticationViewModel with PreviewService
        let authViewModel = AuthenticationViewModel(mastodonService: previewService)

        // Simulate unauthenticated state
        authViewModel.isAuthenticated = false
        authViewModel.instanceURL = previewService.baseURL

        return AuthenticationView()
            .environmentObject(authViewModel)
    }
}

