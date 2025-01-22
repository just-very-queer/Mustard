//
//  SettingsView.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 13/01/25.
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
                Section(header: Text("Profile")) {
                    if let user = authViewModel.currentUser {
                        HStack {
                            AvatarView(url: user.avatar, size: 50)
                            VStack(alignment: .leading, spacing: 4) {
                                // Use the correct display_name property here
                                Text(user.display_name).font(.headline)
                                Text("@\(user.username)").font(.caption).foregroundColor(.gray)
                            }
                        }
                    } else {
                        Text("Not logged in").foregroundColor(.gray)
                    }
                }

                // Preferences Section
                Section(header: Text("Preferences")) {
                    Toggle("Enable Location Services", isOn: Binding(
                        get: { locationManager.userLocation != nil },
                        set: { _ in locationManager.requestLocationPermission() }
                    ))
                }

                // Account Section
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


// MARK: - Preview
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        let mockService = MockMastodonService(shouldSucceed: true)
        let authViewModel = AuthenticationViewModel(mastodonService: mockService)
        let locationManager = LocationManager()

        return SettingsView()
            .environmentObject(authViewModel)
            .environmentObject(locationManager)
    }
}
