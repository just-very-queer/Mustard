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
    @Environment(AppEnvironment.self) private var appEnvironment
    @EnvironmentObject var locationManager: LocationManager
    @State private var isAuthenticating: Bool = false
    @State private var showServerList: Bool = false
    @State private var showGlow = false

    private let logger = Logger(subsystem: "titan.mustard.app.ao", category: "LoginView")

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
                            showServerList = false
                            // Introduce a small delay
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                Task {
                                    await AuthenticationService.shared.authenticate(to: server)
                                }
                            }
                        },
                        onCancel: {
                            showServerList = false
                        }
                    )
                }
                .alert(isPresented: Binding<Bool>(
                    get: { appEnvironment.alertError != nil },
                    set: { if !$0 { appEnvironment.alertError = nil } }
                )) {
                    Alert(
                        title: Text("Authentication Failed"),
                        message: Text(appEnvironment.alertError?.message ?? "Please try again."),
                        dismissButton: .default(Text("OK")) {
                            appEnvironment.alertError = nil
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
                    
                    // Register for keyboard notifications
                    NotificationCenter.default.addObserver(
                        forName: UIResponder.keyboardWillChangeFrameNotification,
                        object: nil,
                        queue: .main) { notification in
                            self.keyboardWillChangeFrame(notification: notification)
                    }
                }
                .onDisappear {
                    // Unregister for keyboard notifications when the view disappears
                    NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
                }
            }
            
            // Show progress view if authenticating
            if appEnvironment.authState == .authenticating {
                ProgressView("Authenticating...")
                    .progressViewStyle(CircularProgressViewStyle())
            }
        }
    }

    // MARK: - Keyboard Frame Change Handling
    func keyboardWillChangeFrame(notification: Notification) {
        guard let userInfo = notification.userInfo,
            let endFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }

        if endFrame.origin.y >= UIScreen.main.bounds.height {
            // Keyboard is not visible
            logger.debug("Keyboard is not visible.")
        } else {
            // Keyboard is visible
            logger.debug("Keyboard is visible.")
        }
    }
}

