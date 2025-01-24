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
class AuthenticationViewModel: NSObject, ObservableObject, ASWebAuthenticationPresentationContextProviding {
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
    
    /// Authenticate the user to the specified server
    func authenticate(to server: Server) async {
        guard !isAuthenticating else { return }
        isAuthenticating = true
        alertError = nil
        
        authenticationTask = Task {
            logger.info("Starting authentication for server: \(server.url.absoluteString, privacy: .public)")
            await authService.authenticate(to: server)
            currentUser = authService.currentUser
            isAuthenticated = authService.isAuthenticated
            logger.info("Authentication successful for user: \(self.currentUser?.username ?? "Unknown", privacy: .public)")
            isAuthenticating = false
        }
    }
    
    /// Validate the current authentication status
    func validateAuthentication() async {
        isAuthenticating = true
        alertError = nil
        
        logger.info("Validating authentication status...")
        await authService.validateAuthentication()
        currentUser = authService.currentUser
        isAuthenticated = authService.isAuthenticated
        logger.info("Authentication validation completed. Status: \(self.isAuthenticated ? "Authenticated" : "Unauthenticated", privacy: .public)")
        isAuthenticating = false
    }
    
    /// Log out the user
    func logout() async {
        isAuthenticating = true
        alertError = nil
        
        logger.info("Logging out...")
        await authService.logout()
        isAuthenticated = false
        currentUser = nil
        logger.info("Logout successful.")
        isAuthenticating = false
    }
    
    /// Handle errors and update the `alertError` property
    private func handleError(_ error: Error) {
        if let appError = error as? AppError {
            alertError = appError
            logger.error("AppError encountered: \(appError.message, privacy: .public)")
        } else {
            alertError = AppError(message: "An unexpected error occurred.", underlyingError: error)
            logger.error("Unknown error: \(error.localizedDescription, privacy: .public)")
        }
    }
    
    /// Provide a presentation anchor for the ASWebAuthenticationSession
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // Attempt to get the current key window from the active window scene
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first(where: { $0.isKeyWindow }) {
            return window
        }
        
        // If no key window is found, create and return a new fallback window
        let fallbackWindow = UIWindow(frame: UIScreen.main.bounds)
        fallbackWindow.makeKeyAndVisible()
        return fallbackWindow
    }
}
