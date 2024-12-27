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

    /// Tests that the PostRowView handles errors correctly.
    func testPostRowViewHandlesErrors() async throws {
        let mockService = MockMastodonService(shouldSucceed: false)
        let viewModel = TimelineViewModel(mastodonService: mockService)
        
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

        // Simulate an error
        viewModel.alertError = AppError(message: "Failed to handle action.")

        XCTAssertNotNil(viewModel.alertError)
        XCTAssertEqual(viewModel.alertError?.message, "Failed to handle action.")
    }

    /// Tests that the TimelineViewModel successfully loads the timeline.
    func testTimelineViewModelLoadTimelineSuccess() async throws {
        let mockService = MockMastodonService(shouldSucceed: true)
        let viewModel = TimelineViewModel(mastodonService: mockService)
        viewModel.mastodonService.baseURL = URL(string: "https://mastodon.social")
        mockService.accessToken = "testToken"

        await viewModel.fetchTimeline()
        
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertEqual(viewModel.posts.count, 1)
        XCTAssertEqual(viewModel.posts.first?.id, "1")
    }

    /// Tests that the TimelineViewModel handles timeline loading failures.
    func testTimelineViewModelLoadTimelineFailure() async throws {
        let mockService = MockMastodonService(shouldSucceed: false)
        let viewModel = TimelineViewModel(mastodonService: mockService)
        viewModel.mastodonService.baseURL = URL(string: "https://mastodon.social")
        mockService.accessToken = "testToken"

        await viewModel.fetchTimeline()

        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNotNil(viewModel.alertError)
        XCTAssertEqual(viewModel.alertError?.message, "Mock service error.")
        XCTAssertTrue(viewModel.posts.isEmpty)
    }
}

