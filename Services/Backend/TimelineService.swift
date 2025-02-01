//
//  TimelineService.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 24/01/25.
//

import Foundation
import OSLog
import CoreLocation
import Combine

class TimelineService {
    private let networkService: NetworkService
    private let cacheService: CacheService
    private let postActionService: PostActionService
    private let locationManager: LocationManager
    private let trendingService: TrendingService
    private let logger = Logger(subsystem: "titan.mustard.app.ao", category: "TimelineService")
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Publishers
    @Published private(set) var timelinePosts: [Post] = []
    var timelinePostsPublisher: Published<[Post]>.Publisher { $timelinePosts }

    @Published private(set) var weather: WeatherData?
    var weatherPublisher: Published<WeatherData?>.Publisher { $weather }

    @Published private(set) var isLoading: Bool = false
    var isLoadingPublisher: Published<Bool>.Publisher { $isLoading }

    @Published private(set) var isFetchingMore: Bool = false
    var isFetchingMorePublisher: Published<Bool>.Publisher { $isFetchingMore }

    @Published private(set) var error: AppError?
    var errorPublisher: Published<AppError?>.Publisher { $error }
    
    @Published private(set) var topPosts: [Post] = []  // Make sure this is a property and not a method

    private let weatherAPIKeyBase64 = "OTk2NTdjOTNhN2E5M2JlYTJkZTdiZjkzZTMyMTkxMDQy="
    private var weatherFetchOnce: Bool = false

    init(networkService: NetworkService,
            cacheService: CacheService,
            postActionService: PostActionService,
            locationManager: LocationManager,
            trendingService: TrendingService) { // Add TrendingService type here

           self.networkService = networkService
           self.cacheService = cacheService
           self.postActionService = postActionService
           self.locationManager = locationManager
           self.trendingService = trendingService

           setupLocationListener()
       }

    // MARK: - Location Listener
    private func setupLocationListener() {
        locationManager.locationPublisher
            .debounce(for: .seconds(10), scheduler: DispatchQueue.main)
            .sink { [weak self] location in
                guard let self = self, !self.weatherFetchOnce else { return }
                Task { await self.fetchWeather(for: location) }
            }
            .store(in: &cancellables)
    }

    // MARK: - Timeline Data Methods
    func initializeTimelineData() {
        isLoading = true
        Task {
            do {
                let posts = try await fetchTimeline(useCache: true)
                await MainActor.run {
                    self.timelinePosts = posts
                    self.isLoading = false
                }
                if let location = locationManager.userLocation, !weatherFetchOnce {
                    await fetchWeather(for: location)
                    weatherFetchOnce = true
                }
            } catch {
                await MainActor.run {
                    self.error = error as? AppError ?? AppError(message: "Failed to initialize timeline data.", underlyingError: error)
                    self.isLoading = false
                }
            }
        }
    }

    func fetchMoreTimelinePosts() {
        guard !isFetchingMore else { return }
        isFetchingMore = true
        let nextPage = (timelinePosts.count / 20) + 1
        Task {
            do {
                let newPosts = try await fetchMoreTimeline(page: nextPage)
                await MainActor.run {
                    if !newPosts.isEmpty {
                        self.timelinePosts.append(contentsOf: newPosts)
                    }
                    self.isFetchingMore = false
                }
            } catch {
                await MainActor.run {
                    self.error = error as? AppError ?? AppError(message: "Failed to fetch more timeline posts.", underlyingError: error)
                    self.isFetchingMore = false
                }
            }
        }
    }

    func refreshTimeline() {
        Task {
            do {
                let posts = try await fetchTimeline(useCache: false)
                await MainActor.run {
                    self.timelinePosts = posts
                }
            } catch {
                await MainActor.run {
                    self.error = error as? AppError ?? AppError(message: "Failed to refresh timeline.", underlyingError: error)
                }
            }
        }
    }

    // MARK: - Network Operations
    func fetchTimeline(useCache: Bool) async throws -> [Post] {
        let cacheKey = "timeline"

        if useCache {
            do {
                let cachedPosts = try await cacheService.loadPostsFromCache(forKey: cacheKey)
                Task { try await backgroundRefreshTimeline() }
                return cachedPosts
            } catch let error as AppError {
                if case .mastodon(.cacheNotFound) = error.type {
                    logger.info("Timeline cache not found. Fetching from network.")
                } else {
                    logger.error("Cache error: \(error.localizedDescription)")
                    throw error
                }
            }
        }

        do {
            let url = try await NetworkService.shared.endpointURL("/api/v1/timelines/home")
            let fetchedPosts = try await networkService.fetchData(url: url, method: "GET", type: [Post].self)
            Task { await cacheService.cachePosts(fetchedPosts, forKey: cacheKey) }
            return fetchedPosts
        } catch {
            logger.error("Network error: \(error.localizedDescription)")
            throw error
        }
    }

