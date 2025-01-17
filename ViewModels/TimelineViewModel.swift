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
    private let weatherAPIKeyBase64 = "OTk2NTdjOTNhN2E5M2JlYTJkZTdiZjkzZTMyMTkxMDQy" // Base64-encoded API key

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
                Task { await self?.initializeData() }
            }
            .store(in: &cancellables)

        // Location updates
        locationManager.locationPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] location in
                self?.fetchWeather(for: location)
            }
            .store(in: &cancellables)
    }

    // MARK: - Data Fetching

    func initializeData() async {
            do {
                try await mastodonService.ensureInitialized()

                // Check if the token is near expiry or doesn't exist
                if mastodonService.isTokenNearExpiry() {
                    // Reauthenticate using the existing configuration
                    if let instanceURL = try await mastodonService.retrieveInstanceURL(),
                       let config = try? await mastodonService.registerOAuthApp(instanceURL: instanceURL) {
                        try await mastodonService.reauthenticate(config: config, instanceURL: instanceURL)
                    } else {
                        // Handle the case where reauthentication is not possible (e.g., no stored instance URL)
                        logger.warning("Reauthentication required but no stored instance URL found.")
                        // You might want to prompt the user to log in again or handle this case as appropriate
                    }
                }

                // Proceed with fetching data
                await fetchTimeline()
                await fetchTopPosts()
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
        } catch {
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
            topPosts = try await mastodonService.fetchTrendingPosts()
            logger.info("Top posts fetched successfully.")
        } catch {
            alertError = AppError(type: .mastodon(.failedToFetchTrendingPosts), underlyingError: error)
            logger.error("Failed to fetch top posts: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Weather Fetching
    
    func fetchWeather(for location: CLLocation) {
        // Check if the user is authenticated before fetching weather
        guard authViewModel.isAuthenticated else {
            logger.warning("Weather fetch attempted when not authenticated.")
            return
        }
        
        isLoading = true

        guard let apiKey = decodeAPIKey(weatherAPIKeyBase64) else {
            alertError = AppError(type: .weather(.invalidKey))
            isLoading = false
            return
        }

        let weatherURLString = "https://api.openweathermap.org/data/2.5/weather?lat=\(location.coordinate.latitude)&lon=\(location.coordinate.longitude)&units=metric&appid=\(apiKey)"

        guard let weatherURL = URL(string: weatherURLString) else {
            alertError = AppError(type: .weather(.invalidURL))
            isLoading = false
            return
        }

        URLSession.shared.dataTaskPublisher(for: weatherURL)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                    throw AppError(type: .weather(.badResponse))
                }
                return data
            }
            .decode(type: OpenWeatherResponse.self, decoder: JSONDecoder())
            .map { response in
                WeatherData(temperature: response.main.temp, description: response.weather.first?.description ?? "No description", cityName: response.name)
            }
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    let appError = (error as? AppError) ?? AppError(type: .weather(.badResponse), underlyingError: error)
                    self?.alertError = appError
                    self?.logger.error("Failed to fetch weather: \(appError.localizedDescription, privacy: .public)")
                }
            }, receiveValue: { [weak self] weatherData in
                self?.weather = weatherData
            })
            .store(in: &cancellables)
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
