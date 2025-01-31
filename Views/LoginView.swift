//
//  LoginView.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 24/01/25.
//

import SwiftUI
import SwiftData
import OSLog

struct LoginView: View {
    @EnvironmentObject var authViewModel: AuthenticationViewModel
    @EnvironmentObject var locationManager: LocationManager
    @State private var isAuthenticating: Bool = false
    @State private var showServerList: Bool = false
    @State private var showGlow = false

    private let logger = Logger(subsystem: "com.yourcompany.Mustard", category: "LoginView")

    var body: some View {
        NavigationView {
            ZStack {
                // Apply GlowEffect as a background with conditional visibility
                if showGlow {
                    GlowEffect()
                        .edgesIgnoringSafeArea(.all) // Make sure the effect covers the whole screen
                        .onAppear {
                            // Start a timer to stop the glow after 2 seconds
                            Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { _ in
                                withAnimation(.easeOut(duration: 0.5)) {
                                    showGlow = false
                                }
                            }
                        }
                        .transition(.opacity)
                }

                VStack {
                    Text("Welcome to Mustard")
                        .font(.largeTitle)
                        .padding(.bottom, 50)

                    // Add Server Button
                    Button(action: {
                        showServerList = true
                        // Trigger the glow effect when the button is tapped
                        withAnimation {
                            showGlow = true
                        }
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.blue)
                            Text("Add Server")
                                .font(.headline)
                                .foregroundColor(.blue)
                        }
                        .padding(.top, 20)
                    }
                }
                .sheet(isPresented: $showServerList) {
                    ServerListView(
                        onSelect: { server in
                            // Indicate that authentication is in progress
                            isAuthenticating = true
                            Task {
                                // Use the logger here
                                logger.debug("Authenticate called with server: \(server.name)")
                                do {
                                    try await authViewModel.authenticate(to: server)
                                    // Authentication was successful, dismiss the sheet
                                    showServerList = false
                                    logger.debug("isAuthenticated: \(authViewModel.isAuthenticated)")
                                } catch {
                                    // Handle authentication failure
                                    logger.error("Authentication failed: \(error.localizedDescription)")
                                    authViewModel.alertError = AppError(message: "Authentication failed", underlyingError: error)
                                }
                                isAuthenticating = false
                            }
                        },
                        onCancel: {
                            showServerList = false
                        }
                    )
                    .environmentObject(authViewModel)
                }
                .alert(isPresented: Binding<Bool>(
                    get: { authViewModel.alertError != nil },
                    set: { if !$0 { authViewModel.alertError = nil } }
                )) {
                    Alert(
                        title: Text("Authentication Failed"),
                        message: Text(authViewModel.alertError?.message ?? "Please try again."),
                        dismissButton: .default(Text("OK")) {
                            authViewModel.alertError = nil
                        }
                    )
                }
                .navigationTitle("Login")
                .disabled(isAuthenticating)
                .onAppear {
                    // Reset authentication state on appearance if needed
                    isAuthenticating = false
                    // Trigger the glow effect when the view first appears
                    withAnimation {
                        showGlow = true
                    }
                }
            }
        }
    }
}

