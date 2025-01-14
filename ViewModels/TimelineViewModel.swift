//
//  TimelineViewModel.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 30/12/24.
//

import Foundation
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
    @Published var alertError: AppError?

    // MARK: - Private Properties
    private let mastodonService: MastodonServiceProtocol
    private let authViewModel: AuthenticationViewModel
    private var cancellables = Set<AnyCancellable>()
    private let logger = Logger(subsystem: "com.yourcompany.Mustard", category: "TimelineViewModel")

    private var isFetching = false
    private var currentPage = 1
    private let weatherAPIKeyBase64 = "OTk2NTdjOTNhN2E5M2JlYTJkZTdiZjkzZTMyMTkxMDQy" // Base64-encoded API key

    // MARK: - Initialization
    init(mastodonService: MastodonServiceProtocol? = nil, authViewModel: AuthenticationViewModel) {
        self.mastodonService = mastodonService ?? MastodonService.shared
        self.authViewModel = authViewModel

        NotificationCenter.default.publisher(for: .didAuthenticate)
            .sink { [weak self] _ in Task { await self?.initializeData() } }
            .store(in: &cancellables)

        Task { await initializeData() }
    }

    // MARK: - Public Methods

    /// Fetch all necessary data on initialization or authentication
    func initializeData() async {
        guard await authViewModel.validateBaseURL() else {
            handleError("Invalid base URL", AppError(message: "Base URL validation failed."))
            return
        }

        do {
            try await mastodonService.ensureInitialized()

            guard try await isAuthenticated() else {
                handleError("Missing credentials", AppError(mastodon: .missingCredentials))
                return
            }

            logger.info("Service authenticated and initialized.")

            await fetchTimeline()
            await fetchTopPosts()
        } catch {
            handleError("Initialization failed", error)
        }
    }

    /// Fetch timeline with optional cache usage
    func fetchTimeline(useCache: Bool = true) async {
        guard !isFetching else { return }
        isFetching = true
        defer { isFetching = false }

        do {
            let fetchedPosts = try await mastodonService.fetchTimeline(useCache: useCache)
            posts = fetchedPosts.sorted(by: { $0.createdAt > $1.createdAt })
            currentPage = 1
        } catch {
            handleError("Failed to fetch timeline", AppError(mastodon: .failedToFetchTimeline))
        }
    }

    /// Fetch next page for infinite scrolling
    func fetchMoreTimeline() async {
        guard !isFetching else { return }
        isFetching = true
        defer { isFetching = false }

        do {
            let nextPagePosts = try await mastodonService.fetchTimeline(page: currentPage + 1, useCache: false)
            if !nextPagePosts.isEmpty {
                let newPosts = nextPagePosts.filter { newPost in
                    !posts.contains(where: { $0.id == newPost.id })
                }
                posts.append(contentsOf: newPosts.sorted(by: { $0.createdAt > $1.createdAt }))
                currentPage += 1
            } else {
                logger.info("No more posts available.")
            }
        } catch {
            handleError("Failed to fetch more timeline", error)
        }
    }

    /// Fetch top posts of the day
    func fetchTopPosts() async {
        do {
            topPosts = try await mastodonService.fetchTrendingPosts()
            logger.info("Successfully fetched top posts.")
        } catch {
            handleError("Failed to fetch top posts", error)
        }
    }

    /// Fetch weather data for a given location
    func fetchWeather(for location: CLLocation) {
        isLoading = true

        guard let apiKey = decodeAPIKey(weatherAPIKeyBase64) else {
            handleError("Failed to decode API key", WeatherError.invalidKey)
            isLoading = false
            return
        }

        let weatherURL = "https://api.openweathermap.org/data/2.5/weather?lat=\(location.coordinate.latitude)&lon=\(location.coordinate.longitude)&units=metric&appid=\(apiKey)"

        guard let url = URL(string: weatherURL) else {
            handleError("Invalid weather URL", WeatherError.invalidURL)
            isLoading = false
            return
        }

        URLSession.shared.dataTaskPublisher(for: url)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                    throw WeatherError.badResponse
                }
                return data
            }
            .decode(type: OpenWeatherResponse.self, decoder: JSONDecoder())
            .map { response in
                WeatherData(
                    temperature: response.main.temp,
                    description: response.weather.first?.description ?? "No description",
                    cityName: response.name
                )
            }
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] result in
                self?.isLoading = false
                if case .failure(let error) = result {
                    self?.handleError("Failed to fetch weather", error)
                }
            }, receiveValue: { [weak self] weatherData in
                self?.weather = weatherData
            })
            .store(in: &cancellables)
    }

    /// Toggle like on a post
    func toggleLike(on post: Post) async {
        do {
            try await mastodonService.toggleLike(postID: post.id)
            if let index = posts.firstIndex(where: { $0.id == post.id }) {
                posts[index].isFavourited.toggle()
                posts[index].favouritesCount += posts[index].isFavourited ? 1 : -1
            }
        } catch {
            handleError("Failed to toggle like", error)
        }
    }

    /// Toggle repost on a post
    func toggleRepost(on post: Post) async {
        do {
            try await mastodonService.toggleRepost(postID: post.id)
            if let index = posts.firstIndex(where: { $0.id == post.id }) {
                posts[index].isReblogged.toggle()
                posts[index].reblogsCount += posts[index].isReblogged ? 1 : -1
            }
        } catch {
            handleError("Failed to toggle repost", error)
        }
    }

    /// Comment on a post
    func comment(on post: Post, content: String) async throws {
        do {
            try await mastodonService.comment(postID: post.id, content: content)
            if let index = posts.firstIndex(where: { $0.id == post.id }) {
                posts[index].repliesCount += 1
            }
        } catch {
            handleError("Failed to comment", error)
            throw error
        }
    }

    // MARK: - Private Helpers

    /// Decode Base64 API key
    private func decodeAPIKey(_ base64Key: String) -> String? {
        guard let data = Data(base64Encoded: base64Key) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Check if the service is authenticated
    private func isAuthenticated() async throws -> Bool {
        guard let _ = try await mastodonService.retrieveInstanceURL(),
              let _ = try await mastodonService.retrieveAccessToken() else {
            return false
        }
        return true
    }

    /// Handle and log errors
    private func handleError(_ message: String, _ error: Error) {
        logger.error("\(message): \(error.localizedDescription)")
        if let appError = error as? AppError {
            alertError = appError
        } else {
            alertError = AppError(message: message, underlyingError: error)
        }
    }
}

// MARK: - WeatherError
enum WeatherError: Error, LocalizedError {
    case invalidKey
    case invalidURL
    case badResponse

    var errorDescription: String? {
        switch self {
        case .invalidKey: return "Invalid or missing API key."
        case .invalidURL: return "Invalid weather request URL."
        case .badResponse: return "Received bad response from the server."
        }
    }
}

// MARK: - Weather Data Model
struct WeatherData: Identifiable {
    let id = UUID()
    let temperature: Double
    let description: String
    let cityName: String
}

// MARK: - OpenWeatherResponse
struct OpenWeatherResponse: Codable {
    let main: Main
    let weather: [Weather]
    let name: String

    struct Main: Codable {
        let temp: Double
    }

    struct Weather: Codable {
        let description: String
    }
}
