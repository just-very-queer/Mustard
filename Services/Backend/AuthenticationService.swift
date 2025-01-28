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

@MainActor
class AuthenticationService: NSObject, ObservableObject, ASWebAuthenticationPresentationContextProviding {

    // MARK: - Published Properties
    @Published private(set) var isAuthenticated = false
    @Published private(set) var isAuthenticating = false
    @Published private(set) var currentUser: User?
    @Published var alertError: AppError?

    // MARK: - Private Properties
    private let logger = Logger(subsystem: "com.yourcompany.Mustard", category: "AuthenticationService")
    private let keychainService = "MustardKeychain"
    private let networkService = NetworkService.shared
    private var webAuthSession: ASWebAuthenticationSession?
    private var tokenCreationDate: Date?
    private var accessToken: String?
    static let shared = AuthenticationService()


    // MARK: - Authentication Flow
    func authenticate(to server: ServerModel) async throws {
        guard !isAuthenticating else { throw AppError(mastodon: .operationInProgress) }
        isAuthenticating = true
        alertError = nil

        defer { isAuthenticating = false }

        do {
            let config: OAuthConfig
            let existingClientID = try await KeychainHelper.shared.read(service: keychainService, account: "clientID")
            let existingClientSecret = try await KeychainHelper.shared.read(service: keychainService, account: "clientSecret")
            
            if let existingClientID = existingClientID,
               let existingClientSecret = existingClientSecret,
               !existingClientID.isEmpty,
               !existingClientSecret.isEmpty {
                logger.info("Reusing existing OAuth credentials")
                config = OAuthConfig(
                    clientId: existingClientID,
                    clientSecret: existingClientSecret,
                    redirectUri: "mustard://oauth-callback",
                    scope: "read write follow push"
                )
            } else {
                logger.info("Registering new OAuth app with server: \(server.url.absoluteString, privacy: .public)")
                let newConfig = try await networkService.registerOAuthApp(instanceURL: server.url)
                
                guard !newConfig.clientId.isEmpty, !newConfig.clientSecret.isEmpty else {
                    logger.error("Invalid OAuth credentials from registerOAuthApp.")
                    throw AppError(mastodon: .invalidCredentials)
                }
                
                try await KeychainHelper.shared.save(newConfig.clientId, service: keychainService, account: "clientID")
                try await KeychainHelper.shared.save(newConfig.clientSecret, service: keychainService, account: "clientSecret")
                config = newConfig
                logger.info("Successfully registered and saved new OAuth app")
            }

            let authorizationCode = try await startWebAuthSession(config: config, instanceURL: server.url)
            try await exchangeAuthorizationCode(authorizationCode, config: config, instanceURL: server.url)
            tokenCreationDate = Date()
            try await saveInstanceURL(server.url)
            try await fetchAndUpdateUser(instanceURL: server.url)
            logger.info("Authentication successful for user: \(self.currentUser?.username ?? "Unknown")")

        } catch {
            handleError(error)
            try await clearCredentials()
            throw error
        }
    }

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

    func updateAuthenticatedUser(_ user: User) {
        currentUser = user
        logger.info("Updated authenticated user: \(user.username, privacy: .public)")
    }

    // MARK: - ASWebAuthenticationPresentationContextProviding
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }) else {
            logger.error("No key window available for ASWebAuthenticationSession.")
            return ASPresentationAnchor()
        }
        return window
    }
}

// MARK: - Private Helpers
private extension AuthenticationService {
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

    func exchangeAuthorizationCode(
        _ code: String,
        config: OAuthConfig,
        instanceURL: URL
    ) async throws {
        try await networkService.exchangeAuthorizationCode(code, config: config, instanceURL: instanceURL)
        tokenCreationDate = Date()
    }

    func fetchAndUpdateUser(instanceURL: URL) async throws {
        let user = try await networkService.fetchCurrentUser(instanceURL: instanceURL)
        currentUser = user
        isAuthenticated = true
        NotificationCenter.default.post(name: .didAuthenticate, object: user)
    }

    func saveInstanceURL(_ url: URL) async throws {
        try await KeychainHelper.shared.save(url.absoluteString,
                                             service: keychainService,
                                             account: "baseURL")
    }

    func verifyCredentials() async throws {
        async let baseURL = KeychainHelper.shared.read(service: keychainService, account: "baseURL")
        async let token = KeychainHelper.shared.read(service: keychainService, account: "accessToken")

        guard let baseURL = try await baseURL,
              let token = try await token,
              !baseURL.isEmpty, !token.isEmpty else {
            throw AppError(mastodon: .missingCredentials)
        }

        currentUser = try await networkService.fetchCurrentUser()
        isAuthenticated = true
    }

    func clearCredentials() async throws {
        try await KeychainHelper.shared.delete(service: keychainService, account: "baseURL")
        try await KeychainHelper.shared.delete(service: keychainService, account: "accessToken")
        currentUser = nil
        isAuthenticated = false
        tokenCreationDate = nil
        NotificationCenter.default.post(name: .authenticationFailed, object: nil)
    }

    func handleError(_ error: Error) {
        logger.error("Authentication error: \(error.localizedDescription, privacy: .public)")

        if let appError = error as? AppError {
            alertError = appError
        } else {
            alertError = AppError(message: "Authentication failed", underlyingError: error)
        }
    }
}
