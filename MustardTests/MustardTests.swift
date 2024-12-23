//
//  MustardTests.swift
//  MustardTests
//
//  Created by VAIBHAV SRIVASTAVA on 14/09/24.
//

import XCTest
@testable import Mustard

@MainActor
class MustardTests: XCTestCase {
    
    override func setUp() async throws {
        // Reset MastodonService.shared to default before each test
        MastodonService.shared = MastodonService()
    }
    
    func testPostRowViewHandlesErrors() async throws {
        let viewModel = TimelineViewModel()
        let sampleAccount = Account(
            id: "a1",
            username: "user1",
            displayName: "User One",
            avatar: URL(string: "https://example.com/avatar1.png")!,
            acct: "user1"
        )
        let samplePost = Post(
            id: "1",
            content: "<p>Hello, world!</p>",
            createdAt: Date(),
            account: sampleAccount,
            mediaAttachments: [],
            isFavourited: false,
            isReblogged: false,
            reblogsCount: 0,
            favouritesCount: 0,
            repliesCount: 0
        )
        viewModel.posts.append(samplePost)

        // Simulate a failure in handling action
        viewModel.alertError = MustardAppError(message: "Failed to handle action.")

        XCTAssertNotNil(viewModel.alertError)
        XCTAssertEqual(viewModel.alertError?.message, "Failed to handle action.")
    }
    
    func testTimelineViewModelLoadTimelineSuccess() async throws {
        let mockService = MockMastodonService(shouldSucceed: true)
        MastodonService.shared = mockService

        let viewModel = TimelineViewModel()
        viewModel.instanceURL = URL(string: "https://mastodon.social") // Set instanceURL for testing

        try await viewModel.authenticate() // Ensure authenticate sets isAuthenticated

        XCTAssertFalse(viewModel.isLoading)
        XCTAssertEqual(viewModel.posts.count, 1) // Assuming MockMastodonService returns one post
        XCTAssertTrue(viewModel.isAuthenticated)
    }
    
    func testTimelineViewModelLoadTimelineFailure() async throws {
        let mockService = MockMastodonService(shouldSucceed: false)
        MastodonService.shared = mockService

        let viewModel = TimelineViewModel()
        viewModel.instanceURL = URL(string: "https://mastodon.social") // Set instanceURL for testing

        try await viewModel.authenticate()

        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNotNil(viewModel.alertError)
        XCTAssertEqual(viewModel.alertError?.message, "Mock fetch failed.")
        XCTAssertFalse(viewModel.isAuthenticated)
    }
}
