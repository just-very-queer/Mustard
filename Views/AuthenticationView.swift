//
//  AuthenticationView.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 30/12/24.
//

import SwiftUI
import OSLog // Import for logging

struct AuthenticationView: View {
    @EnvironmentObject var authViewModel: AuthenticationViewModel
    @State private var showingServerList = false
    @State private var isAuthenticating = false

    // Use a logger instance
    private let logger = Logger(subsystem: "com.yourcompany.Mustard", category: "Authentication")

    var body: some View {
        VStack(spacing: 20) {
            Text("Welcome to Mustard")
                .font(.largeTitle)
                .bold()

            Text("Sign in to your preferred Mastodon instance.")
                .multilineTextAlignment(.center)
                .padding()

            Button(action: {
                showingServerList = true
            }) {
                HStack {
                    Text("Select a Mastodon Instance")
                        .foregroundColor(.blue)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .foregroundColor(.gray)
                }
                .padding()
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray, lineWidth: 1)
                )
            }
            .disabled(isAuthenticating)

            .sheet(isPresented: $showingServerList) {
                ServerListView(
                    servers: SampleServers.servers,
                    onSelect: { server in
                        logger.info("Server selected: \(server.url, privacy: .public)")
                        showingServerList = false
                        isAuthenticating = true
                        Task {
                            do {
                                // Delegate authentication to the ViewModel
                                try await authViewModel.authenticate(to: server)
                            } catch {
                                // Handle any unexpected errors (optional)
                                logger.error("Unexpected error during authentication: \(error.localizedDescription)")
                                // Optionally, set alertError here if not already handled in ViewModel
                            }
                            isAuthenticating = false
                        }
                    },
                    onCancel: {
                        showingServerList = false
                    }
                )
            }

            Spacer()

            if isAuthenticating {
                ProgressView("Authenticating...")
                    .padding()
            }
        }
        .padding()
        .alert(item: $authViewModel.alertError) { error in // Improved error handling
            Alert(
                title: Text("Authentication Error"),
                message: Text(error.message), // Use error.message instead of localizedDescription
                dismissButton: .default(Text("OK"))
            )
        }
    }
}

// MARK: - Preview
struct AuthenticationView_Previews: PreviewProvider {
    static var previews: some View {
        let mockService = MockMastodonService(shouldSucceed: true)
        let authViewModel = AuthenticationViewModel(mastodonService: mockService)

        return AuthenticationView()
            .environmentObject(authViewModel)
    }
}
