//
//  AuthenticationViewModel.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 30/12/24.
//

import SwiftUI
import Combine
import AuthenticationServices
import OSLog

@MainActor
class AuthenticationViewModel: NSObject, ObservableObject {
    @Published var isAuthenticated = false
    @Published var isAuthenticating = false
    @Published var alertError: AppError?
    @Published var currentUser: User?

    private let authService: AuthenticationService
    private let logger = Logger(subsystem: "com.yourcompany.Mustard", category: "Authentication")

    // Expose the authentication service publicly as a read-only property
    var authenticationService: AuthenticationService {
        authService
    }

    private var authenticationTask: Task<Void, Never>?

    init(authenticationService: AuthenticationService) {
        self.authService = authenticationService
        super.init()
    }

    func authenticate(to server: Server) async {
        guard !isAuthenticating else { return }
        isAuthenticating = true
        alertError = nil

        authenticationTask = Task {
            await authService.authenticate(to: server)
            currentUser = authService.currentUser
            isAuthenticated = authService.isAuthenticated
            isAuthenticating = false
        }
    }

    func validateAuthentication() async {
        isAuthenticating = true
        alertError = nil

        await authService.validateAuthentication()
        currentUser = authService.currentUser
        isAuthenticated = authService.isAuthenticated

        isAuthenticating = false
    }

    func logout() async {
        isAuthenticating = true
        alertError = nil

        await authService.logout()
        isAuthenticated = false
        currentUser = nil

        isAuthenticating = false
    }

    private func handleError(_ error: Error) {
        if let appError = error as? AppError {
            alertError = appError
            logger.error("AppError encountered: \(appError.message, privacy: .public)")
        } else {
            alertError = AppError(message: "An unexpected error occurred.", underlyingError: error)
            logger.error("Unknown error: \(error.localizedDescription, privacy: .public)")
        }
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // Use an existing window if available
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first(where: { $0.isKeyWindow }) {
            return window
        }

        // If no existing window, create a new one. This is less ideal but can serve as a fallback.
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.makeKeyAndVisible() // This line is crucial to make the window visible
        return window
    }
}
