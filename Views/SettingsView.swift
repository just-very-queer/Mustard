//
//  SettingsView.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 24/01/25.
//

import SwiftUI
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject var authViewModel: AuthenticationViewModel
    @EnvironmentObject var locationManager: LocationManager // Make sure LocationManager is available
    @EnvironmentObject var cacheService: CacheService
    @State private var isShowingLogoutAlert = false
    @State private var selectedCacheSize: Int = 100 // Default cache size
    @AppStorage("isDarkMode") private var isDarkMode = false // Dark mode setting
    @State private var isCachingPosts = false // State to track caching progress
    @State private var cacheProgress: Double = 0.0 // Progress value

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
                                VStack(alignment:.leading, spacing: 4) {
                                    Text(user.display_name ?? user.username)
                                        .font(.headline)
                                    Text("@\(user.username)")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    } else {
                        Text("Not logged in")
                            .foregroundColor(.gray)
                            .font(.subheadline)
                            .padding(.vertical, 8)
                    }
                }

                // Preferences Section
                Section(header: Text("Preferences").font(.headline)) {
                    Toggle(isOn: $isDarkMode) {
                        HStack {
                            Image(systemName: "moon.circle")
                                .foregroundColor(.blue)
                            Text("Dark Mode")
                        }
                    }

                    Picker("Cache Posts for Offline Reading", selection: $selectedCacheSize) {
                        Text("100 Posts").tag(100)
                        Text("500 Posts").tag(500)
                        Text("1000 Posts").tag(1000)
                    }
                    .pickerStyle(MenuPickerStyle())

                    Button(action: {
                        Task {
                            isCachingPosts = true
                            await cacheService.prefetchPosts(count: selectedCacheSize, forKey: "offline_posts", progress: { progress in
                                // Update the progress here
                                cacheProgress = progress
                            })
                            isCachingPosts = false
                        }
                    }) {
                        HStack {
                            Image(systemName: "arrow.down.circle.fill")
                                .foregroundColor(.blue)
                            Text("Cache Posts for Offline Reading")
                        }
                    }
                    
                    if isCachingPosts {
                        ProgressView("Caching Posts...", value: cacheProgress, total: 100)
                            .progressViewStyle(LinearProgressViewStyle())
                            .padding()
                    }

                    Button("Request Notification Permission") {
                        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
                            if granted {
                                print("Notification permission granted.")
                            } else if let error = error {
                                print("Error requesting notification permission: \(error.localizedDescription)")
                            } else {
                                print("Notification permission denied.")
                            }
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
                        Task { authViewModel.logout() }
                    },
                    secondaryButton: .cancel()
                )
            }
        }
        .preferredColorScheme(isDarkMode ? .dark : .light) // Corrected Dark Mode toggle
    }
}

