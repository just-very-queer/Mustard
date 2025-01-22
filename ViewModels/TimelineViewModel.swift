//
//  TimelineViewModel.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 30/12/24.
//

import SwiftUI
import Combine
import CoreLocation
import OSLog

@MainActor
class TimelineViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var posts: [Post] = []
    @Published var topPosts: [Post] = []
    @Published var weather: WeatherData?
    @Published var isLoading = false
    @Published var isFetchingMore = false // Indicates if fetching more posts for infinite scroll
    @Published var alertError: AppError?

    // MARK: - Private Properties

    private let mastodonService: MastodonServiceProtocol
    private let authViewModel: AuthenticationViewModel
    private let locationManager: LocationManager
    private var cancellables = Set<AnyCancellable>()
    private let logger = Logger(subsystem: "com.yourcompany.Mustard", category: "TimelineViewModel")
    private let weatherAPIKeyBase64 = "OTk2NTdjOTNhN2E5M2JlYTJkZTdiZjkzZTMyMTkxMDQy=" // Base64-encoded API key
    
    private var weatherFetchTask: Task<Void, Never>?
    private var weatherFetchOnce: Bool = false // Ensures weather is fetched only once per app launch

    // MARK: - Initialization

    init(mastodonService: MastodonServiceProtocol, authViewModel: AuthenticationViewModel, locationManager: LocationManager) {
        self.mastodonService = mastodonService
        self.authViewModel = authViewModel
        self.locationManager = locationManager

        // Subscribe to authentication and location updates
        setupSubscriptions()
    }

    // MARK: - Setup

    private func setupSubscriptions() {
        // Authentication updates
        NotificationCenter.default.publisher(for: .didAuthenticate)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task {
                    await self?.initializeData()
                }
            }
            .store(in: &cancellables)

        // Location updates
        locationManager.locationPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] location in
                // Only fetch weather once after initialization or a significant location update
                guard let self = self else { return }
                if !self.weatherFetchOnce {
                    Task {
                        await self.fetchWeather(for: location)
                    }
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Data Fetching

    func initializeData() async {
        do {
            try await mastodonService.ensureInitialized()

            if mastodonService.isTokenNearExpiry() {
                if let instanceURL = try await mastodonService.retrieveInstanceURL(),
                   let config = try? await mastodonService.registerOAuthApp(instanceURL: instanceURL) {
                    try await mastodonService.reauthenticate(config: config, instanceURL: instanceURL)
                } else {
                    logger.warning("Reauthentication required but no stored instance URL found.")
                }
            }

            // Fetch data sequentially using serial queue to avoid race conditions
            await fetchTimeline(useCache: false)
            await fetchTopPosts()

            // Fetch weather once during initialization
            if let location = self.locationManager.userLocation, !self.weatherFetchOnce {
                await self.fetchWeather(for: location)
                self.weatherFetchOnce = true
            }
        } catch {
            alertError = AppError(type: .generic("Initialization failed."), underlyingError: error)
            logger.error("Initialization failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func fetchTimeline(useCache: Bool = true) async {
        // Prevent concurrent timeline fetches
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let fetchedPosts = try await mastodonService.fetchTimeline(useCache: useCache)
            posts = fetchedPosts.sorted { $0.createdAt > $1.createdAt }
            logger.info("Timeline fetched successfully.")
        } catch let error as AppError {
            // Handle specific AppError cases
            if case .cache(.notFound) = error.type {
                logger.info("Timeline cache not found on disk. Fetching from network.")
                // Proceed to fetch from the network
            } else {
                alertError = error
                logger.error("Failed to fetch timeline: \(error.localizedDescription, privacy: .public)")
            }
        } catch {
            // Handle generic errors
            alertError = AppError(type: .mastodon(.failedToFetchTimeline), underlyingError: error)
            logger.error("Failed to fetch timeline: \(error.localizedDescription, privacy: .public)")
        }
    }

    func fetchMoreTimeline() async {
        // Prevent fetching more if already fetching or not authenticated
        guard !isFetchingMore, authViewModel.isAuthenticated else { return }
        isFetchingMore = true
        defer { isFetchingMore = false }

        do {
            let nextPagePosts = try await mastodonService.fetchTimeline(page: (posts.count / 20) + 1, useCache: false)
            if !nextPagePosts.isEmpty {
                let newPosts = nextPagePosts.filter { newPost in
                    !posts.contains { $0.id == newPost.id }
                }
                posts.append(contentsOf: newPosts.sorted { $0.createdAt > $1.createdAt })
                logger.info("Fetched more posts.")
            } else {
                logger.info("No more posts available.")
            }
        } catch {
            alertError = AppError(type: .mastodon(.failedToFetchTimelinePage), underlyingError: error)
            logger.error("Failed to fetch more timeline: \(error.localizedDescription, privacy: .public)")
        }
    }

    func fetchTopPosts() async {
        do {
            let fetchedTopPosts = try await mastodonService.fetchTrendingPosts()
            topPosts = fetchedTopPosts
            logger.info("Top posts fetched successfully.")
        } catch {
            alertError = AppError(type: .mastodon(.failedToFetchTrendingPosts), underlyingError: error)
            logger.error("Failed to fetch top posts: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Weather Fetching
    
    func fetchWeather(for location: CLLocation) async {
        weatherFetchTask?.cancel() // Cancel any existing task

        guard authViewModel.isAuthenticated else {
            logger.warning("Weather fetch attempted when not authenticated.")
            return
        }
        
        weatherFetchTask = Task { [weak self] in
            // Debounce: Wait for 0.5 seconds
            try? await Task.sleep(nanoseconds: 500_000_000)

            guard !Task.isCancelled else { return }

            await MainActor.run {
                self?.isLoading = true
            }
            defer {
                Task {
                    await MainActor.run {
                        self?.isLoading = false
                    }
                }
            }

            guard let self = self, let apiKey = self.decodeAPIKey(self.weatherAPIKeyBase64) else {
                await MainActor.run {
                    self?.alertError = AppError(type: .weather(.invalidKey))
                }
                return
            }

            let urlString = "https://api.openweathermap.org/data/2.5/weather?lat=\(location.coordinate.latitude)&lon=\(location.coordinate.longitude)&units=metric&appid=\(apiKey)"
            guard let url = URL(string: urlString) else {
                await MainActor.run {
                    self.alertError = AppError(type: .weather(.invalidURL))
                }
                return
            }

            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw AppError(type: .weather(.badResponse))
                }

                logger.info("Weather API Response Status Code: \(httpResponse.statusCode)")

                if (200...299).contains(httpResponse.statusCode) {
                    let weatherResponse = try JSONDecoder().decode(OpenWeatherResponse.self, from: data)
                    await MainActor.run {
                        self.weather = WeatherData(temperature: weatherResponse.main.temp, description: weatherResponse.weather.first?.description ?? "No description", cityName: weatherResponse.name)
                    }
                } else {
                    logger.error("Weather API Error: \(httpResponse.statusCode)")
                    throw AppError(type: .weather(.badResponse), underlyingError: NSError(domain: "HTTPError", code: httpResponse.statusCode, userInfo: nil))
                }
            } catch {
                logger.error("Weather fetch failed: \(error.localizedDescription, privacy: .public)")
                await MainActor.run {
                    self.alertError = AppError(type: .weather(.badResponse), underlyingError: error)
                }
            }
        }
    }

    // MARK: - Post Actions

    func toggleLike(on post: Post) async {
        do {
            try await mastodonService.toggleLike(postID: post.id)
            if let index = posts.firstIndex(where: { $0.id == post.id }) {
                posts[index].isFavourited.toggle()
                posts[index].favouritesCount += posts[index].isFavourited ? 1 : -1
            }
            logger.info("Post \(post.id) like toggled successfully.")
        } catch {
            alertError = AppError(type: .generic("Failed to toggle like."), underlyingError: error)
            logger.error("Failed to toggle like for post \(post.id): \(error.localizedDescription, privacy: .public)")
        }
    }

    func toggleRepost(on post: Post) async {
        do {
            try await mastodonService.toggleRepost(postID: post.id)
            if let index = posts.firstIndex(where: { $0.id == post.id }) {
                posts[index].isReblogged.toggle()
                posts[index].reblogsCount += posts[index].isReblogged ? 1 : -1
            }
            logger.info("Post \(post.id) repost toggled successfully.")
        } catch {
            alertError = AppError(type: .generic("Failed to toggle repost."), underlyingError: error)
            logger.error("Failed to toggle repost for post \(post.id): \(error.localizedDescription, privacy: .public)")
        }
    }

    func comment(on post: Post, content: String) async throws {
        do {
            try await mastodonService.comment(postID: post.id, content: content)
            if let index = posts.firstIndex(where: { $0.id == post.id }) {
                posts[index].repliesCount += 1
            }
            logger.info("Comment added to post \(post.id) successfully.")
        } catch {
            alertError = AppError(type: .generic("Failed to add comment."), underlyingError: error)
            logger.error("Failed to add comment for post \(post.id): \(error.localizedDescription, privacy: .public)")
            throw error // Re-throw the error after logging
        }
    }

    // MARK: - Private Helpers

    private func decodeAPIKey(_ base64Key: String) -> String? {
        guard let data = Data(base64Encoded: base64Key) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

