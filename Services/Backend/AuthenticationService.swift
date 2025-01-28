//
//  AuthenticationService.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 24/01/25.
//

import Foundation
import AuthenticationServices
import OSLog
import SwiftUI

/// The primary service for authenticating a user with a Mastodon server.
/// Marked with @MainActor to ensure UI-related state updates occur on the main thread.
@MainActor
class AuthenticationService: NSObject, ObservableObject, ASWebAuthenticationPresentationContextProviding {

    // MARK: - Published Properties

    /// Indicates whether the user is currently authenticated (has a valid token).
    @Published private(set) var isAuthenticated = false

    /// Indicates whether an authentication flow is in progress.
    @Published private(set) var isAuthenticating = false

    /// The currently authenticated user, if any.
    @Published private(set) var currentUser: User?

    /// Holds any `AppError` to display in UI alerts.
    @Published var alertError: AppError?

    // MARK: - Private Properties

    /// Logger for structured logging of auth events.
    private let logger = Logger(subsystem: "com.yourcompany.Mustard", category: "AuthenticationService")

    /// Keychain service identifier for storing baseURL + tokens.
    private let keychainService = "MustardKeychain"

    /// Shared `NetworkService` for all network calls.
    private let networkService = NetworkService.shared

    /// ASWebAuthenticationSession instance for the OAuth flow.
    private var webAuthSession: ASWebAuthenticationSession?

    /// Timestamp when we first obtained our token (optional).
    private var tokenCreationDate: Date?

    /// Cached in-memory token, if desired (optional).
    private var accessToken: String?

    // MARK: - Authentication Flow

    /// Main entry point to authenticate with a given Mastodon server.
    /// - Parameter server: The chosen `ServerModel` containing name & URL.
    /// - Throws: An `AppError` if authentication fails (or concurrency prevents a second flow).
    func authenticate(to server: ServerModel) async throws {
        guard !isAuthenticating else { throw AppError(mastodon: .operationInProgress) }
        isAuthenticating = true
        alertError = nil

        defer { isAuthenticating = false }

        do {
            logger.info("Registering OAuth app with server: \(server.url.absoluteString, privacy: .public)")
            let config = try await networkService.registerOAuthApp(instanceURL: server.url)

            guard !config.clientId.isEmpty, !config.clientSecret.isEmpty else {
                logger.error("Invalid OAuth credentials from registerOAuthApp.")
                throw AppError(mastodon: .invalidCredentials)
            }

            // 1) Start the ASWebAuthenticationSession to get the auth code
            let authorizationCode = try await startWebAuthSession(config: config, instanceURL: server.url)

            // 2) Exchange code for an access token
            try await exchangeAuthorizationCode(authorizationCode, config: config, instanceURL: server.url)
            tokenCreationDate = Date()

            // 3) Save the instance URL in keychain for future calls
            try await saveInstanceURL(server.url)

            // 4) Fetch the current user & update UI state
            try await fetchAndUpdateUser(instanceURL: server.url)
            logger.info("Authentication successful for user: \(self.currentUser?.username ?? "Unknown")")

        } catch {
            // If any step fails, handle error & clear leftover credentials
            handleError(error)
            try await clearCredentials()
            throw error
        }
    }

    /// Quickly verifies if the stored token is still valid by fetching the user.
    /// If it fails, we assume the token or baseURL are invalid and clear them.
    func validateAuthentication() async {
        guard !isAuthenticating else { return }
        isAuthenticating = true
        alertError = nil

        defer { isAuthenticating = false }

        do {
            try await verifyCredentials()
            logger.info("Authentication validation successful")
        } catch {
            handleError(error)
            try? await clearCredentials()
        }
    }

    /// Logs out the user by removing token & user state from memory & Keychain.
    func logout() async {
        guard !isAuthenticating else { return }
        isAuthenticating = true
        alertError = nil

        defer { isAuthenticating = false }

        do {
            try await clearCredentials()
            logger.info("Logout completed successfully")
        } catch {
            handleError(error)
        }
    }

    /// For forcibly updating the `currentUser` after user data changes.
    func updateAuthenticatedUser(_ user: User) {
        currentUser = user
        logger.info("Updated authenticated user: \(user.username, privacy: .public)")
    }

    // MARK: - ASWebAuthenticationPresentationContextProviding

    /// Required for ASWebAuthenticationSession to know what window to present in.
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }) else {
            logger.error("No key window available for ASWebAuthenticationSession.")
            return ASPresentationAnchor()
        }
        return window
    }
}

// MARK: - Private Helpers & Implementation

private extension AuthenticationService {

