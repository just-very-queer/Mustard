//
//  AuthenticationView.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 30/12/24.
//

import SwiftUI
import OSLog

struct AuthenticationView: View {
    @EnvironmentObject var authViewModel: AuthenticationViewModel
    @EnvironmentObject var locationManager: LocationManager
    @State private var showingServerList = false
    @State private var isAuthenticating = false

    // Logger instance
    private let logger = Logger(subsystem: "com.yourcompany.Mustard", category: "Authentication")

    // Gradient colors for the glowing effect
    private let gradientColors = [
        Color(red: 0.4, green: 0.6, blue: 1.0),
        Color(red: 0.6, green: 0.8, blue: 1.0),
        Color(red: 0.4, green: 0.6, blue: 1.0),
        Color(red: 0.6, green: 0.8, blue: 1.0)
    ]

    var body: some View {
        NavigationView {
            ZStack {
                // Background with glowing gradient effect
                LinearGradient(gradient: Gradient(colors: gradientColors), startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                    .opacity(0.5)

                // Main content
                VStack(spacing: 20) {
                    Text("Welcome to Mustard")
                        .font(.largeTitle)
                        .bold()
                        .foregroundColor(.white)

                    Text("Sign in to your preferred Mastodon instance.")
                        .multilineTextAlignment(.center)
                        .padding()
                        .foregroundColor(.white)

                    Button(action: {
                        showingServerList = true
                    }) {
                        HStack {
                            Text("Select a Mastodon Instance")
                                .foregroundColor(.white)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .foregroundColor(.gray)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(.black.opacity(0.2)) // Semi-transparent background
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.white, lineWidth: 1)
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
                                    await authViewModel.authenticate(to: server)
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
                            .tint(.white)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity) // Ensure content takes up full space
                .alert(item: $authViewModel.alertError) { error in
                    Alert(
                        title: Text("Authentication Error"),
                        message: Text(error.message),
                        dismissButton: .default(Text("OK"))
                    )
                }
                .navigationDestination(isPresented: $authViewModel.isAuthenticated) {
                    MainAppView()
                        .environmentObject(authViewModel)
                        .environmentObject(locationManager)
                }
            }
        }
        .navigationViewStyle(.stack) // Apply the stack style to the NavigationView
    }
}

// Placeholder for the Main App View
struct MainAppView: View {
    var body: some View {
        // Your main app content here
        Text("Welcome to the Main App")
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
