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

    /// Authenticates the user.
    func authenticate() async {
        // Ensure authentication is not already in progress
        guard authState != .authenticating else {
            alertError = AppError(message: "Authentication is already in progress.")
            return
        }

        // Update state to indicate authentication is in progress
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
            authState = .authenticated
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

    /// Logs out the current user.
    func logout() {
        Task {
            await authService.logout()
            authState = .unauthenticated
        }
    }
    
    func prepareAuthentication() {
        authState = .authenticating
        Task {
            await authenticate()
        }
    }
}
