//
//  HomeView.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 13/01/25.
//

import SwiftUI
import OSLog
import SwiftData
import CoreLocation

struct HomeView: View {
    // MARK: - Environment Objects
    @EnvironmentObject var timelineViewModel: TimelineViewModel
    @EnvironmentObject var authViewModel: AuthenticationViewModel
    @EnvironmentObject var locationManager: LocationManager

    // For infinite scroll detection
    @State private var isRequestingMore = false
    @State private var isShowingFullScreenImage = false
    @State private var selectedImageURL: URL?

    // Logger
    private let logger = Logger(subsystem: "com.yourcompany.Mustard", category: "HomeView")

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Show weather only if user is authenticated
                    if authViewModel.isAuthenticated {
                        weatherHeader
                    }
                    topPostsSection
                    timelineSection
                }
                .padding(.horizontal)
            }
            .navigationTitle("Home")
            .task { // Use .task instead of .onAppear
                await initializeData()
            }
            .onReceive(NotificationCenter.default.publisher(for: .didUpdateLocation)) { notification in
                // Only fetch weather if user is authenticated
                if authViewModel.isAuthenticated, let location = notification.userInfo?["location"] as? CLLocation {
                    Task {
                        await timelineViewModel.fetchWeather(for: location)
                    }
                }
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
            .sheet(isPresented: $isShowingFullScreenImage) {
                if let imageURL = selectedImageURL {
                    FullScreenImageView(imageURL: imageURL, isPresented: $isShowingFullScreenImage)
                }
            }
        }
    }

    // MARK: - Weather Header
    private var weatherHeader: some View {
        Group {
            if let weather = timelineViewModel.weather {
                WeatherBarView(weather: weather)
                    .padding(.top)
                    .transition(.opacity) // Add a transition effect
            } else if authViewModel.isAuthenticated {
                // Only prompt for location if authenticated
                Button(action: {
                    locationManager.requestLocationPermission()
                }) {
                    Text("Enable Location to Show Weather")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                        .shadow(radius: 3)
                }
                .padding(.top)
            }
        }
    }

    // MARK: - Top Posts Section
    private var topPostsSection: some View {
        Group {
            if !timelineViewModel.topPosts.isEmpty {
                VStack(alignment: .leading) {
                    Text("Trending Posts")
                        .font(.title2)
                        .bold()
                        .padding(.leading)
                        .padding(.top)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(timelineViewModel.topPosts) { post in
                                NavigationLink(destination: PostView(post: post)) {
                                    PostView(post: post)
                                        .frame(width: 300)
                                        .cornerRadius(15)
                                        .shadow(radius: 5)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(20)
                .shadow(radius: 5)
                .padding(.horizontal, 5)
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
                LazyVStack(spacing: 15) {
                    ForEach(timelineViewModel.posts) { post in
                        NavigationLink(destination: PostView(post: post)) {
                            PostView(post: post)
                                .cornerRadius(15)
                                .shadow(radius: 3)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .onAppear {
                            loadMorePostsIfNeeded(currentPost: post)
                        }
                        .contextMenu {
                            if let firstImage = post.mediaAttachments.first?.url {
                                Button(action: {
                                    selectedImageURL = firstImage
                                    isShowingFullScreenImage = true
                                }) {
                                    Label("View Image", systemImage: "photo")
                                }
                            }
                        }
                    }

                    if timelineViewModel.isFetchingMore {
                        HStack {
                            Spacer()
                            ProgressView("Loading more...")
                            Spacer()
                        }
                        .padding()
                    }
                }
                .padding(.top, 5) // Add some top padding to the LazyVStack
            }
        }
    }

    // MARK: - Logout Button
    private var logoutButton: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                Task { // Create an async context here
                    await authViewModel.logout()
                }
            } label: {
                Image(systemName: "arrow.backward.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
            .accessibilityLabel("Logout")
        }
    }

    // MARK: - Helper Functions
    private func initializeData() async {
        // Only initialize data if authenticated
        guard authViewModel.isAuthenticated else { return }
        await timelineViewModel.fetchTimeline()
        await timelineViewModel.fetchTopPosts()
        if let location = locationManager.userLocation {
            await timelineViewModel.fetchWeather(for: location)
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
            VStack(alignment: .leading) {
                Text(weather.cityName)
                    .font(.title2)
                    .bold()
                    .foregroundColor(.primary)
                Text(weather.description.capitalized)
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text("\(weather.temperature, specifier: "%.1f")°C")
                .font(.largeTitle)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(UIColor.secondarySystemBackground))
                .shadow(color: .gray.opacity(0.3), radius: 10, x: 0, y: 5)
        )
    }
}

// MARK: - Preview

struct HomeView_Preview: PreviewProvider {
    static var previews: some View {
        let mockService = MockMastodonService(shouldSucceed: true)
        let authViewModel = AuthenticationViewModel(mastodonService: mockService)
        let locationManager = LocationManager()

        // Initialize the TimelineViewModel with locationManager
        let timelineViewModel = TimelineViewModel(
            mastodonService: mockService,
            authViewModel: authViewModel,
            locationManager: locationManager
        )

        // Simulate fetched weather data
        timelineViewModel.weather = WeatherData(
            temperature: 23.5,
            description: "Clear sky",
            cityName: "San Francisco"
        )

        return HomeView()
            .environmentObject(authViewModel)
            .environmentObject(timelineViewModel)
            .environmentObject(locationManager)
    }
}
