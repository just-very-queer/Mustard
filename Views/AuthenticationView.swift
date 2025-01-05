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
    @State private var isAuthenticating = false

    var body: some View {
        VStack(spacing: 20) {
            Text("Welcome to Mustard")
                .font(.largeTitle)
                .bold()

            Text("Sign in to your preferred Mastodon instance.")
                .multilineTextAlignment(.center)
                .padding()

            // Server selection button
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
            .disabled(isAuthenticating) // Disable while authenticating
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

            // Authentication progress
            if isAuthenticating {
                ProgressView("Authenticating...")
                    .padding()
            }
        }
        .padding()
        .overlay(
            Group {
                if authViewModel.isAuthenticating {
                    Color.black.opacity(0.4)
                        .edgesIgnoringSafeArea(.all)
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

    private func initiateAuthentication(with server: Server) {
        guard !isAuthenticating else { return }
        isAuthenticating = true // Start loading
        Task {
            await authViewModel.authenticate(to: server)

            // Validate base URL after authentication
            let isValid = await authViewModel.validateBaseURL()
            if isValid {
                print("[AuthenticationView] Base URL validated successfully.")
            } else {
                authViewModel.alertError = AppError(message: "Failed to validate base URL after login.")
            }
            isAuthenticating = false // Stop loading
        }
    }
}

// MARK: - Preview
struct AuthenticationView_Previews: PreviewProvider {
    static var previews: some View {
        let mockService = MockMastodonService(shouldSucceed: true)

        let container: ModelContainer
        do {
            container = try ModelContainer(for: Account.self, MediaAttachment.self, Post.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }

        let authViewModel = AuthenticationViewModel(mastodonService: mockService)
        let timelineViewModel = TimelineViewModel(mastodonService: mockService)
        let topPostsViewModel = TopPostsViewModel(service: mockService)
        let weatherViewModel = WeatherViewModel()
        let locationManager = LocationManager()

        return AuthenticationView()
            .environmentObject(authViewModel)
            .environmentObject(timelineViewModel)
            .environmentObject(topPostsViewModel)
            .environmentObject(weatherViewModel)
            .environmentObject(locationManager)
            .modelContainer(container)
    }
}
