//
//  ProfileViewModel.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 24/01/25.
//

import SwiftUI
import Combine

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published private(set) var followers: [User] = []
    @Published private(set) var following: [User] = []
    @Published var alertMessage: String?
    @Published var showAlert: Bool = false

    private let profileService: ProfileService
    private var cancellables = Set<AnyCancellable>()

    init(profileService: ProfileService) {
        self.profileService = profileService
        setupUserSubscription()
    }

    func fetchFollowers(for accountId: String) async {
        do {
            let fetchedFollowers = try await profileService.fetchFollowers(for: accountId)
            // Update on the main thread.
              await MainActor.run {
                  self.followers = fetchedFollowers
                }
        } catch {
            await handleError(error, message: "Error fetching followers")
        }
    }

    func fetchFollowing(for accountId: String) async {
        do {
            let fetchedFollowing = try await profileService.fetchFollowing(for: accountId)
            following = fetchedFollowing
        } catch {
            await  handleError(error, message: "Error fetching following")
        }
    }

    func updateProfile(for accountId: String, updatedFields: [String: String]) async {
        do {
            let updatedUser = try await profileService.updateProfile(
                for: accountId,
                updatedFields: updatedFields
            )
            AuthenticationService.shared.updateAuthenticatedUser(updatedUser)
            showSuccess(message: "Profile updated successfully!")
        } catch {
          await  handleError(error, message: "Error updating profile")
        }
    }
}

// MARK: - Private Helpers
private extension ProfileViewModel {
    func setupUserSubscription() {
        AuthenticationService.shared.$currentUser
            .compactMap { $0 }
            .sink { [weak self] user in
                Task { [weak self] in
                    await self?.refreshUserData(userId: user.id)
                }
            }
            .store(in: &cancellables)
    }

    func refreshUserData(userId: String) async {
        async let fetchFollowersTask: () = fetchFollowers(for: userId)
        async let fetchFollowingTask: () = fetchFollowing(for: userId)
        _ = await (fetchFollowersTask, fetchFollowingTask)
    }

    func showSuccess(message: String) {
        alertMessage = message
        showAlert = true
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            showAlert = false
        }
    }

    func handleError(_ error: Error, message: String) async {
        await MainActor.run {
            alertMessage = "\(message): \(error.localizedDescription)"
            showAlert = true
            print("\(message): \(error.localizedDescription)")
        }
    }
}
