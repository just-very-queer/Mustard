//
//  LoginView.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 24/01/25.
//

import SwiftUI
import SwiftData

struct LoginView: View {
    @EnvironmentObject var authViewModel: AuthenticationViewModel
    @EnvironmentObject var locationManager: LocationManager
    @Query private var servers: [Server] // Fetch servers from SwiftData
    @State private var isAuthenticating: Bool = false
    @State private var authenticationFailed: Bool = false
    @State private var showServerList: Bool = false

    var body: some View {
        NavigationView {
            VStack {
                if servers.isEmpty {
                    // Prompt to add a server if the list is empty
                    Text("No server added yet.")
                    Button("Add Server") {
                        showServerList = true
                    }
                } else {
                    // Show existing server(s) and login button
                    Text("Welcome to Mustard")
                        .font(.largeTitle)
                        .padding(.bottom, 50)
                    
                    // Display the server(s)
                    ForEach(servers, id: \.id) { server in
                        Button(action: {
                            // Indicate that authentication is in progress
                            isAuthenticating = true
                            Task {
                                print("Authenticate called with server: \(server.name)")
                                await authViewModel.authenticate(to: server)
                                print("isAuthenticated: \(authViewModel.isAuthenticated)")
                                print("alertError: \(String(describing: authViewModel.alertError))")

                                // Reset isAuthenticating state after authentication attempt
                                isAuthenticating = false

                                if authViewModel.isAuthenticated {
                                    print("Authentication successful, proceed to main app")
                                } else {
                                    print("Authentication failed")
                                    authenticationFailed = true
                                }
                            }
                        }) {
                            Text("Login with \(server.name)")
                                .font(.headline)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        .padding(.horizontal)
                        .disabled(isAuthenticating)
                    }
                    
                    // Add Server Button
                    Button(action: {
                        showServerList = true
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
            }
            .sheet(isPresented: $showServerList) {
                ServerListView(
                    onSelect: { server in
                        // Indicate that authentication is in progress
                        isAuthenticating = true
                        Task {
                            print("Authenticate called with server: \(server.name)")
                            await authViewModel.authenticate(to: server)
                            print("isAuthenticated: \(authViewModel.isAuthenticated)")
                            print("alertError: \(String(describing: authViewModel.alertError))")
                            
                            // Reset isAuthenticating state after authentication attempt
                            isAuthenticating = false
                            
                            if authViewModel.isAuthenticated {
                                print("Authentication successful, proceed to main app")
                            } else {
                                print("Authentication failed")
                                authenticationFailed = true
                            }
                        }
                    },
                    onCancel: {
                        showServerList = false
                    }
                )
                .environmentObject(authViewModel)
            }
            .alert("Authentication Failed", isPresented: $authenticationFailed) {
                Button("OK", role: .cancel) {
                    authenticationFailed = false
                }
            } message: {
                if let error = authViewModel.alertError {
                    Text("Error: \(error.message)")
                } else {
                    Text("Please try again.")
                }
            }
            .navigationTitle("Login")
            .disabled(isAuthenticating)
        }
    }
}
