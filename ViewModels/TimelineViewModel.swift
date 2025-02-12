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
class TimelineViewModel: ObservableObject, @preconcurrency TimelineSchedule { // Conform to TimelineSchedule, remove @preconcurrency
    @Published var posts: [Post] = []
    @Published var topPosts: [Post] = []
    @Published var weather: WeatherData?
    @Published var isFetchingMore = false
    @Published var alertError: AppError?

    private var _isLoading: Bool = false  // Backing stored property
    var isLoading: Bool {   // Computed property
        get { return _isLoading }
        set { _isLoading = newValue }
    }

    private let timelineService: TimelineService
    private let weatherService: WeatherService
    private let locationManager: LocationManager
    private var cancellables = Set<AnyCancellable>()
    private var weatherFetchOnce: Bool = false

    // Conforming to the TimelineSchedule protocol
    //No need for this as it's already defined in the protocal, we only need to define it once

    //    var timelinePosts: [Post] {
    //        get { return posts }
    //        set { posts = newValue }
    //    }
    //
    //    var error: AppError? {
    //        get { return alertError }
    //        set { alertError = newValue }
    //    }

    init(timelineService: TimelineService, weatherService: WeatherService, locationManager: LocationManager) {
        self.timelineService = timelineService
        self.weatherService = weatherService
        self.locationManager = locationManager
        setupSubscriptions()
        setupLocationListener()
    }

    private func setupSubscriptions() {
        timelineService.timelinePostsPublisher
            .sink { [weak self] posts in
                self?.posts = posts
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

        weatherService.$weather
            .receive(on: RunLoop.main)
            .sink { [weak self] weather in
                self?.weather = weather
            }
            .store(in: &cancellables)

        weatherService.$error
            .receive(on: RunLoop.main)
            .sink { [weak self] error in
                if let error = error, error.isRecoverable {
                    self?.alertError = error
                }
            }
            .store(in: &cancellables)
    }

    private func setupLocationListener() {
        locationManager.locationPublisher
            .debounce(for: .seconds(10), scheduler: DispatchQueue.main)
            .sink { [weak self] (location: CLLocation) in
                guard let self = self, !self.weatherFetchOnce else { return }
                Task {
                    await self.weatherService.fetchWeather(for: location)
                    self.weatherFetchOnce = true
                }
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

    func fetchTopPosts() async {
        await timelineService.fetchTopPosts()
    }

    func fetchWeather(for location: CLLocation) async {
        await weatherService.fetchWeather(for: location)
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


// Assuming `TimelineSchedule` is a protocol that expects these properties or similar ones

protocol TimelineSchedule: AnyObject { // Add AnyObject to require it to be a class
    var posts: [Post] { get set }  //Changed from timelinePosts to posts
    var isLoading: Bool { get set }
    var alertError: AppError? { get set } // Changed from error to alertError
}
