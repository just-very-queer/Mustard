//
//  AuthenticationService.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 24/01/25.
//

import Foundation
import AuthenticationServices
import OSLog

@MainActor
class AuthenticationService: NSObject, ObservableObject, ASWebAuthenticationPresentationContextProviding {

    @Published var isAuthenticated = false
    @Published var isAuthenticating = false
    @Published var currentUser: User?

    private let logger = Logger(subsystem: "com.yourcompany.Mustard", category: "AuthenticationService")
    private var webAuthSession: ASWebAuthenticationSession?
    private let keychainService = "MustardKeychain"
    private var tokenCreationDate: Date? // Now has a property to track token creation date
    private let networkService = NetworkService.shared // Add instance of NetworkService
    private var accessToken: String? // Fix for _accessToken error.

    // MARK: - Public Methods

    func authenticate(to server: Server) async {
        guard !isAuthenticating else { return }
        isAuthenticating = true

        do {
            // Use NetworkService to register OAuth app
            let config = try await networkService.registerOAuthApp(instanceURL: server.url)

            // Validate OAuthConfig
            guard !config.clientId.isEmpty, !config.clientSecret.isEmpty else {
                logger.error("Invalid OAuthConfig: clientID or clientSecret is empty.")
                throw AppError(mastodon: .invalidResponse)
            }
            logger.info("OAuth App registered successfully with clientID: \(config.clientId, privacy: .public)")

            // Start Web Authentication Session
            logger.info("Starting web authentication session...")
            let authorizationCode = try await startWebAuthSession(config: config, instanceURL: server.url)
            logger.info("Authorization code received successfully.")

            // Exchange Authorization Code for Access Token
            logger.info("Exchanging authorization code for access token...")
            try await networkService.exchangeAuthorizationCode(authorizationCode, config: config, instanceURL: server.url)
            // Update the token creation date after successfully exchanging the code
            self.tokenCreationDate = Date()
            logger.info("Successfully exchanged authorization code for access token.")

            // Fetch Current User Details
            logger.info("Fetching current user details...")
            let fetchedUser = try await networkService.fetchCurrentUser(instanceURL: server.url)

            // Update properties on the main actor
            currentUser = fetchedUser
            isAuthenticated = true
            logger.info("Fetched current user: \(fetchedUser.username)")

            // Post notification of successful authentication with user info
            NotificationCenter.default.post(name: .didAuthenticate, object: nil, userInfo: ["user": fetchedUser])
        } catch {
            isAuthenticated = false
            logger.error("Authentication failed: \(error.localizedDescription, privacy: .public)")
            handleError(error)
        }

        isAuthenticating = false
    }

    func validateAuthentication() async {
        isAuthenticating = true
        do {
            try await ensureInitialized()
            if try await isAuthenticated() {
                let user = try await networkService.fetchCurrentUser()
                currentUser = user
                isAuthenticated = true
                logger.info("User is authenticated: \(user.username)")
            } else {
                isAuthenticated = false
                logger.info("User is not authenticated.")
            }
        } catch let error as AppError {
            isAuthenticated = false
            handleError(error)
        } catch {
            isAuthenticated = false
            handleError(error)
        }

        isAuthenticating = false
    }

