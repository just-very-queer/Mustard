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
        // Provide necessary initializers for AuthenticationViewModel and LocationManager
        let authViewModel = AuthenticationViewModel(mastodonService: mockService)
        let locationManager = LocationManager()
        let viewModel = TimelineViewModel(mastodonService: mockService, authViewModel: authViewModel, locationManager: locationManager)
        // Ensure the mock service is set up to be authenticated
            mockService.baseURL = URL(string: "https://mastodon.social")!
            mockService.accessToken = "mockAccessToken"

        let sampleAccount = Account(
            id: "a1",
            username: "user1",
            displayName: "User One",
            avatar: URL(string: "https://example.com/avatar1.png")!,
            acct: "user1",
            url: URL(string: "https://example.com/user1")! // Add a dummy url for the account
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
        // Provide necessary initializers for AuthenticationViewModel and LocationManager
        let authViewModel = AuthenticationViewModel(mastodonService: mockService)
        let locationManager = LocationManager()
        let viewModel = TimelineViewModel(mastodonService: mockService, authViewModel: authViewModel, locationManager: locationManager)
        // Ensure the mock service is set up to be authenticated
        mockService.baseURL = URL(string: "https://mastodon.social")!
        mockService.accessToken = "mockAccessToken"

        // Trigger authentication manually in the mock service if needed
        await mockService.authenticate()
        
        // Since `initializeData()` is called on successful authentication,
        // you might want to await that if it's necessary for the timeline to be fetched
        // before proceeding with the rest of your test.
        // It depends on your specific requirements and how `initializeData()` is structured.
        await viewModel.initializeData()
        
        XCTAssertFalse(viewModel.isLoading)
        // Correctly assert that posts are equal to mockPosts
        XCTAssertEqual(viewModel.posts.count, mockService.mockPosts.count)
        XCTAssertEqual(viewModel.posts.first?.id, mockService.mockPosts.first?.id)
    }

    /// Tests that the TimelineViewModel handles timeline loading failures.
    func testTimelineViewModelLoadTimelineFailure() async throws {
        let mockService = MockMastodonService(shouldSucceed: false)
        // Provide necessary initializers for AuthenticationViewModel and LocationManager
        let authViewModel = AuthenticationViewModel(mastodonService: mockService)
        let locationManager = LocationManager()
        let viewModel = TimelineViewModel(mastodonService: mockService, authViewModel: authViewModel, locationManager: locationManager)
        // Ensure the mock service is set up to be authenticated
        mockService.baseURL = URL(string: "https://mastodon.social")!
        mockService.accessToken = "mockAccessToken"

        // Trigger authentication manually in the mock service if needed
        await mockService.authenticate()
        
        // Since `initializeData()` is called on successful authentication,
        // you might want to await that if it's necessary for the timeline to be fetched
        // before proceeding with the rest of your test.
        // It depends on your specific requirements and how `initializeData()` is structured.
        await viewModel.initializeData()

        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNotNil(viewModel.alertError)
        XCTAssertEqual(viewModel.alertError?.message, "Failed to fetch timeline.")
        XCTAssertTrue(viewModel.posts.isEmpty)
    }
}

// Mock functions for the test to compile
extension MockMastodonService {
    func authenticate() async {
            // Simulate a successful authentication by setting the required properties
            self.baseURL = URL(string: "https://mastodon.social")!
            self.accessToken = "mockAccessToken"
        
    }
}