    func fetchMoreTimeline(page: Int) async throws -> [Post] {
        var endpoint = "/api/v1/timelines/home"
        if page > 1 {
            do {
                let cachedPosts = try await cacheService.loadPostsFromCache(forKey: "timeline")
                if let lastID = cachedPosts.last?.id {
                    endpoint += "?max_id=\(lastID)"
                }
            } catch {
                logger.error("Cache error: \(error.localizedDescription)")
            }
        }

        let url = try await NetworkService.shared.endpointURL(endpoint)
        let fetchedPosts = try await networkService.fetchData(url: url, method: "GET", type: [Post].self)

        if !fetchedPosts.isEmpty {
            Task {
                do {
                    let updatedPosts = (try await cacheService.loadPostsFromCache(forKey: "timeline")) + fetchedPosts
                    await cacheService.cachePosts(updatedPosts, forKey: "timeline")
                } catch {
                    logger.error("Cache update error: \(error.localizedDescription)")
                }
            }
        }
        return fetchedPosts
    }

    func backgroundRefreshTimeline() async throws {
        do {
            let url = try await NetworkService.shared.endpointURL("/api/v1/timelines/home")
            let fetchedPosts = try await networkService.fetchData(url: url, method: "GET", type: [Post].self)
            Task { await cacheService.cachePosts(fetchedPosts, forKey: "timeline") }
        } catch {
            logger.error("Background refresh failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Weather Implementation
    func fetchWeather(for location: CLLocation) async {
        guard let apiKey = decodeAPIKey(weatherAPIKeyBase64) else {
            await handleWeatherError(.weather(.invalidKey))
            return
        }

        let urlString = "https://api.openweathermap.org/data/2.5/weather?lat=\(location.coordinate.latitude)&lon=\(location.coordinate.longitude)&units=metric&appid=\(apiKey)"
        guard let url = URL(string: urlString) else {
            await handleWeatherError(.weather(.invalidURL))
            return
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                let errorDescription = HTTPURLResponse.localizedString(forStatusCode: statusCode)
                throw AppError(type: .weather(.badResponse),
                             underlyingError: NSError(domain: "HTTPError", code: statusCode,
                                                    userInfo: [NSLocalizedDescriptionKey: errorDescription]))
            }

            let weatherResponse = try JSONDecoder().decode(OpenWeatherResponse.self, from: data)
            let weatherData = WeatherData(
                temperature: weatherResponse.main.temp,
                description: weatherResponse.weather.first?.description ?? "Clear",
                cityName: weatherResponse.name
            )
            
            await MainActor.run { self.weather = weatherData }
        } catch {
            logger.error("Weather fetch failed: \(error.localizedDescription)")
            await handleWeatherError(.weather(.badResponse), error: error)
        }
    }

    private func handleWeatherError(_ type: AppError.ErrorType, error: Error? = nil) async {
        await MainActor.run {
            self.error = AppError(type: type, underlyingError: error)
        }
    }

    // MARK: - Utility Methods
    private func decodeAPIKey(_ base64Key: String) -> String? {
        guard let data = Data(base64Encoded: base64Key) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - Post Actions
    func toggleLike(for post: Post) async throws {
        try await postActionService.toggleLike(postID: post.id)
        await updatePostInteraction(for: post.id) { post in
            post.isFavourited.toggle()
            post.favouritesCount += post.isFavourited ? 1 : -1
        }
    }

    func toggleRepost(for post: Post) async throws {
        try await postActionService.toggleRepost(postID: post.id)
        await updatePostInteraction(for: post.id) { post in
            post.isReblogged.toggle()
            post.reblogsCount += post.isReblogged ? 1 : -1
        }
    }

    func comment(on post: Post, content: String) async throws {
        try await postActionService.comment(postID: post.id, content: content)
        await MainActor.run {
            if let index = timelinePosts.firstIndex(where: { $0.id == post.id }) {
                timelinePosts[index].repliesCount += 1
            }
        }
    }
    
    func fetchTopPosts() async {
        do {
            // Call the TrendingService to fetch the top (trending) posts
            let trendingPosts = try await trendingService.fetchTopPosts()  // Call the fetchTopPosts method from TrendingService
            
            // Once the posts are fetched, update the topPosts property
            await MainActor.run {
                self.topPosts = trendingPosts  // Update the topPosts property
            }
        } catch {
            // Handle the error gracefully and log it
            logger.error("Failed to fetch top posts: \(error.localizedDescription)")
            await MainActor.run {
                self.error = AppError(message: "Failed to fetch top posts", underlyingError: error)
            }
        }
    }

    private func updatePostInteraction(for postID: String, update: (inout Post) -> Void) async {
        await MainActor.run {
            if let index = timelinePosts.firstIndex(where: { $0.id == postID }) {
                var post = timelinePosts[index]
                update(&post)
                timelinePosts[index] = post
            }
        }
    }
}

