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

@MainActor
final class TimelineViewModel: ObservableObject {
    @Published var posts: [Post] = []
    @Published var topPosts: [Post] = []
    @Published var weather: WeatherData?
    @Published var isFetchingMore = false
    @Published var alertError: AppError?
    
    @Published private(set) var postLoadingStates: [String: Bool] = [:] {
        didSet { objectWillChange.send() }
    }
    
    private var _isLoading: Bool = false
    var isLoading: Bool {
        get { return _isLoading }
        set { _isLoading = newValue }
    }
    
    private let timelineService: TimelineService
    private let weatherService: WeatherService
    private let locationManager: LocationManager
    private let trendingService: TrendingService
    let postActionService: PostActionService
    private var cancellables = Set<AnyCancellable>()
    private var weatherFetchOnce = false
    private var currentPage = 0
    
    init(timelineService: TimelineService, weatherService: WeatherService, locationManager: LocationManager, trendingService: TrendingService, postActionService: PostActionService) {
        self.timelineService = timelineService
        self.weatherService = weatherService
        self.locationManager = locationManager
        self.trendingService = trendingService
        self.postActionService = postActionService
        setupSubscriptions()
        setupLocationListener()
    }
    
    // MARK: - Setup Subscriptions
    private func setupSubscriptions() {
        timelineService.timelinePostsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] posts in
                guard let self = self else { return }
                self.posts = posts
                var newStates = self.postLoadingStates
                for post in posts where newStates[post.id] == nil {
                    newStates[post.id] = false
                }
                self.postLoadingStates = newStates
            }
            .store(in: &cancellables)
        
        timelineService.isLoadingPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: \.isLoading, on: self)
            .store(in: &cancellables)
        
        timelineService.isFetchingMorePublisher
            .receive(on: DispatchQueue.main)
            .assign(to: \.isFetchingMore, on: self)
            .store(in: &cancellables)
        
        timelineService.errorPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.alertError = error
            }
            .store(in: &cancellables)
        
        weatherService.$weather
            .receive(on: DispatchQueue.main)
            .assign(to: \.weather, on: self)
            .store(in: &cancellables)
        
        weatherService.$error
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                if let error = error, error.isRecoverable {
                    self?.alertError = error
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Location Listener
    private func setupLocationListener() {
        locationManager.locationPublisher
            .debounce(for: .seconds(10), scheduler: DispatchQueue.main)
            .sink { [weak self] location in
                guard let self = self, !self.weatherFetchOnce else { return }
                Task {
                    await self.weatherService.fetchWeather(for: location)
                    self.weatherFetchOnce = true
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Fetch Data
    func initializeData() async {
        timelineService.initializeTimelineData()
    }
    
    func fetchMoreTimeline() {
        guard !isFetchingMore else { return }
        isFetchingMore = true
        
        Task {
            let newPosts = await fetchPosts(page: currentPage + 1)
            DispatchQueue.main.async {
                self.posts.append(contentsOf: newPosts)
                self.currentPage += 1
                self.isFetchingMore = false
            }
        }
    }
    
    func refreshTimeline() {
        timelineService.refreshTimeline()
    }
    
    func fetchTopPosts() async {
        await timelineService.fetchTopPosts()
    }
    
    func fetchWeather(for location: CLLocation) async {
        await weatherService.fetchWeather(for: location)
    }
    
    func fetchPosts(page: Int) async -> [Post] {
        return await timelineService.fetchPosts(page: page)
    }
    
    // MARK: - Post Actions
    func likePost(_ post: Post) async {
        updateLoadingState(for: post.id, isLoading: true)
        defer { updateLoadingState(for: post.id, isLoading: false) }
        
        do {
            try await timelineService.toggleLike(for: post)
        } catch {
            alertError = AppError(message: "Failed to like the post", underlyingError: error)
        }
    }
    
    func repostPost(_ post: Post) async {
        updateLoadingState(for: post.id, isLoading: true)
        defer { updateLoadingState(for: post.id, isLoading: false) }
        
        do {
            try await timelineService.toggleRepost(for: post)
        } catch {
            alertError = AppError(message: "Failed to repost the post", underlyingError: error)
        }
    }
    
    func comment(on post: Post, content: String) async {
        updateLoadingState(for: post.id, isLoading: true)
        defer { updateLoadingState(for: post.id, isLoading: false) }
        
        do {
            try await timelineService.comment(on: post, content: content)
            
            await MainActor.run {
                let newComment = Post(
                    id: UUID().uuidString,
                    content: content,
                    createdAt: Date(),
                    account: authAccount(),
                    mediaAttachments: [],
                    isFavourited: false,
                    isReblogged: false,
                    reblogsCount: 0,
                    favouritesCount: 0,
                    repliesCount: 0,
                    mentions: nil
                )
                
                if let index = posts.firstIndex(where: { $0.id == post.id }) {
                    posts[index].replies?.append(newComment)
                    posts[index].repliesCount += 1
                }
            }
        } catch {
            alertError = AppError(message: "Failed to comment", underlyingError: error)
        }
    }
    
    func toggleLike(on post: Post) async {
        updateLoadingState(for: post.id, isLoading: true)
        defer { updateLoadingState(for: post.id, isLoading: false) }
        
        do {
            try await timelineService.toggleLike(for: post)
        } catch {
            alertError = AppError(message: "Failed to toggle like", underlyingError: error)
        }
    }
    
    func toggleRepost(on post: Post) async {
        updateLoadingState(for: post.id, isLoading: true)
        defer { updateLoadingState(for: post.id, isLoading: false) }
        
        do {
            try await timelineService.toggleRepost(for: post)
        } catch {
            alertError = AppError(message: "Failed to toggle repost", underlyingError: error)
        }
    }
    
    // MARK: - Search and Trending
    func search(query: String, type: String?, limit: Int?, resolve: Bool?, excludeUnreviewed: Bool?) async throws -> SearchResults {
        guard let baseURLString = try? await KeychainHelper.shared.read(service: "MustardKeychain", account: "baseURL"),
              let baseURL = URL(string: baseURLString) else {
            throw AppError(message: "Base URL not found")
        }
        
        var components = URLComponents(url: baseURL.appendingPathComponent("/api/v2/search"), resolvingAgainstBaseURL: false)!
        var queryItems = [URLQueryItem(name: "q", value: query)]
        
        if let type = type {
            queryItems.append(URLQueryItem(name: "type", value: type))
        }
        if let limit = limit {
            queryItems.append(URLQueryItem(name: "limit", value: String(limit)))
        }
        if let resolve = resolve {
            queryItems.append(URLQueryItem(name: "resolve", value: String(resolve)))
        }
        if let excludeUnreviewed = excludeUnreviewed {
            queryItems.append(URLQueryItem(name: "exclude_unreviewed", value: String(excludeUnreviewed)))
        }
        
        components.queryItems = queryItems
        
        guard let url = components.url else {
            throw AppError(message: "Invalid search URL")
        }
        
        return try await NetworkService.shared.fetchData(url: url, method: "GET", type: SearchResults.self)
    }
    
    func fetchTrendingHashtags() async throws -> [Tag] {
        guard let baseURLString = try? await KeychainHelper.shared.read(service: "MustardKeychain", account: "baseURL"),
              let baseURL = URL(string: baseURLString) else {
            throw AppError(message: "Base URL not found")
        }
        
        let endpoint = "/api/v1/trends/tags"
        let url = baseURL.appendingPathComponent(endpoint)
        
        do {
            let tags = try await NetworkService.shared.fetchData(url: url, method: "GET", type: [Tag].self)
            return tags
        } catch {
            throw AppError(message: "Failed to fetch trending hashtags", underlyingError: error)
        }
    }
    
    func followHashtag(_ hashtag: String) async throws {
        let encodedHashtag = hashtag.trimmingCharacters(in: .whitespacesAndNewlines).addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)
        guard let encodedHashtagName = encodedHashtag else {
            throw AppError(message: "Invalid hashtag format.")
        }
        
        let endpoint = "/api/v1/tags/\(encodedHashtagName)/follow"
        
        do {
            _ = try await NetworkService.shared.request(endpoint: endpoint, method: .post, responseType: EmptyResponse.self)
            print("Successfully followed hashtag: \(hashtag)")
        } catch {
            if let appError = error as? AppError {
                self.alertError = appError
            } else {
                self.alertError = AppError(message: "Failed to follow hashtag: \(hashtag)", underlyingError: error)
            }
        }
    }
    
    // MARK: - Loading State Helper
    private func updateLoadingState(for postId: String, isLoading: Bool) {
        var newStates = postLoadingStates
        newStates[postId] = isLoading
        postLoadingStates = newStates
    }
    
    func isLoading(for post: Post) -> Bool {
        return postLoadingStates[post.id] ?? false
    }
    
    // MARK: - Private account helper
    private func authAccount() -> Account? {
        return Account(
            id: "current-user-id",
            username: "currentUsername",
            display_name: "Current User",
            avatar: nil,
            acct: "current-user-acct",
            url: nil,
            accessToken: nil,
            followers_count: 0,
            following_count: 0,
            statuses_count: 0,
            last_status_at: nil,
            isBot: false,
            isLocked: false,
            note: nil,
            header: nil,
            header_static: nil,
            discoverable: false,
            indexable: false,
            suspended: false
        )
    }
}

// MARK: - SearchResults
struct SearchResults: Decodable {
    var accounts: [Account]
    var statuses: [Post]
    var hashtags: [Tag]
}

// MARK: - Empty Response
private struct EmptyResponse: Decodable {}
