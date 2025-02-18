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
    private var cancellables = Set<AnyCancellable>()
    private var weatherFetchOnce = false
    private var currentPage = 0

    init(timelineService: TimelineService, weatherService: WeatherService, locationManager: LocationManager) {
        self.timelineService = timelineService
        self.weatherService = weatherService
        self.locationManager = locationManager
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

    // Function to like a post
    func likePost(_ post: Post) async {
        updateLoadingState(for: post.id, isLoading: true)
        defer { updateLoadingState(for: post.id, isLoading: false) }

        do {
            try await timelineService.toggleLike(for: post) // Toggle like action in service
        } catch {
            alertError = AppError(message: "Failed to like the post", underlyingError: error)
        }
    }

    // Function to repost a post
    func repostPost(_ post: Post) async {
        updateLoadingState(for: post.id, isLoading: true)
        defer { updateLoadingState(for: post.id, isLoading: false) }

        do {
            try await timelineService.toggleRepost(for: post) // Toggle repost action in service
        } catch {
            alertError = AppError(message: "Failed to repost the post", underlyingError: error)
        }
    }

    // Function to comment on a post
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

    // MARK: - Post Actions
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


    // MARK: - Loading State Helper
    private func updateLoadingState(for postId: String, isLoading: Bool) {
        var newStates = postLoadingStates
        newStates[postId] = isLoading
        postLoadingStates = newStates
    }

    func isLoading(for post: Post) -> Bool {
        return postLoadingStates[post.id] ?? false
    }

    // MARK: - Private account helper (replace with your actual auth mechanism)
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
