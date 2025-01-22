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
    
    // MARK: - Published Properties
    
    @Published var isAuthenticated = false
    @Published var isAuthenticating = false
    @Published var alertError: AppError?
    @Published var currentUser: User?
    
    // MARK: - Private Properties
    
    private let mastodonService: MastodonServiceProtocol
    private let logger = Logger(subsystem: "com.yourcompany.Mustard", category: "Authentication")
    
    // A dedicated Task to handle authentication operations
    private var authenticationTask: Task<Void, Never>?
    
    // MARK: - Initialization
    
    init(mastodonService: MastodonServiceProtocol) {
        self.mastodonService = mastodonService
        super.init()
    }
    
    // MARK: - Public Methods
    
    // Starts the OAuth flow for the selected server.
    func authenticate(to server: Server) async {
        guard !isAuthenticating else { return }
        isAuthenticating = true
        alertError = nil
        
        authenticationTask = Task {
            do {
                // Step 1: Register OAuth App
                logger.info("Registering OAuth app with instance: \(server.url)")
                let config: OAuthConfig
                do {
                    config = try await mastodonService.registerOAuthApp(instanceURL: server.url)
                } catch {
                    handleError(error)
                    return
                }

                // Step 2: Validate OAuthConfig
                guard !config.clientID.isEmpty, !config.clientSecret.isEmpty else {
                    logger.error("Invalid OAuthConfig: clientID or clientSecret is empty.")
                    throw AppError(mastodon: .invalidResponse)
                }
                logger.info("OAuth App registered successfully with clientID: \(config.clientID, privacy: .public)")

                // Step 3: Start Web Authentication Session
                logger.info("Starting web authentication session...")
                let authorizationCode: String
                do {
                    authorizationCode = try await mastodonService.startWebAuthSession(config: config, instanceURL: server.url)
                } catch {
                    throw AppError(mastodon: .oauthError(message: "Failed to start web authentication session."), underlyingError: error)
                }
                logger.info("Authorization code received successfully.")

                // Step 4: Exchange Authorization Code for Access Token
                logger.info("Exchanging authorization code for access token...")
                do {
                    try await mastodonService.exchangeAuthorizationCode(
                        authorizationCode,
                        config: config,
                        instanceURL: server.url
                    )
                } catch {
                    throw AppError(mastodon: .failedToExchangeCode, underlyingError: error)
                }
                logger.info("Successfully exchanged authorization code for access token.")

                // Step 5: Fetch Current User Details
                logger.info("Fetching current user details...")
                do {
                    let fetchedUser = try await mastodonService.fetchCurrentUser()

                    // Update properties on the main actor
                    currentUser = fetchedUser
                    isAuthenticated = true
                    logger.info("Fetched current user: \(fetchedUser.username)")

                    // Post notification of successful authentication with user info
                    NotificationCenter.default.post(name: .didAuthenticate, object: nil, userInfo: ["user": fetchedUser])
                } catch let error as AppError {
                    isAuthenticated = false
                    logger.error("Failed to fetch current user: \(error.localizedDescription)")

                    if case .mastodon(.decodingError) = error.type {
                        alertError = AppError(message: "Failed to decode user data. Please check server compatibility.")
                    } else {
                        alertError = AppError(message: "Failed to fetch current user after authentication. \(error.message)")
                    }
                } catch {
                    isAuthenticated = false
                    logger.error("Unexpected error fetching current user: \(error)")
                    alertError = AppError(message: "An unexpected error occurred while fetching user details. \(error.localizedDescription)", underlyingError: error)
                }
            } catch let error as AppError {
                handleError(error)
            } catch {
                let genericError = AppError(message: "An unexpected error occurred during authentication.", underlyingError: error)
                handleError(genericError)
            }
            isAuthenticating = false
        }
    }

    // Validates if the user is already authenticated and updates the UI accordingly.
    func validateAuthentication() async {
        isAuthenticating = true
        alertError = nil

        do {
            try await mastodonService.ensureInitialized()
            if try await mastodonService.isAuthenticated() {
                let user = try await mastodonService.fetchCurrentUser()
                currentUser = user
                isAuthenticated = true
                logger.info("User is authenticated: \(user.username)")
            } else {
                isAuthenticated = false
                logger.info("User is not authenticated.")
                // No error here, it's a normal state on first launch
            }
        } catch let error as AppError {
            switch error.type {
            case .mastodon(.missingOrClearedCredentials):
                isAuthenticated = false  // It's ok, no credentials yet.
                logger.info("App launched for the first time or after logout.")
            default:
                isAuthenticated = false
                handleError(error)
            }
        } catch { // Handle non-AppError
            isAuthenticated = false
            handleError(error)
        }

        isAuthenticating = false
    }

    // Logs out the user by clearing the access token and user information.
    func logout() async {
        isAuthenticating = true
        alertError = nil

        do {
            try await mastodonService.clearAccessToken()
            try await mastodonService.clearAllKeychainData()
            self.isAuthenticated = false
            self.currentUser = nil
            NotificationCenter.default.post(name: .authenticationFailed, object: nil)
            logger.info("User logged out successfully.")
        } catch {
            handleError(error)
            logger.error("Logout failed: \(error.localizedDescription, privacy: .public)")
        }

        isAuthenticating = false
    }

    // MARK: - Private Methods

    // Handles errors by setting the alertError property.
    private func handleError(_ error: Error) {
        if let appError = error as? AppError {
            alertError = appError
            logger.error("AppError encountered: \(appError.message, privacy: .public)")
        } else if let decodingError = error as? DecodingError {
            alertError = AppError(mastodon: .decodingError, underlyingError: decodingError)
            logger.error("Decoding error: \(decodingError.localizedDescription, privacy: .public)")
        } else {
            alertError = AppError(message: "An unexpected error occurred.", underlyingError: error)
            logger.error("Unknown error: \(error.localizedDescription, privacy: .public)")
        }
    }
    // MARK: - ASWebAuthenticationPresentationContextProviding
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
