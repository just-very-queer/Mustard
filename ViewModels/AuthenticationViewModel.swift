//
//  AuthenticationViewModel.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 30/12/24.
//

import SwiftUI
import Combine
import OSLog

@MainActor
class AuthenticationViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published private(set) var authState: AuthState = .unauthenticated
    @Published var alertError: AppError?
    @Published var currentUser: User?
    @Published var selectedServer: ServerModel?

    // MARK: - Private Properties
    private let logger = Logger(subsystem: "titan.mustard.app.ao", category: "AuthenticationViewModel")
    private var authService = AuthenticationService.shared
    private var cancellables = Set<AnyCancellable>()
    private var authTask: Task<Void, Never>? // Task to handle authentication

    // MARK: - Initializer
    init() {
        // Bind AuthenticationService properties to the ViewModel
        authService.$isAuthenticated
            .receive(on: RunLoop.main)
            .sink { [weak self] isAuthenticated in
                self?.authState = isAuthenticated ? .authenticated : .unauthenticated
            }
            .store(in: &cancellables)

        authService.$currentUser
            .receive(on: RunLoop.main)
            .assign(to: \.currentUser, on: self)
            .store(in: &cancellables)

        authService.$alertError
            .receive(on: RunLoop.main)
            .assign(to: \.alertError, on: self)
            .store(in: &cancellables)
    }

    // MARK: - Authentication State
    enum AuthState {
        case unauthenticated
        case authenticating
        case authenticated
    }

    // MARK: - Public Methods

    /// Prepares for authentication by updating the state and starting the authentication process.
    func prepareAuthentication() {
        authState = .authenticating // Indicate authentication is starting
        Task {
            await authenticate()
        }
    }

    /// Authenticates the user.
    func authenticate() async {
        // Ensure only one authentication task runs at a time
        if let existingTask = authTask {
            await existingTask.value // Wait for the existing task to complete
            return
        }

        // Create a new task for authentication
        authTask = Task {
            defer { authTask = nil } // Clear the task when done

            // Indicate that authentication is in progress
            authState = .authenticating

            do {
                // Use the selectedServer for authentication
                guard let server = selectedServer else {
                    alertError = AppError(message: "No server selected.")
                    authState = .unauthenticated
                    return
                }
                try await authService.authenticate(to: server)
                logger.info("Authentication successful")
                authState = .authenticated // Update to authenticated state
            } catch let error as AppError {
                // Handle known errors
                logger.error("Authentication failed: \(error.localizedDescription)")
                alertError = error
                authState = .unauthenticated
            } catch {
                // Handle unknown errors
                logger.error("Unknown error during authentication: \(error.localizedDescription)")
                alertError = AppError(message: "Authentication failed due to an unknown error.")
                authState = .unauthenticated
            }
        }

        await authTask?.value // Wait for the task to complete
    }

    /// Logs out the current user.
    func logout() {
        Task {
            await authService.logout()
            authState = .unauthenticated
        }
    }
}