    func logout() async {
        isAuthenticating = true

        do {
            try await clearAccessToken()
            try await clearAllKeychainData()
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

    // MARK: - Private Methods

    private func handleError(_ error: Error) {
        if let appError = error as? AppError {
            NotificationCenter.default.post(name: .authenticationFailed, object: nil, userInfo: ["error": appError])
        } else {
            let genericError = AppError(message: "An unexpected error occurred during authentication.", underlyingError: error)
            NotificationCenter.default.post(name: .authenticationFailed, object: nil, userInfo: ["error": genericError])
        }
    }

    private func saveToKeychain(key: String, value: String?) async {
        guard let value = value else { return }
        do {
            try await KeychainHelper.shared.save(value, service: keychainService, account: key)
            logger.debug("Saved \(key) to Keychain.")
        } catch {
            logger.error("Failed to save \(key) to Keychain: \(error.localizedDescription)")
        }
    }

    private func loadFromKeychain(key: String) async -> String? {
        do {
            return try await KeychainHelper.shared.read(service: keychainService, account: key)
        } catch {
            logger.error("Failed to load \(key) from Keychain: \(error.localizedDescription)")
            return nil
        }
    }

    private func clearAllKeychainData() async throws {
        try await KeychainHelper.shared.delete(service: keychainService, account: "baseURL")
        try await KeychainHelper.shared.delete(service: keychainService, account: "accessToken")
    }

    /// Starts the Web Authentication Session to retrieve the authorization code.
    internal func startWebAuthSession(config: OAuthConfig, instanceURL: URL) async throws -> String {
        let authURL = instanceURL.appendingPathComponent("/oauth/authorize")
        var components = URLComponents(url: authURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: config.clientId),
            URLQueryItem(name: "redirect_uri", value: config.redirectUri),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: config.scope)
        ]
        
        guard let finalURL = components.url else {
            throw AppError(mastodon: .invalidAuthorizationCode, underlyingError: nil)
        }
        
        guard let redirectScheme = URL(string: config.redirectUri)?.scheme else {
            throw AppError(mastodon: .invalidResponse, underlyingError: nil)
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: finalURL,
                callbackURLScheme: redirectScheme
            ) { callbackURL, error in
                if let error = error {
                    if (error as NSError).code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                        print("User cancelled the operation")
                        continuation.resume(throwing: AppError(mastodon: .authError, underlyingError: error))
                        return
                    } else {
                        self.logger.error("ASWebAuthenticationSession error: \(error.localizedDescription, privacy: .public)")
                        continuation.resume(throwing: AppError(mastodon: .oauthError(message: error.localizedDescription), underlyingError: error))
                        return
                    }
                }

                guard let callbackURL = callbackURL,
                      let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
                        .queryItems?.first(where: { $0.name == "code" })?.value else {
                    self.logger.error("Authorization code not found in callback URL.")
                    continuation.resume(throwing: AppError(mastodon: .oauthError(message: "Authorization code not found."), underlyingError: nil))
                    return
                }

                continuation.resume(returning: code)
            }

            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = true

            if !session.start() {
                self.logger.error("ASWebAuthenticationSession failed to start.")
                continuation.resume(throwing: AppError(mastodon: .oauthError(message: "Failed to start WebAuth session."), underlyingError: nil))
            }
            self.webAuthSession = session
        }
    }

    private func ensureInitialized() async throws {
        // Fetch the values separately and store them in variables
        let baseURL = await loadFromKeychain(key: "baseURL")
        let accessToken = await loadFromKeychain(key: "accessToken")
        
        // Check if either baseURL or accessToken is missing
        if baseURL == nil || accessToken == nil {
            // Clear all Keychain data if credentials are missing
            try await clearAllKeychainData()
            // Additional error thrown to indicate that credentials are not just missing but also cleared
            throw AppError(mastodon: .missingOrClearedCredentials)
        }
    }

    func isAuthenticated() async throws -> Bool {
        guard let baseUrl = await loadFromKeychain(key: "baseURL"),
              let token = await loadFromKeychain(key: "accessToken"),
              !baseUrl.isEmpty,
              !token.isEmpty
        else {
            throw AppError(mastodon: .missingCredentials)
        }
        return true
    }

    func isTokenNearExpiry() -> Bool {
        guard let creationDate = tokenCreationDate else { return true } // Treat as expired if no creation date
        let expiryThreshold = TimeInterval(3600 * 24 * 80)    // 80 days for example (adjust as needed)
        return Date().timeIntervalSince(creationDate) > expiryThreshold
    }

    func reauthenticate(config: OAuthConfig, instanceURL: URL) async throws {
        // Clear existing credentials
        try await clearAccessToken()
        tokenCreationDate = nil

        // Start a new web authentication session to get a new authorization code
        let authorizationCode = try await startWebAuthSession(config: config, instanceURL: instanceURL)
        logger.info("Received new authorization code.")

        // Exchange the new authorization code for a new access token
        try await networkService.exchangeAuthorizationCode(authorizationCode, config: config, instanceURL: instanceURL)
        logger.info("Exchanged new authorization code for access token")

        // Fetch and update the current user details
        let updatedUser = try await networkService.fetchCurrentUser(instanceURL: instanceURL) // Pass instanceURL here
        NotificationCenter.default.post(name: .didAuthenticate, object: nil, userInfo: ["user": updatedUser])
        logger.info("Fetched and updated current user: \(updatedUser.username)")
    }

    
    func clearAccessToken() async throws {
        // Clear the stored access token
        try await KeychainHelper.shared.delete(service: keychainService, account: "accessToken")

        // Reset the in-memory accessToken property
        accessToken = nil

        // Optionally, reset the token creation date
        tokenCreationDate = nil

        logger.info("Access token cleared from Keychain and memory.")
    }

}
