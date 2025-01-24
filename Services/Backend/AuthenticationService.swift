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

    // MARK: - Published Properties
    @Published var isAuthenticated = false
    @Published var isAuthenticating = false
    @Published var currentUser: User?
    @Published var alertError: AppError?

    // MARK: - Private Properties
    private let logger = Logger(subsystem: "com.yourcompany.Mustard", category: "AuthenticationService")
    private var webAuthSession: ASWebAuthenticationSession?
    private let keychainService = "MustardKeychain"
    private var tokenCreationDate: Date?
    private let networkService = NetworkService.shared
    private var accessToken: String?

    // MARK: - Public Methods

    /// Authenticates the user with the specified Mastodon server.
    func authenticate(to server: Server) async {
        guard !isAuthenticating else { return }
        isAuthenticating = true
        alertError = nil

        do {
            logger.info("Registering OAuth app with server: \(server.url.absoluteString, privacy: .public)")
            let config = try await networkService.registerOAuthApp(instanceURL: server.url)

            // Validate OAuthConfig
            guard !config.clientId.isEmpty, !config.clientSecret.isEmpty else {
                logger.error("OAuth app registration returned invalid clientID or clientSecret.")
                throw AppError(mastodon: .invalidResponse)
            }

            logger.info("Starting web authentication session...")
            let authorizationCode = try await startWebAuthSession(config: config, instanceURL: server.url)

            logger.info("Exchanging authorization code for access token...")
            try await networkService.exchangeAuthorizationCode(authorizationCode, config: config, instanceURL: server.url)

            tokenCreationDate = Date()
            logger.info("Access token exchanged successfully.")

            // Save the instance URL to Keychain
            try await KeychainHelper.shared.save(server.url.absoluteString, service: keychainService, account: "baseURL")

            // Fetch Current User
            logger.info("Fetching current user details...")
            let fetchedUser = try await networkService.fetchCurrentUser(instanceURL: server.url)

            // Update State
            currentUser = fetchedUser
            isAuthenticated = true
            logger.info("Authentication successful for user: \(fetchedUser.username, privacy: .public)")

            // Notify Authentication Success
            NotificationCenter.default.post(name: .didAuthenticate, object: nil, userInfo: ["user": fetchedUser])
        } catch {
            isAuthenticated = false
            logger.error("Authentication failed: \(error.localizedDescription, privacy: .public)")
            handleError(error)
        }

        isAuthenticating = false
    }

    /// Validates the current authentication status.
    func validateAuthentication() async {
        isAuthenticating = true
        alertError = nil

        do {
            try await ensureInitialized()
            if try await isAuthenticated() {
                let user = try await networkService.fetchCurrentUser()
                currentUser = user
                isAuthenticated = true
                logger.info("Authentication validated for user: \(user.username, privacy: .public)")
            } else {
                isAuthenticated = false
                logger.info("User is not authenticated.")
            }
        } catch {
            isAuthenticated = false
            handleError(error)
        }

        isAuthenticating = false
    }

    /// Logs out the current user by clearing all credentials.
    func logout() async {
        isAuthenticating = true
        alertError = nil

        do {
            try await clearAccessToken()
            try await clearAllKeychainData()
            isAuthenticated = false
            currentUser = nil
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
        // Attempt to get the current key window from the active window scene
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first(where: { $0.isKeyWindow }) {
            return window
        }

        // If no key window is found, create a new fallback window
        let fallbackWindow = UIWindow(frame: UIScreen.main.bounds)
        fallbackWindow.makeKeyAndVisible()
        return fallbackWindow
    }

    // MARK: - Private Methods

    private func handleError(_ error: Error) {
        if let appError = error as? AppError {
            alertError = appError
            logger.error("AppError encountered: \(appError.message, privacy: .public)")
        } else {
            alertError = AppError(message: "An unexpected error occurred.", underlyingError: error)
            logger.error("Unknown error: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func ensureInitialized() async throws {
        guard let baseURL = await loadFromKeychain(key: "baseURL"),
              let accessToken = await loadFromKeychain(key: "accessToken"),
              !baseURL.isEmpty,
              !accessToken.isEmpty else {
            try await clearAllKeychainData()
            throw AppError(mastodon: .missingOrClearedCredentials)
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

    private func clearAccessToken() async throws {
        try await KeychainHelper.shared.delete(service: keychainService, account: "accessToken")
        accessToken = nil
        tokenCreationDate = nil
        logger.info("Access token cleared.")
    }

    /// Starts the Web Authentication Session to retrieve the authorization code.
    internal func startWebAuthSession(config: OAuthConfig, instanceURL: URL) async throws -> String {
            print("startWebAuthSession called")
            let authURL = instanceURL.appendingPathComponent("/oauth/authorize")
            var components = URLComponents(url: authURL, resolvingAgainstBaseURL: false)!
            components.queryItems = [
                URLQueryItem(name: "client_id", value: config.clientId),
                URLQueryItem(name: "redirect_uri", value: config.redirectUri),
                URLQueryItem(name: "response_type", value: "code"),
                URLQueryItem(name: "scope", value: config.scope)
            ]
            
            print("Auth URL components: \(components)")
            
            guard let finalURL = components.url else {
                print("Error: Invalid final URL")
                throw AppError(mastodon: .invalidAuthorizationCode, underlyingError: nil)
            }
            
            print("Final URL: \(finalURL)")
            
            guard let redirectScheme = URL(string: config.redirectUri)?.scheme else {
                print("Error: Invalid redirect scheme")
                throw AppError(mastodon: .invalidResponse, underlyingError: nil)
            }
            
            print("Redirect Scheme: \(redirectScheme)")

            return try await withCheckedThrowingContinuation { continuation in
                print("Creating ASWebAuthenticationSession")
                let session = ASWebAuthenticationSession(
                    url: finalURL,
                    callbackURLScheme: redirectScheme
                ) { callbackURL, error in
                    print("Callback URL: \(callbackURL?.absoluteString ?? "nil")")
                    print("ASWebAuthenticationSession error: \(error?.localizedDescription ?? "nil")")
                    
                    if let error = error {
                        if let authError = error as? ASWebAuthenticationSessionError, authError.code == .canceledLogin {
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
                    print("Authorization code: \(code)")
                    continuation.resume(returning: code)
                }

                session.presentationContextProvider = self
                session.prefersEphemeralWebBrowserSession = true

                print("Starting ASWebAuthenticationSession")
                if !session.start() {
                    self.logger.error("ASWebAuthenticationSession failed to start.")
                    continuation.resume(throwing: AppError(mastodon: .oauthError(message: "Failed to start WebAuth session."), underlyingError: nil))
                }
                print("ASWebAuthenticationSession started")
                self.webAuthSession = session
            }
        }

    func isAuthenticated() async throws -> Bool {
        guard let baseURL = await loadFromKeychain(key: "baseURL"),
              let token = await loadFromKeychain(key: "accessToken"),
              !baseURL.isEmpty,
              !token.isEmpty else {
            throw AppError(mastodon: .missingCredentials)
        }
        return true
    }

    func isTokenNearExpiry() -> Bool {
        guard let creationDate = tokenCreationDate else { return true } // Treat as expired if no creation date
        let expiryThreshold = TimeInterval(3600 * 24 * 80)    // 80 days for example
        return Date().timeIntervalSince(creationDate) > expiryThreshold
    }

    func reauthenticate(config: OAuthConfig, instanceURL: URL) async throws {
        try await clearAccessToken()
        tokenCreationDate = nil

        let authorizationCode = try await startWebAuthSession(config: config, instanceURL: instanceURL)
        logger.info("Received new authorization code.")

        try await networkService.exchangeAuthorizationCode(authorizationCode, config: config, instanceURL: instanceURL)
        logger.info("Exchanged new authorization code for access token")

        let updatedUser = try await networkService.fetchCurrentUser(instanceURL: instanceURL)
        NotificationCenter.default.post(name: .didAuthenticate, object: nil, userInfo: ["user": updatedUser])
        logger.info("Fetched and updated current user: \(updatedUser.username)")
    }
}
