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
class TimelineViewModel: ObservableObject {
    @Published var posts: [Post] = []
    @Published var topPosts: [Post] = []
    @Published var weather: WeatherData?
    @Published var isLoading = false
    @Published var isFetchingMore = false
    @Published var alertError: AppError?

    private let timelineService: TimelineService
    private var cancellables = Set<AnyCancellable>()

    init(timelineService: TimelineService) {
        self.timelineService = timelineService
        setupSubscriptions()
    }

    private func setupSubscriptions() {
        timelineService.timelinePostsPublisher
            .sink { [weak self] posts in
                self?.posts = posts
            }
            .store(in: &cancellables)

        timelineService.weatherPublisher
            .sink { [weak self] weather in
                self?.weather = weather
            }
            .store(in: &cancellables)

        timelineService.isLoadingPublisher
            .sink { [weak self] isLoading in
                self?.isLoading = isLoading
            }
            .store(in: &cancellables)

        timelineService.isFetchingMorePublisher
            .sink { [weak self] isFetchingMore in
                self?.isFetchingMore = isFetchingMore
            }
            .store(in: &cancellables)

        timelineService.errorPublisher
            .sink { [weak self] error in
                self?.alertError = error
            }
            .store(in: &cancellables)
    }

    func initializeData() async {
        timelineService.initializeTimelineData()
    }

    func fetchMoreTimeline() {
        timelineService.fetchMoreTimelinePosts()
    }

    func refreshTimeline() {
        timelineService.refreshTimeline()
    }

    // Fetch top posts from TimelineService
    func fetchTopPosts() async {
        await timelineService.fetchTopPosts()
    }

    // Fetch weather from TimelineService
    func fetchWeather(for location: CLLocation) async {
         await timelineService.fetchWeather(for: location)
    }

    func toggleLike(on post: Post) async {
        do {
            try await timelineService.toggleLike(for: post)
        } catch {
            alertError = AppError(message: "Failed to toggle like", underlyingError: error)
        }
    }

    func toggleRepost(on post: Post) async {
        do {
            try await timelineService.toggleRepost(for: post)
        } catch {
            alertError = AppError(message: "Failed to toggle repost", underlyingError: error)
        }
    }

    func comment(on post: Post, content: String) async {
        do {
            try await timelineService.comment(on: post, content: content)
        } catch {
            alertError = AppError(message: "Failed to comment", underlyingError: error)
        }
    }
}



