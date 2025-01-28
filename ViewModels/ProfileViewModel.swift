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
        
        authenticationService.$currentUser
            .compactMap { $0 }
            .sink { [weak self] user in
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
            handleError(error, message: "Error fetching followers")
        }
    }

    func fetchFollowing(for accountId: String) async {
        do {
            following = try await profileService.fetchFollowing(for: accountId)
        } catch {
            handleError(error, message: "Error fetching following")
        }
    }

    func updateProfile(for accountId: String, updatedFields: [String: String]) async {
        do {
            let updatedUser = try await profileService.updateProfile(
                for: accountId,
                updatedFields: updatedFields
            )
            
            // Use the new update method instead of direct property access
            authenticationService.updateAuthenticatedUser(updatedUser)
            
            showSuccess(message: "Profile updated successfully!")
        } catch {
            handleError(error, message: "Error updating profile")
        }
    }

    private func showSuccess(message: String) {
        alertMessage = message
        showAlert = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.showAlert = false
        }
    }

    private func handleError(_ error: Error, message: String) {
        alertMessage = "\(message): \(error.localizedDescription)"
        showAlert = true
        print("\(message): \(error.localizedDescription)")
    }
}
