//
//  ProfileViewModel.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 24/01/25.
// (REVISED & FIXED)

import SwiftUI
import Combine
import OSLog // Import OSLog

@MainActor
final class ProfileViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published private(set) var followers: [User] = []
    @Published private(set) var following: [User] = []
    @Published private(set) var userPosts: [Post] = [] // <-- ADDED: To store profile-specific posts
    @Published private(set) var isLoadingUserPosts: Bool = false // <-- ADDED: Loading state for user posts
    @Published var alertMessage: String?
    @Published var showAlert: Bool = false

    // MARK: - Services & Private Properties
    private let profileService: ProfileService
    private var cancellables = Set<AnyCancellable>()
    private let logger = Logger(subsystem: "titan.mustard.app.ao", category: "ProfileViewModel") // <-- ADDED: Logger

    // MARK: - Initialization
    init(profileService: ProfileService) {
        self.profileService = profileService
        // setupUserSubscription() // Commented out: This refreshes data for the *authenticated* user, which might not be what's needed when viewing *another* profile. Fetching should be triggered by the ProfileView's .task.
    }

    // MARK: - Public Fetch Methods

    func fetchFollowers(for accountId: String) async {
        logger.debug("Fetching followers for account ID: \(accountId)")
        // Consider adding a loading state for followers if needed
        do {
            // Assuming profileService.fetchFollowers returns [User] directly now
            let fetchedFollowers = try await profileService.fetchFollowers(for: accountId)
            self.followers = fetchedFollowers
            logger.debug("Successfully fetched \(fetchedFollowers.count) followers.")
        } catch {
            logger.error("Error fetching followers: \(error.localizedDescription)")
            await handleError(error, message: "Error fetching followers")
        }
    }

    func fetchFollowing(for accountId: String) async {
        logger.debug("Fetching following for account ID: \(accountId)")
        // Consider adding a loading state for following if needed
        do {
             // Assuming profileService.fetchFollowing returns [User] directly now
            let fetchedFollowing = try await profileService.fetchFollowing(for: accountId)
            self.following = fetchedFollowing
            logger.debug("Successfully fetched \(fetchedFollowing.count) following.")
        } catch {
             logger.error("Error fetching following: \(error.localizedDescription)")
            await handleError(error, message: "Error fetching following")
        }
    }

    // --- ADDED: Fetch User-Specific Posts ---
    func fetchUserPosts(for accountId: String) async {
        // Prevent fetching if already loading or if posts are already loaded (optional optimization)
        // guard !isLoadingUserPosts else { return } // Add this guard if needed

        logger.debug("Fetching posts for account ID: \(accountId)")
        isLoadingUserPosts = true
        // Clear previous posts when fetching for a new user (important)
        // self.userPosts = [] // Clear immediately or wait until fetch completes? Let's clear before fetch.
        self.userPosts = []

        do {
            // *** ASSUMPTION: profileService has fetchStatuses method ***
            // You need to add this method to your ProfileService:
             let fetchedPosts = try await profileService.fetchStatuses(for: accountId) // Replace with your actual service call

            self.userPosts = fetchedPosts
            logger.debug("Successfully fetched \(fetchedPosts.count) posts for user \(accountId).")
        } catch {
             logger.error("Error fetching user posts for \(accountId): \(error.localizedDescription)")
            // Set userPosts to empty on error to clear stale data
            self.userPosts = []
            await handleError(error, message: "Error fetching user posts")
        }
        isLoadingUserPosts = false // Ensure loading state is reset
    }
    // -----------------------------------------

    func updateProfile(for accountId: String, updatedFields: [String: String]) async {
         logger.debug("Updating profile for account ID: \(accountId)")
         // Consider adding an isLoading state for profile updates
        do {
            // Assuming profileService.updateProfile returns the updated User
            let updatedUser = try await profileService.updateProfile(
                for: accountId,
                updatedFields: updatedFields
            )
            // Update the globally authenticated user if this is the current user
            // This assumes AuthenticationService provides a way to update its currentUser
            AuthenticationService.shared.updateAuthenticatedUser(updatedUser)
            showSuccess(message: "Profile updated successfully!")
            logger.debug("Profile updated successfully for account ID: \(accountId)")
        } catch {
            logger.error("Error updating profile for \(accountId): \(error.localizedDescription)")
            await handleError(error, message: "Error updating profile")
        }
    }

    // MARK: - Private Helpers

    // This might only be relevant if the ProfileViewModel is specifically for the *authenticated* user.
    // If ProfileViewModel is used for *any* user profile, this subscription is likely incorrect.
    /*
    private func setupUserSubscription() {
        AuthenticationService.shared.$currentUser
            .compactMap { $0 }
            .sink { [weak self] user in
                Task { [weak self] in
                    // This refreshes data based on the *logged-in* user, not necessarily the profile being viewed
                    // await self?.refreshUserData(userId: user.id)
                }
            }
            .store(in: &cancellables)
    }
    */

    // This refreshUserData was likely intended for the logged-in user's profile tab.
    // When viewing *another* user's profile, fetching should be triggered by the view's .task.
    /*
    func refreshUserData(userId: String) async {
        logger.debug("Refreshing user data for \(userId)...")
        // Fetch all data concurrently
        async let fetchFollowersTask: () = fetchFollowers(for: userId)
        async let fetchFollowingTask: () = fetchFollowing(for: userId)
        async let fetchPostsTask: () = fetchUserPosts(for: userId) // <-- ADDED
        _ = await (fetchFollowersTask, fetchFollowingTask, fetchPostsTask)
        logger.debug("User data refresh complete for \(userId).")
    }
    */

    // --- Alert/Success Message Handling ---
    func showSuccess(message: String) {
        // Show a temporary success message (e.g., for profile update)
        alertMessage = message
        showAlert = true
        // Optional: Automatically hide after a delay
        Task {
            try? await Task.sleep(for: .seconds(2)) // Use new duration syntax
            // Ensure we are still on the main actor if hiding automatically
            await MainActor.run {
                 self.showAlert = false
            }
        }
    }

    func handleError(_ error: Error, message: String) async {
        // Set alert message to show error to the user
        // No need for await MainActor.run here as the class is @MainActor
        alertMessage = "\(message): \(error.localizedDescription)"
        showAlert = true
        // Log the error using OSLog
        logger.error("\(message): \(error.localizedDescription)")
    }
}
