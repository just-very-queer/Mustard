//
//  HashtagViewModel.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 19/02/25.
//

import Combine
import SwiftUI

@MainActor
class HashtagViewModel: ObservableObject {
    @Published var posts: [Post] = []
    @Published var isLoading = false
    @Published var error: Error?

    private let searchService: SearchService
    private var cancellables = Set<AnyCancellable>()

    @MainActor
    init(searchService: SearchService) {
        self.searchService = searchService
    }

    // Async convenience initializer to get main actor-isolated service
    static func create() async -> HashtagViewModel {
        let service =  MustardApp.mastodonAPIServiceInstance
        return HashtagViewModel(searchService: SearchService(mastodonAPIService: service))
    }

    @MainActor
    func fetchPosts(for hashtag: String) async {
        guard !isLoading else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            posts = try await searchService.fetchHashtagPosts(hashtag: hashtag)
        } catch {
            self.error = error
            posts = []
        }
    }
}

