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
    @Published var posts: [Post] = []
    @Published var topPosts: [Post] = []
    @Published var weather: WeatherData?
    @Published var isLoading = false
    @Published var isFetchingMore = false
    @Published var alertError: AppError?

    private let timelineService: TimelineService
    private let trendingService: TrendingService
    private let postActionService: PostActionService
    private let locationManager: LocationManager
    private var cancellables = Set<AnyCancellable>()
    private let logger = Logger(subsystem: "com.yourcompany.Mustard", category: "TimelineViewModel")
    private let weatherAPIKeyBase64 = "OTk2NTdjOTNhN2E5M2JlYTJkZTdiZjkzZTMyMTkxMDQy=" //

    private var weatherFetchTask: Task<Void, Never>?
    private var weatherFetchOnce: Bool = false
    private let cacheService: CacheService
    private let networkService: NetworkService
    private let cacheKey = "timeline"

    init(timelineService: TimelineService,cacheService: CacheService, networkService: NetworkService ,trendingService: TrendingService, postActionService: PostActionService, locationManager: LocationManager) {
        self.timelineService = timelineService
        self.trendingService = trendingService
        self.postActionService = postActionService
        self.cacheService = cacheService
        self.networkService = networkService
        self.locationManager = locationManager
        setupSubscriptions()
        
    }

    private func setupSubscriptions() {
        // Subscribe to authentication success
        NotificationCenter.default.publisher(for: .didAuthenticate)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task {
                    await self?.initializeData()
                }
            }
            .store(in: &cancellables)

        // Subscribe to location updates
        locationManager.locationPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] location in
                guard let self = self, !self.weatherFetchOnce else { return }
                Task {
                    await self.fetchWeather(for: location)
                }
            }
            .store(in: &cancellables)
    }

    func initializeData() async {
        // Fetch data sequentially
        await fetchTimeline(useCache: false)
        await fetchTopPosts()

        // Fetch weather once during initialization
        if let location = self.locationManager.userLocation, !self.weatherFetchOnce {
            await self.fetchWeather(for: location)
            self.weatherFetchOnce = true
        }
    }
    
    /// Fetch the timeline
    func fetchTimeline(useCache: Bool = true) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        
        let cacheKey = "timeline"

        if useCache {
            do {
                // Attempt to load posts from the cache
                let cachedPosts = try await cacheService.loadPostsFromCache(forKey: cacheKey)
                
                // Perform a background refresh of the timeline
                Task {
                    await backgroundRefreshTimeline()
                }
                
                // Update the `posts` with cached data and exit
                posts = cachedPosts
                return
            } catch let error as AppError {
                // Handle specific cache errors
                if case .mastodon(.cacheNotFound) = error.type {
                    logger.info("Timeline cache not found on disk. Fetching from network.")
                } else {
                    logger.error("Error loading timeline from cache: \(error.localizedDescription)")
                    handleError(error)
                    return
                }
            } catch {
                // Handle other cache errors
                logger.error("Error loading timeline from cache: \(error.localizedDescription)")
                handleError(error)
                return
            }
        }

        // Fetch from the network if cache is not used or not found
        do {
            // Fetch base URL and access token for debugging
            let baseURL = try await KeychainHelper.shared.read(service: "MustardKeychain", account: "baseURL")
            let accessToken = try await KeychainHelper.shared.read(service: "MustardKeychain", account: "accessToken")
            logger.debug("Using baseURL: \(baseURL ?? "nil")")
            logger.debug("Using accessToken: \(accessToken ?? "nil")")
            
            // Construct the API endpoint and fetch the timeline
            let url = try await networkService.endpointURL("/api/v1/timelines/home")
            let fetchedPosts = try await networkService.fetchData(url: url, method: "GET", type: [Post].self)
            
            // Cache the fetched posts in a background task
            Task {
                await cacheService.cachePosts(fetchedPosts, forKey: cacheKey)
            }
            
            // Update the `posts` with the fetched data
            posts = fetchedPosts
        } catch {
            // Handle network fetch errors
            logger.error("Failed to fetch timeline: \(error.localizedDescription)")
            handleError(error)
        }
    }
    /// Background refresh of the timeline
        private func backgroundRefreshTimeline() async {
            do {
                let url = try await networkService.endpointURL("/api/v1/timelines/home")
                let fetchedPosts = try await networkService.fetchData(url: url, method: "GET", type: [Post].self)

                // Cache the fetched posts in a background task
                Task {
                    await cacheService.cachePosts(fetchedPosts, forKey: cacheKey)
                }

                // Update the `posts` on the main actor
                await MainActor.run {
                    self.posts = fetchedPosts
                }
            } catch {
                logger.error("Failed to refresh timeline: \(error.localizedDescription)")
            }
        }
    
    func fetchMoreTimeline() async {
        guard !isFetchingMore else { return }
        isFetchingMore = true
        defer { isFetchingMore = false }

        do {
            let newPosts = try await timelineService.fetchMoreTimeline(page: (posts.count / 20) + 1)
            if !newPosts.isEmpty {
                posts.append(contentsOf: newPosts)
            }
        } catch {
            handleError(error)
        }
    }

    func fetchTopPosts() async {
        do {
            topPosts = try await trendingService.fetchTrendingPosts()
        } catch {
            handleError(error)
        }
    }

    func fetchWeather(for location: CLLocation) async {
        // Cancel any ongoing fetch tasks
        weatherFetchTask?.cancel()

        weatherFetchTask = Task { [weak self] in
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
                guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                    let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                    let errorDescription = HTTPURLResponse.localizedString(forStatusCode: statusCode)
                    logger.error("Weather API Error: \(statusCode) - \(errorDescription)")
                    throw AppError(
                        type: .weather(.badResponse),
                        underlyingError: NSError(
                            domain: "HTTPError",
                            code: statusCode,
                            userInfo: [NSLocalizedDescriptionKey: errorDescription]
                        )
                    )
                }

                // Decode the weather response
                let weatherResponse = try JSONDecoder().decode(OpenWeatherResponse.self, from: data)
                let weatherData = WeatherData(
                    temperature: weatherResponse.main.temp,
                    description: weatherResponse.weather.first?.description ?? "No description",
                    cityName: weatherResponse.name
                )

                // Update the weather on the main thread
                await MainActor.run {
                    self.weather = weatherData
                }

            } catch {
                // Handle decoding or network errors
                logger.error("Weather fetch failed: \(error.localizedDescription, privacy: .public)")
                await MainActor.run {
                    if let appError = error as? AppError {
                        self.alertError = appError
                    } else {
                        self.alertError = AppError(type: .weather(.badResponse), underlyingError: error)
                    }
                }
            }
        }
    }

    func toggleLike(on post: Post) async {
        do {
            try await postActionService.toggleLike(postID: post.id)
            if let index = posts.firstIndex(where: { $0.id == post.id }) {
                posts[index].isFavourited.toggle()
                posts[index].favouritesCount += posts[index].isFavourited ? 1 : -1
            }
        } catch {
            handleError(error)
        }
    }

    func toggleRepost(on post: Post) async {
        do {
            try await postActionService.toggleRepost(postID: post.id)
            if let index = posts.firstIndex(where: { $0.id == post.id }) {
                posts[index].isReblogged.toggle()
                posts[index].reblogsCount += posts[index].isReblogged ? 1 : -1
            }
        } catch {
            handleError(error)
        }
    }

    func comment(on post: Post, content: String) async throws {
        do {
            try await postActionService.comment(postID: post.id, content: content)
            if let index = posts.firstIndex(where: { $0.id == post.id }) {
                posts[index].repliesCount += 1
            }
        } catch {
            handleError(error)
            throw error
        }
    }

    private func handleError(_ error: Error) {
        if let appError = error as? AppError {
            alertError = appError
        } else {
            alertError = AppError(type: .generic("An error occurred."), underlyingError: error)
        }
    }

    private func decodeAPIKey(_ base64Key: String) -> String? {
        guard let data = Data(base64Encoded: base64Key) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

