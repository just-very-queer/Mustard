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

    // Animation properties
    @State private var glowOpacity: Double = 0.5
    @State private var glowRadius: CGFloat = 10
    @State private var isAnimating = false

    var body: some View {
        NavigationView {
            ZStack {
                // Background with animated glowing gradient effect
                AnimatedGradientGlowView()

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
                                
                                // Use `Task` to run async code within the button's action
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

// Animated Gradient Glow View
struct AnimatedGradientGlowView: View {
    @State private var startRadius: CGFloat = 0
    @State private var endRadius: CGFloat = 200

    var body: some View {
        RadialGradient(
            gradient: Gradient(colors: [
                Color(red: 0.4, green: 0.6, blue: 1.0).opacity(0.8),
                Color(red: 0.6, green: 0.8, blue: 1.0).opacity(0.3),
                Color.clear
            ]),
            center: .center,
            startRadius: startRadius,
            endRadius: endRadius
        )
        .ignoresSafeArea()
        .onAppear {
            withAnimation(Animation.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                startRadius = 50
                endRadius = 150
            }
        }
    }
}

// MainAppView for the authenticated user
struct MainAppView: View {
    @EnvironmentObject var authViewModel: AuthenticationViewModel
    @EnvironmentObject var locationManager: LocationManager
    
    var body: some View {
        // Use a TabView to switch between HomeView and SettingsView
        TabView {
            // Home Tab
            NavigationStack {
                HomeView()
                    .environmentObject(authViewModel)
                    .environmentObject(TimelineViewModel(mastodonService: MastodonService.shared, authViewModel: authViewModel, locationManager: locationManager))
            }
            .tabItem {
                Label("Home", systemImage: "house")
            }

            // Settings Tab
            NavigationStack {
                SettingsView()
                    .environmentObject(authViewModel)
                    .environmentObject(locationManager)
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
        }
        .onAppear {
            // Fetch the timeline when the MainAppView appears
            Task {
                let timelineViewModel = TimelineViewModel(mastodonService: MastodonService.shared, authViewModel: authViewModel, locationManager: locationManager)
                await timelineViewModel.initializeData()
                await timelineViewModel.fetchTimeline()
            }
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
