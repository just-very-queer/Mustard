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
    @Environment(LocationManager.self) private var locationManager
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
                        .edgesIgnoringSafeArea(.all)
                        .onAppear {
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

                    // Progress indicator when authenticating
                    if isAuthenticating {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .padding(.top, 20)
                    }
                }
                .sheet(isPresented: $showServerList) {
                    ServerListView(
                        onSelect: { selectedServer in
                            showServerList = false
                            isAuthenticating = true
                            Task {
                                await AuthenticationService.shared.authenticate(to: selectedServer)
                                isAuthenticating = false
                            }
                        },
                        onCancel: {
                            showServerList = false
                        }
                    )
                }
                .navigationTitle("Login")
                .navigationBarHidden(true)
            }
        }
    }
}
