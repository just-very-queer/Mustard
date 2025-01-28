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

/// Main view model handling authentication state and user interactions.
/// Coordinates with AuthenticationService to perform OAuth flows and maintain user session state.
@MainActor
class AuthenticationViewModel: NSObject, ObservableObject, ASWebAuthenticationPresentationContextProviding {
    
    // MARK: - Published Properties
    
    /// Indicates whether the user is currently authenticated
    @Published var isAuthenticated = false
    
    /// Shows if an authentication operation is in progress
    @Published var isAuthenticating = false
    
    /// Holds any authentication-related errors for display
    @Published var alertError: AppError?
    
    /// Contains the currently authenticated user's data
    @Published var currentUser: User?
    
    // MARK: - Private Properties
    
    /// Reference to the authentication service handling OAuth operations
    private let authService: AuthenticationService
    
    /// Logger for authentication-related events
    private let logger = Logger(subsystem: "com.yourcompany.Mustard", category: "Authentication")
    
    /// Current authentication task to allow cancellation
    private var authenticationTask: Task<Void, Never>?
    
    // MARK: - Initialization
    
    init(authenticationService: AuthenticationService) {
        self.authService = authenticationService
        super.init()
        
        // Initial setup could go here
    }
    
    // MARK: - Public Authentication Methods
    
    /// Initiates authentication flow with a Mastodon server
    /// - Parameter server: The server model containing instance URL
    func authenticate(to server: ServerModel) async {
        guard !isAuthenticating else { return }
        isAuthenticating = true
        alertError = nil
        
        authenticationTask = Task {
            logger.info("Starting authentication for server: \(server.url.absoluteString, privacy: .public)")
            
            do {
                // 1. Trigger authentication flow through service
                try await authService.authenticate(to: server)
                
                // 2. Update local state with service's authentication status
                currentUser = authService.currentUser
                isAuthenticated = authService.isAuthenticated
                
                if isAuthenticated {
                    logger.info("Authentication successful for user: \(self.currentUser?.username ?? "Unknown", privacy: .public)")
                } else {
                    // Handle unexpected success without authentication
                    throw AppError(message: "Authentication failed without error")
                }
            } catch {
                // 3. Handle any errors during authentication
                handleAuthenticationFailure(error: error)
            }
            
            // 4. Reset authenticating state
            isAuthenticating = false
        }
    }
    
    /// Validates existing authentication status
    func validateAuthentication() async {
        isAuthenticating = true
        alertError = nil
        
        logger.info("Validating authentication status...")
        
        // 1. Trigger service-side validation
        await authService.validateAuthentication()
        
        // 2. Sync local state with service status
        currentUser = authService.currentUser
        isAuthenticated = authService.isAuthenticated
        
        logger.info("Authentication validation completed. Status: \(self.isAuthenticated ? "Authenticated" : "Unauthenticated", privacy: .public)")
        isAuthenticating = false
    }
    
    /// Handles user logout process
    func logout() async {
        isAuthenticating = true
        alertError = nil
        
        logger.info("Logging out...")
        
        // 1. Trigger service-side logout
        await authService.logout()
        
        // 2. Clear local authentication state
        isAuthenticated = false
        currentUser = nil
        
        logger.info("Logout successful.")
        isAuthenticating = false
    }
    
    // MARK: - Error Handling
    
    /// Processes authentication errors and converts them to user-presentable format
    /// - Parameter error: The error encountered during authentication
    private func handleError(_ error: Error) {
        if let appError = error as? AppError {
            alertError = appError
            logger.error("AppError encountered: \(appError.message, privacy: .public)")
        } else {
            alertError = AppError(message: "An unexpected error occurred.", underlyingError: error)
            logger.error("Unknown error: \(error.localizedDescription, privacy: .public)")
        }
    }
    
    /// Centralized handler for authentication failures
    /// - Parameter error: The error that caused the failure
    private func handleAuthenticationFailure(error: Error) {
        isAuthenticated = false
        currentUser = nil
        logger.error("Authentication failed: \(error.localizedDescription, privacy: .public)")
        handleError(error)
    }
    
    // MARK: - ASWebAuthenticationPresentationContextProviding
    
    /// Provides the presentation anchor for authentication sessions
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            logger.error("Could not get window scene.")
            return ASPresentationAnchor()
        }

        // Prefer the current key window if available
        if let window = windowScene.windows.first(where: { $0.isKeyWindow }) {
            return window
        } else {
            // Fallback for edge cases where no key window exists
            logger.warning("No key window found, using a new window.")
            let fallbackWindow = UIWindow(windowScene: windowScene)
            fallbackWindow.makeKeyAndVisible()
            return fallbackWindow
        }
    }
}
