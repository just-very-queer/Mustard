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
    private var clientID: String?
    private var clientSecret: String?
    private let logger = Logger(subsystem: "com.yourcompany.Mustard", category: "AuthenticationViewModel")

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
            let config = try await mastodonService.registerOAuthApp(instanceURL: server.url)
            clientID = config.clientID
            clientSecret = config.clientSecret

            let authorizationCode = try await startWebAuthSession(config: config, server: server)
            try await mastodonService.exchangeAuthorizationCode(
                authorizationCode,
                config: config,
                instanceURL: server.url
            )

            currentUser = try await mastodonService.fetchCurrentUser()
            isAuthenticated = true
            NotificationCenter.default.post(name: .didAuthenticate, object: nil)
        } catch {
            alertError = AppError(message: "Authentication failed: \(error.localizedDescription)", underlyingError: error)
            isAuthenticated = false
        }
        isAuthenticating = false
    }

    /// Validates if the user is already authenticated.
    func validateAuthentication() async {
        isAuthenticating = true
        alertError = nil
        do {
            if let token = try await mastodonService.retrieveAccessToken(),
               let _ = try await mastodonService.retrieveInstanceURL(),
               !token.isEmpty {
                try await mastodonService.validateToken()
                currentUser = try await mastodonService.fetchCurrentUser()
                isAuthenticated = true
                logger.log("Authentication validation successful.")
            } else {
                logger.log("Authentication validation failed: Missing token or URL.")
                isAuthenticated = false
            }
        } catch {
            logger.error("Authentication validation error: \(error.localizedDescription)")
            isAuthenticated = false
            alertError = AppError(message: "Token validation failed: \(error.localizedDescription)", underlyingError: error)
        }
        isAuthenticating = false
    }

    /// Logs out the user by clearing the access token and user information.
    func logout() async {
        isAuthenticating = true
        do {
            try await mastodonService.clearAccessToken()
            isAuthenticated = false
            currentUser = nil
            NotificationCenter.default.post(name: .authenticationFailed, object: nil)
        } catch {
            alertError = AppError(message: "Failed to logout: \(error.localizedDescription)", underlyingError: error)
        }
        isAuthenticating = false
    }

    /// Validates the base URL stored in the service.
    func validateBaseURL() async -> Bool {
        do {
            if let url = try await mastodonService.retrieveInstanceURL() {
                logger.log("Base URL validated successfully: \(url.absoluteString)")
                return true
            } else {
                logger.error("Base URL is nil.")
            }
        } catch {
            logger.error("Error during base URL validation: \(error.localizedDescription)")
            alertError = AppError(message: "Failed to validate base URL: \(error.localizedDescription)", underlyingError: error)
        }
        return false
    }

    // MARK: - Private Methods

    /// Starts the Web Authentication Session to retrieve the authorization code.
    private func startWebAuthSession(config: OAuthConfig, server: Server) async throws -> String {
        let authURL = server.url.appendingPathComponent("/oauth/authorize")
        var components = URLComponents(url: authURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: config.clientID),
            URLQueryItem(name: "redirect_uri", value: config.redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: config.scope)
            
        ]

        guard let finalURL = components.url else {
            throw AppError(message: "Invalid authorization URL.")
        }

        guard let redirectScheme = URL(string: config.redirectURI)?.scheme else {
            throw AppError(message: "Invalid redirect URI scheme.")
        }

        self.logger.log("Starting WebAuth session with URL: \(finalURL.absoluteString)")

        return try await withCheckedThrowingContinuation { [weak self] continuation in
            guard let self = self else {
                continuation.resume(throwing: AppError(message: "Authentication session failed: ViewModel was deallocated."))
                return
            }

            let session = ASWebAuthenticationSession(
                url: finalURL,
                callbackURLScheme: redirectScheme
            ) { callbackURL, error in
                if let error = error {
                    self.logger.error("WebAuth session error: \(error.localizedDescription)")
                    continuation.resume(throwing: AppError(message: "WebAuth session error: \(error.localizedDescription)"))
                    return
                }

                guard let callbackURL = callbackURL,
                      let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
                        .queryItems?.first(where: { $0.name == "code" })?.value else {
                    self.logger.error("Authorization code not found.")
                    continuation.resume(throwing: AppError(message: "Authorization code not found."))
                    return
                }

                self.logger.log("Authorization code received: \(code)")
                continuation.resume(returning: code)
            }

            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = true

            if !session.start() {
                logger.error("Failed to start WebAuth session.")
                continuation.resume(throwing: AppError(message: "Failed to start WebAuth session."))
            } else {
                logger.log("WebAuth session started successfully.")
            }

            self.webAuthSession = session
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


