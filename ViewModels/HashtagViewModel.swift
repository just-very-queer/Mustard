//
//  HashtagViewModel.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 19/02/25.
//

import Combine
import SwiftUI

class HashtagViewModel: ObservableObject {
    @Published var posts: [Post] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private let searchService: SearchService // Inject SearchService
    private var cancellables = Set<AnyCancellable>()

     init(searchService: SearchService = SearchService) {
          self.searchService = searchService
      }

    @MainActor
    func fetchPosts(for hashtag: String) async {
        guard !isLoading else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            // Use the injected searchService to fetch posts
            posts = try await searchService.fetchHashtagPosts(hashtag: hashtag)
        } catch {
            self.error = error  // No need to wrap in IdentifiableError here (it's handled in HashtagAnalyticsView)
            posts = []
        }
    }
}
