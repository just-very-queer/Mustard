//
//  AuthenticationView.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 30/12/24.
//

import SwiftUI
import SwiftData

struct AuthenticationView: View {
    @EnvironmentObject var authViewModel: AuthenticationViewModel
    @State private var showingServerList = false
    @State private var selectedServer: Server? = nil

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
                    Text(selectedServer?.name ?? "Select a Mastodon Instance")
                        .foregroundColor(selectedServer != nil ? .black : .blue)
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
                        showingServerList = false
                        initiateAuthentication(with: server)
                    },
                    onCancel: {
                        showingServerList = false
                    }
                )
            }

            Spacer()
        }
        .padding()
        .overlay(
            Group {
                if authViewModel.isAuthenticating {
                    Color.black.opacity(0.4)
                        .edgesIgnoringSafeArea(.all)
                    ProgressView("Authenticating...")
                        .padding()
                        .background(Color.white)
                        .cornerRadius(10)
                }
            }
        )
        .alert(item: $authViewModel.alertError) { error in
            Alert(
                title: Text("Authentication Error"),
                message: Text(error.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    // MARK: - Private Methods

    private func initiateAuthentication(with server: Server) {
        Task {
            do {
                try await authViewModel.authenticate(with: server)
                print("[AuthenticationView] Authentication successful for server: \(server.name)")
            } catch {
                authViewModel.alertError = AppError(message: "Authentication failed: \(error.localizedDescription)")
                print("[AuthenticationView] Authentication failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Preview
    struct AuthenticationView_Previews: PreviewProvider {
        static var previews: some View {
            let previewService = MockMastodonService()

            let container: ModelContainer
            do {
                container = try ModelContainer(for: Account.self, MediaAttachment.self, Post.self)
            } catch {
                fatalError("Failed to create ModelContainer: \(error)")
            }

            let modelContext = container.mainContext

            let accountsViewModel = AccountsViewModel(mastodonService: previewService, modelContext: modelContext)
            let authViewModel = AuthenticationViewModel(mastodonService: previewService)
            let timelineViewModel = TimelineViewModel(mastodonService: previewService)

            accountsViewModel.accounts = previewService.mockAccounts
            accountsViewModel.selectedAccount = previewService.mockAccounts.first
            timelineViewModel.posts = previewService.mockPosts

            return AuthenticationView()
                .environmentObject(authViewModel)
                .environmentObject(timelineViewModel)
                .environmentObject(accountsViewModel)
                .modelContainer(container)
        }
    }
}

