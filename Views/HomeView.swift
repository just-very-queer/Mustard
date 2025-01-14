//
//  HomeView.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 13/01/25.
//

import SwiftUI
import OSLog
import SwiftData

struct HomeView: View {
    // MARK: - Environment Objects
    @EnvironmentObject var timelineViewModel: TimelineViewModel
    @EnvironmentObject var authViewModel: AuthenticationViewModel
    @EnvironmentObject var locationManager: LocationManager

    // For infinite scroll detection
    @State private var isRequestingMore = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    weatherHeader
                    topPostsSection
                    timelineSection
                }
                .padding(.horizontal)
            }
            .navigationTitle("Home")
            .onAppear {
                initializeData()
            }
            .alert(item: $timelineViewModel.alertError) { error in
                Alert(
                    title: Text("Error"),
                    message: Text(error.message),
                    dismissButton: .default(Text("OK"))
                )
            }
            .toolbar {
                logoutButton
            }
        }
    }

    // MARK: - Weather Header
    private var weatherHeader: some View {
        Group {
            if let weather = timelineViewModel.weather {
                WeatherBarView(weather: weather)
                    .padding(.top)
            }
        }
    }

    // MARK: - Top Posts Section
    private var topPostsSection: some View {
        Group {
            if !timelineViewModel.topPosts.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Here’s Today’s Top Mastodon Posts")
                        .font(.headline)
                        .padding(.leading, 16)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(timelineViewModel.topPosts) { post in
                                NavigationLink(destination: PostView(post: post)) {
                                    PostView(post: post)
                                        .frame(width: 300)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Timeline Section
    private var timelineSection: some View {
        Group {
            if timelineViewModel.isLoading && timelineViewModel.posts.isEmpty {
                ProgressView("Loading timeline...")
                    .padding()
            } else if timelineViewModel.posts.isEmpty {
                Text("No posts available.")
                    .font(.headline)
                    .foregroundColor(.gray)
                    .padding()
            } else {
                LazyVStack {
                    ForEach(timelineViewModel.posts) { post in
                        NavigationLink(destination: PostView(post: post)) {
                            PostView(post: post)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .onAppear {
                            loadMorePostsIfNeeded(currentPost: post)
                        }
                    }

                    if timelineViewModel.isLoading {
                        HStack {
                            Spacer()
                            ProgressView("Loading more...")
                            Spacer()
                        }
                        .padding()
                    }
                }
            }
        }
    }

    // MARK: - Logout Button
    private var logoutButton: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button(action: {
                Task {
                    await authViewModel.logout()
                }
            }) {
                Image(systemName: "arrow.backward.circle.fill")
                    .imageScale(.large)
            }
            .accessibilityLabel("Logout")
        }
    }

    // MARK: - Helper Functions
    private func initializeData() {
        if authViewModel.isAuthenticated {
            Task {
                await timelineViewModel.fetchTopPosts()
                if let location = locationManager.userLocation {
                    timelineViewModel.fetchWeather(for: location)
                }
            }
        }
    }

    private func loadMorePostsIfNeeded(currentPost: Post) {
        guard currentPost == timelineViewModel.posts.last, !isRequestingMore else { return }
        isRequestingMore = true
        Task {
            await timelineViewModel.fetchMoreTimeline()
            isRequestingMore = false
        }
    }
}

// MARK: - WeatherBarView
struct WeatherBarView: View {
    let weather: WeatherData

    var body: some View {
        HStack {
            Text(weather.cityName).font(.headline)
            Spacer()
            Text("\(weather.temperature, specifier: "%.1f")°C")
            Text(weather.description).font(.caption).foregroundColor(.gray)
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(8)
    }
}

// MARK: - Preview
struct HomeView_Preview: PreviewProvider {
    static var previews: some View {
        let mockService = MockMastodonService(shouldSucceed: true)
        let authViewModel = AuthenticationViewModel(mastodonService: mockService)
        let timelineViewModel = TimelineViewModel(mastodonService: mockService, authViewModel: authViewModel)
        let locationManager = LocationManager()

        return HomeView()
            .environmentObject(authViewModel)
            .environmentObject(timelineViewModel)
            .environmentObject(locationManager)
    }
}
