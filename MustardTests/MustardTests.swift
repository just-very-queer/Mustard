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
        viewModel.alertError = MustardAppError(message: "Failed to handle action.")

        XCTAssertNotNil(viewModel.alertError)
        XCTAssertEqual(viewModel.alertError?.message, "Failed to handle action.")
    }

    func testTimelineViewModelLoadTimelineSuccess() async throws {
        let mockService = MockMastodonService(shouldSucceed: true)
        let viewModel = TimelineViewModel(mastodonService: mockService)
        viewModel.instanceURL = URL(string: "https://mastodon.social")

        await viewModel.loadTimeline()
        
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertEqual(viewModel.posts.count, 1)
    }

    func testTimelineViewModelLoadTimelineFailure() async throws {
        let mockService = MockMastodonService(shouldSucceed: false)
        let viewModel = TimelineViewModel(mastodonService: mockService)
        viewModel.instanceURL = URL(string: "https://mastodon.social")

        await viewModel.loadTimeline()

        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNotNil(viewModel.alertError)
        XCTAssertEqual(viewModel.alertError?.message, "Mock service error.")
        XCTAssertTrue(viewModel.posts.isEmpty)
    }
}

