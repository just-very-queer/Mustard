//
//  AuthenticationView.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on [Date].
//

import SwiftUI

struct AuthenticationView: View {
    @EnvironmentObject var authViewModel: AuthenticationViewModel
    @State private var showingServerList = false
    @State private var selectedServer: Server? = SampleServers.servers.first

    var body: some View {
        VStack(spacing: 20) {
            Text("Welcome to Mustard")
                .font(.largeTitle)
                .bold()

            Text("Sign in to your preferred Mastodon instance.")
                .multilineTextAlignment(.center)
                .padding()

            // Show the selected server or allow the user to choose one
            Button(action: {
                showingServerList = true
            }) {
                HStack {
                    Text(selectedServer?.name ?? "Select a Mastodon Instance")
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
            .sheet(isPresented: $showingServerList) {
                ServerListView(
                    servers: SampleServers.servers,
                    onSelect: { server in
                        selectedServer = server
                        authViewModel.customInstanceURL = server.url.absoluteString
                        showingServerList = false
                    },
                    onCancel: {
                        showingServerList = false
                    }
                )
            }

            Button(action: {
                Task {
                    await authViewModel.authenticate()
                }
            }) {
                if authViewModel.isAuthenticating {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(8)
                } else {
                    Text("Sign In")
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(8)
                }
            }
            .disabled(authViewModel.isAuthenticating || selectedServer == nil)
            .padding(.horizontal)

            Spacer()
        }
        .padding()
        .alert(item: $authViewModel.alertError) { (error: AppError) in
            Alert(
                title: Text("Error"),
                message: Text(error.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}

struct AuthenticationView_Previews: PreviewProvider {
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

