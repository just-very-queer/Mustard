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
    @EnvironmentObject var topPostsViewModel: TopPostsViewModel
    @EnvironmentObject var weatherViewModel: WeatherViewModel
    @EnvironmentObject var locationManager: LocationManager
    
    // For infinite scroll detection
    @State private var isRequestingMore = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    
                    // 1) Weather Header
                    if let weather = weatherViewModel.weather {
                        WeatherBarView(weather: weather)
                            .padding(.top)
                    }
                    
                    // 2) Today's Top Posts
                    if !topPostsViewModel.topPosts.isEmpty {
                        VStack(alignment: .leading) {
                            Text("Here’s Today’s Top Mastodon Posts")
                                .font(.headline)
                                .padding(.leading, 16)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    ForEach(topPostsViewModel.topPosts) { post in
                                        NavigationLink(destination: PostDetailView(post: post)) {
                                            TopPostCardView(post: post)
                                                .frame(width: 300)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                            .padding(.vertical, 8)
                        }
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                    
                    // 3) Timeline - Infinite Scroll
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
                                NavigationLink(destination: PostDetailView(post: post)) {
                                    PostRowView(post: post)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .onAppear {
                                    // Infinite scroll: when last item appears, load more
                                    if post == timelineViewModel.posts.last && !isRequestingMore {
                                        isRequestingMore = true
                                        Task {
                                            await timelineViewModel.fetchMoreTimeline()
                                            isRequestingMore = false
                                        }
                                    }
                                }
                            }
                            
                            // Infinite Scroll Spinner
                            if timelineViewModel.isLoading {
                                HStack {
                                    Spacer()
                                    ProgressView("Loading more...")
                                    Spacer()
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .navigationTitle("Home")
            .onAppear {
                // If user is authenticated, request location and fetch top posts
                if authViewModel.isAuthenticated {
                    locationManager.requestLocationPermission()
                    
                    // Attempt to fetch top posts
                    Task {
                        await topPostsViewModel.fetchTopPostsOfDay()
                    }
                }
            }
            .onReceive(locationManager.$userLocation) { location in
                guard let loc = location else { return }
                weatherViewModel.fetchWeather(for: loc)
            }
            .alert(item: $timelineViewModel.alertError) { error in
                Alert(
                    title: Text("Error"),
                    message: Text(error.message),
                    dismissButton: .default(Text("OK"))
                )
            }
            .toolbar {
                // Logout Button
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
        }
    }
}

// MARK: - Preview
struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        // Initialize Mock Service with predefined mock data
        let mockService = PreviewService(
            shouldSucceed: true,
            mockPosts: [
                Post(
                    id: "1",
                    content: "<p>Top post content 1</p>",
                    createdAt: Date(),
                    account: Account(
                        id: "a1",
                        username: "user1",
                        displayName: "User One",
                        avatar: URL(string: "https://example.com/avatar1.png")!,
                        acct: "user1",
                        instanceURL: URL(string: "https://mastodon.social")!,
                        accessToken: "mockAccessToken123"
                    ),
                    mediaAttachments: [],
                    isFavourited: false,
                    isReblogged: false,
                    reblogsCount: 0,
                    favouritesCount: 0,
                    repliesCount: 0
                ),
                Post(
                    id: "2",
                    content: "<p>Top post content 2</p>",
                    createdAt: Date(),
                    account: Account(
                        id: "a2",
                        username: "user2",
                        displayName: "User Two",
                        avatar: URL(string: "https://example.com/avatar2.png")!,
                        acct: "user2",
                        instanceURL: URL(string: "https://mastodon.social")!,
                        accessToken: "mockAccessToken123"
                    ),
                    mediaAttachments: [],
                    isFavourited: false,
                    isReblogged: false,
                    reblogsCount: 0,
                    favouritesCount: 0,
                    repliesCount: 0
                )
            ],
            mockTrendingPosts: [
                Post(
                    id: "3",
                    content: "<p>Trending post content 1</p>",
                    createdAt: Date(),
                    account: Account(
                        id: "a3",
                        username: "user3",
                        displayName: "User Three",
                        avatar: URL(string: "https://example.com/avatar3.png")!,
                        acct: "user3",
                        instanceURL: URL(string: "https://mastodon.social")!,
                        accessToken: "mockAccessToken123"
                    ),
                    mediaAttachments: [],
                    isFavourited: false,
                    isReblogged: false,
                    reblogsCount: 0,
                    favouritesCount: 0,
                    repliesCount: 0
                )
            ]
        )
        
        // Initialize Model Container with Required Models
        let container: ModelContainer
        do {
            container = try ModelContainer(for: Account.self, MediaAttachment.self, Post.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }

        // Initialize ViewModels
        let authViewModel = AuthenticationViewModel(mastodonService: mockService)
        let timelineViewModel = TimelineViewModel(mastodonService: mockService)
        let topPostsViewModel = TopPostsViewModel(service: mockService)
        let weatherViewModel = WeatherViewModel()
        let locationManager = LocationManager()
        
        return HomeView()
            .environmentObject(authViewModel)
            .environmentObject(timelineViewModel)
            .environmentObject(topPostsViewModel)
            .environmentObject(weatherViewModel)
            .environmentObject(locationManager)
            .modelContainer(container)
    }
}
