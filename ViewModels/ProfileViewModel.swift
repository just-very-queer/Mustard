//
//  ProfileViewModel.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 24/01/25.
//

import SwiftUI
import Combine

@MainActor
class ProfileViewModel: ObservableObject {
    @Published var followers: [User] = []
    @Published var following: [User] = []
    @Published var alertMessage: String?
    @Published var showAlert: Bool = false

    private let profileService: ProfileService
    private let authenticationService: AuthenticationService
    private var cancellables = Set<AnyCancellable>()

    init(profileService: ProfileService, authenticationService: AuthenticationService) {
        self.profileService = profileService
        self.authenticationService = authenticationService
        
        // Subscribe to changes in the current user
        authenticationService.$currentUser
            .compactMap { $0 } // Only proceed if currentUser is not nil
            .sink { [weak self] user in
                // Fetch followers and following when the current user changes
                Task {
                    await self?.fetchFollowers(for: user.id)
                    await self?.fetchFollowing(for: user.id)
                }
            }
            .store(in: &cancellables)
    }

    func fetchFollowers(for accountId: String) async {
        do {
            followers = try await profileService.fetchFollowers(for: accountId)
        } catch {
            print("Error fetching followers: \(error.localizedDescription)")
            // Handle error appropriately, possibly updating an alert state
        }
    }

    func fetchFollowing(for accountId: String) async {
        do {
            following = try await profileService.fetchFollowing(for: accountId)
        } catch {
            print("Error fetching following: \(error.localizedDescription)")
            // Handle error appropriately, possibly updating an alert state
        }
    }

    func updateProfile(for accountId: String, updatedFields: [String: String]) async {
        do {
            try await profileService.updateProfile(for: accountId, updatedFields: updatedFields)
            // Handle successful update, possibly updating the UI
        } catch {
            print("Error updating profile: \(error.localizedDescription)")
            // Handle error appropriately, possibly updating an alert state
        }
    }
}
