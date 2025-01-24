//
//  SettingsView.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 24/01/25.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authViewModel: AuthenticationViewModel
    @EnvironmentObject var locationManager: LocationManager
    @State private var isShowingLogoutAlert = false

    var body: some View {
        NavigationView {
            List {
                // Profile Section
                Section(header: Text("Profile").font(.headline).padding(.top)) {
                    if let user = authViewModel.currentUser {
                        NavigationLink(destination: ProfileView(user: user)) {
                            HStack {
                                AvatarView(
                                    url: URL(string: user.avatar ?? "https://example.com/default_avatar.png"),
                                    size: 50
                                )
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(user.display_name ?? user.username)
                                        .font(.headline)
                                    Text("@\(user.username)")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                    } else {
                        Text("Not logged in")
                            .foregroundColor(.gray)
                            .font(.subheadline)
                            .padding(.vertical, 8)
                    }
                }

                // Preferences Section
                Section(header: Text("Preferences").font(.headline)) {
                    Toggle(isOn: Binding(
                        get: { locationManager.userLocation != nil },
                        set: { _ in locationManager.requestLocationPermission() }
                    )) {
                        HStack {
                            Image(systemName: "location.circle")
                                .foregroundColor(.blue)
                            Text("Enable Location Services")
                        }
                    }
                }

                // Account Section
                Section(header: Text("Account").font(.headline)) {
                    Button(role: .destructive) {
                        isShowingLogoutAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "arrow.right.circle.fill")
                                .foregroundColor(.red)
                            Text("Log Out")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .listStyle(InsetGroupedListStyle())
            .alert(isPresented: $isShowingLogoutAlert) {
                Alert(
                    title: Text("Log Out"),
                    message: Text("Are you sure you want to log out?"),
                    primaryButton: .destructive(Text("Log Out")) {
                        Task { await authViewModel.logout() }
                    },
                    secondaryButton: .cancel()
                )
            }
        }
    }
}


