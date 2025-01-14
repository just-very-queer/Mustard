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
    @Published var currentUser: User? = nil

    // MARK: - Private Properties
    private let mastodonService: MastodonServiceProtocol
    private var webAuthSession: ASWebAuthenticationSession?
    private let logger = Logger(subsystem: "com.yourcompany.Mustard", category: "Authentication")

    // MARK: - Initialization
    init(mastodonService: MastodonServiceProtocol) {
        self.mastodonService = mastodonService
        super.init()
        Task { await validateAuthentication() }
    }

    // MARK: - Public Methods

    /// Starts the OAuth flow for the selected server.

    func authenticate(to server: Server) async {
        guard !isAuthenticating else { return }
        isAuthenticating = true
        alertError = nil

        do {
            // Register OAuth App and get OAuthConfig
            let config = try await mastodonService.registerOAuthApp(instanceURL: server.url)
            logger.info("OAuth App registered with clientID: \(config.clientID, privacy: .public)")
            
            // Start Web Authentication Session to get authorization code
            let authorizationCode = try await startWebAuthSession(config: config, instanceURL: server.url)
            logger.info("Received authorization code: \(authorizationCode, privacy: .private)")
            
            // Exchange authorization code for access token
            try await mastodonService.exchangeAuthorizationCode(
                authorizationCode,
                config: config,
                instanceURL: server.url
            )
            logger.info("Exchanged authorization code for access token.")
            
            // Fetch current user details
            self.currentUser = try await mastodonService.fetchCurrentUser()
            logger.info("Fetched current user: \(self.currentUser?.username ?? "Unknown")")
            self.isAuthenticated = true

            // Post notification of successful authentication
            NotificationCenter.default.post(name: .didAuthenticate, object: nil)
        } catch {
            handleError(error)
            self.isAuthenticated = false
            logger.error("Authentication failed: \(error.localizedDescription)")
        }
        self.isAuthenticating = false
    }

    /// Validates if the user is already authenticated.
    func validateAuthentication() async {
        isAuthenticating = true
        alertError = nil

        do {
            guard let token = try await mastodonService.retrieveAccessToken(),
                  let instanceURL = try await mastodonService.retrieveInstanceURL(),
                  !token.isEmpty else {
                alertError = AppError(mastodon: .missingCredentials, underlyingError: nil)
                isAuthenticated = false
                isAuthenticating = false
                logger.warning("Missing access token or instance URL.")
                return
            }

            try await mastodonService.validateToken()
            self.currentUser = try await mastodonService.fetchCurrentUser()
            self.isAuthenticated = true
            logger.info("User is authenticated: \(self.currentUser?.username ?? "Unknown")")
        } catch {
            handleError(error)
            self.isAuthenticated = false
            logger.error("Authentication validation failed: \(error.localizedDescription)")
        }
        isAuthenticating = false
    }

    /// Logs out the user by clearing the access token and user information.
    func logout() async {
        isAuthenticating = true
        alertError = nil

        do {
            try await mastodonService.clearAccessToken()
            self.isAuthenticated = false
            self.currentUser = nil
            NotificationCenter.default.post(name: .authenticationFailed, object: nil)
            logger.info("User logged out successfully.")
        } catch {
            handleError(error)
            logger.error("Logout failed: \(error.localizedDescription)")
        }
        isAuthenticating = false
    }

    /// Validates the base URL stored in the service.
    func validateBaseURL() async -> Bool {
        do {
            if let _ = try await mastodonService.retrieveInstanceURL() {
                logger.info("Base URL is valid.")
                return true
            } else {
                alertError = AppError(mastodon: .missingCredentials, underlyingError: nil)
                logger.warning("Base URL is missing.")
                return false
            }
        } catch {
            alertError = AppError(mastodon: .invalidResponse, underlyingError: error)
            logger.error("Failed to validate base URL: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Private Methods

    /// Starts the Web Authentication Session to retrieve the authorization code.

    private func startWebAuthSession(config: OAuthConfig, instanceURL: URL) async throws -> String {
        let authURL = instanceURL.appendingPathComponent("/oauth/authorize")
        var components = URLComponents(url: authURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: config.clientID),
            URLQueryItem(name: "redirect_uri", value: config.redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: config.scope)
        ]

        guard let finalURL = components.url else {
            throw AppError(mastodon: .invalidAuthorizationCode, underlyingError: nil)
        }

        guard let redirectScheme = URL(string: config.redirectURI)?.scheme else {
            throw AppError(mastodon: .invalidResponse, underlyingError: nil)
        }

        return try await withCheckedThrowingContinuation { [weak self] continuation in
            guard let self = self else {
                continuation.resume(throwing: AppError(mastodon: .unknown(status: -1), underlyingError: nil))
                return
            }

            let session = ASWebAuthenticationSession(
                url: finalURL,
                callbackURLScheme: redirectScheme
            ) { [weak self] callbackURL, error in
                guard let self = self else {
                    continuation.resume(throwing: AppError(mastodon: .unknown(status: -1), underlyingError: nil))
                    return
                }
                
                if let error = error {
                    continuation.resume(throwing: AppError(mastodon: .oauthError(message: error.localizedDescription), underlyingError: error))
                    return
                }

                guard let callbackURL = callbackURL,
                      let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
                        .queryItems?.first(where: { $0.name == "code" })?.value else {
                    continuation.resume(throwing: AppError(mastodon: .oauthError(message: "Authorization code not found."), underlyingError: nil))
                    return
                }

                continuation.resume(returning: code)
            }

            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = true

            if !session.start() {
                continuation.resume(throwing: AppError(mastodon: .oauthError(message: "Failed to start WebAuth session."), underlyingError: nil))
            }
            self.webAuthSession = session
        }
    }
    /// Handles errors by setting the alertError property.
    // AuthenticationViewModel.swift

    private func handleError(_ error: Error) {
        if let appError = error as? AppError {
            self.alertError = appError
            logger.error("AppError encountered: \(appError.message, privacy: .public)")
        } else if let decodingError = error as? DecodingError {
            switch decodingError {
            case .typeMismatch(let type, let context):
                alertError = AppError(mastodon: .decodingError, underlyingError: decodingError)
                logger.error("Decoding error: Type '\(type)' mismatch at \(context.codingPath).")
            case .valueNotFound(let type, let context):
                alertError = AppError(mastodon: .decodingError, underlyingError: decodingError)
                logger.error("Decoding error: Value '\(type)' not found at \(context.codingPath).")
            case .keyNotFound(let key, let context):
                alertError = AppError(mastodon: .decodingError, underlyingError: decodingError)
            case .dataCorrupted(let context):
                alertError = AppError(mastodon: .decodingError, underlyingError: decodingError)
                logger.error("Decoding error: Data corrupted at \(context.codingPath).")
            @unknown default:
                alertError = AppError(mastodon: .unknown(status: -1), underlyingError: decodingError)
                logger.error("Decoding error: Unknown decoding error.")
            }
        } else {
            alertError = AppError(mastodon: .unknown(status: -1), underlyingError: error)
            logger.error("Unknown error: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - ASWebAuthenticationPresentationContextProviding
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }) else {
            return UIWindow()
        }
        return window
    }
}
