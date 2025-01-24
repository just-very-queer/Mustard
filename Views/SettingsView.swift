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
    @State private var isShowingProfile = false

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Profile")) {
                    if let user = authViewModel.currentUser {
                        NavigationLink(destination: ProfileView(user: user)) {
                            HStack {
                                AvatarView(url: user.avatar, size: 50)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(user.display_name ?? user.username).font(.headline)
                                    Text("@\(user.username)").font(.caption).foregroundColor(.gray)
                                }
                            }
                        }
                    } else {
                        Text("Not logged in").foregroundColor(.gray)
                    }
                }

                Section(header: Text("Preferences")) {
                    Toggle("Enable Location Services", isOn: Binding(
                        get: { locationManager.userLocation != nil },
                        set: { _ in locationManager.requestLocationPermission() }
                    ))
                }

                Section(header: Text("Account")) {
                    Button("Log Out") {
                        isShowingLogoutAlert = true
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Settings")
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