    /// Initiates the ASWebAuthenticationSession flow.
    /// - Returns: The `authorization_code` from the OAuth callback URL.
    func startWebAuthSession(config: OAuthConfig, instanceURL: URL) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in

            let authURL = instanceURL.appendingPathComponent("/oauth/authorize")
            var components = URLComponents(url: authURL, resolvingAgainstBaseURL: false)!
            components.queryItems = [
                URLQueryItem(name: "client_id", value: config.clientId),
                URLQueryItem(name: "redirect_uri", value: config.redirectUri),
                URLQueryItem(name: "response_type", value: "code"),
                URLQueryItem(name: "scope", value: config.scope)
            ]

            guard let finalURL = components.url,
                  let redirectScheme = URL(string: config.redirectUri)?.scheme else {
                continuation.resume(throwing: AppError(mastodon: .invalidAuthorizationURL))
                return
            }

            let session = ASWebAuthenticationSession(
                url: finalURL,
                callbackURLScheme: redirectScheme
            ) { [weak self] callbackURL, error in
                guard let self = self else { return }

                if let error = error {
                    self.handleWebAuthError(error, continuation: continuation)
                    return
                }

                guard let callbackURL = callbackURL,
                      let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
                        .queryItems?
                        .first(where: { $0.name == "code" })?
                        .value
                else {
                    continuation.resume(throwing: AppError(mastodon: .missingAuthorizationCode))
                    return
                }

                continuation.resume(returning: code)
            }

            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = true

            if !session.start() {
                continuation.resume(throwing: AppError(mastodon: .webAuthSessionFailed))
            }

            webAuthSession = session
        }
    }

    /// Deals with any error returned by ASWebAuthenticationSession.
    func handleWebAuthError(
        _ error: Error,
        continuation: CheckedContinuation<String, Error>
    ) {
        if let authError = error as? ASWebAuthenticationSessionError {
            switch authError.code {
            case .canceledLogin:
                logger.info("User canceled authentication session.")
                continuation.resume(throwing: AppError(mastodon: .userCancelledAuth))
            default:
                logger.error("ASWebAuthenticationSession error: \(authError.localizedDescription, privacy: .public)")
                continuation.resume(
                    throwing: AppError(mastodon: .oauthError(message: authError.localizedDescription))
                )
            }
        } else {
            continuation.resume(throwing: error)
        }
    }

    /// Exchanges the given authorization code for an access token using our `NetworkService`.
    func exchangeAuthorizationCode(
        _ code: String,
        config: OAuthConfig,
        instanceURL: URL
    ) async throws {
        try await networkService.exchangeAuthorizationCode(code, config: config, instanceURL: instanceURL)
        tokenCreationDate = Date()
    }

    /// Fetches the current user from the server & updates local state.
    func fetchAndUpdateUser(instanceURL: URL) async throws {
        let user = try await networkService.fetchCurrentUser(instanceURL: instanceURL)
        currentUser = user
        isAuthenticated = true
        NotificationCenter.default.post(name: .didAuthenticate, object: user)
    }

    /// Saves the instance URL in Keychain for future reference.
    func saveInstanceURL(_ url: URL) async throws {
        try await KeychainHelper.shared.save(url.absoluteString,
                                             service: keychainService,
                                             account: "baseURL")
    }

    /// Confirms that baseURL + accessToken exist in Keychain & fetches user for validation.
    func verifyCredentials() async throws {
        async let baseURL = KeychainHelper.shared.read(service: keychainService, account: "baseURL")
        async let token = KeychainHelper.shared.read(service: keychainService, account: "accessToken")

        guard let baseURL = try await baseURL,
              let token = try await token,
              !baseURL.isEmpty, !token.isEmpty else {
            throw AppError(mastodon: .missingCredentials)
        }

        // Attempt a quick user fetch to confirm the token is valid.
        currentUser = try await networkService.fetchCurrentUser()
        isAuthenticated = true
    }

    /// Clears stored credentials (baseURL & accessToken) and updates local state to logged-out.
    func clearCredentials() async throws {
        try await KeychainHelper.shared.delete(service: keychainService, account: "baseURL")
        try await KeychainHelper.shared.delete(service: keychainService, account: "accessToken")
        currentUser = nil
        isAuthenticated = false
        tokenCreationDate = nil

        // Broadcast that we lost authentication status.
        NotificationCenter.default.post(name: .authenticationFailed, object: nil)
    }

    /// Handles an error: logs it & updates `alertError` so the UI can display an alert if needed.
    func handleError(_ error: Error) {
        logger.error("Authentication error: \(error.localizedDescription, privacy: .public)")

        if let appError = error as? AppError {
            alertError = appError
        } else {
            alertError = AppError(message: "Authentication failed", underlyingError: error)
        }
    }
}

