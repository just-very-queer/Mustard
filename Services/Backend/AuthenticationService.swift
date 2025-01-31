//
//  AuthenticationService.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 24/01/25.
//

import Foundation
import AuthenticationServices
import OSLog
import Combine

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
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Singleton Instance
    static let shared = AuthenticationService()

    private override init() {
        super.init()
    }

    // MARK: - Authentication Flow
    func authenticate(to server: ServerModel) async throws {
        guard !isAuthenticating else { throw AppError(mastodon: .operationInProgress) }
        isAuthenticating = true
        alertError = nil

        defer {
            isAuthenticating = false
        }

        do {
            let config = try await obtainOAuthConfig(for: server)
            let authorizationCode = try await startWebAuthSession(config: config, instanceURL: server.url)
            try await exchangeAuthorizationCode(authorizationCode, config: config, instanceURL: server.url)
            try await saveInstanceURL(server.url)
            try await fetchAndUpdateUser(instanceURL: server.url)
            self.isAuthenticated = true
            logger.info("Authentication successful")
        } catch {
            self.alertError = AppError(message: "Authentication failed", underlyingError: error)
            logger.error("Authentication failed: \(error.localizedDescription)")
        }
    }

    // MARK: - OAuth Configuration Handling
    private func obtainOAuthConfig(for server: ServerModel) async throws -> OAuthConfig {
        let (existingClientID, existingClientSecret) = try await fetchExistingOAuthCredentials()

        if let clientId = existingClientID, let clientSecret = existingClientSecret, !clientId.isEmpty, !clientSecret.isEmpty {
            logger.info("Reusing existing OAuth credentials")
            return OAuthConfig(clientId: clientId, clientSecret: clientSecret, redirectUri: "mustard://oauth-callback", scope: "read write follow push")
        } else {
            return try await registerNewOAuthApp(with: server)
        }
    }

    private func fetchExistingOAuthCredentials() async throws -> (String?, String?) {
        let existingClientID = try await KeychainHelper.shared.read(service: keychainService, account: "clientID")
        let existingClientSecret = try await KeychainHelper.shared.read(service: keychainService, account: "clientSecret")
        return (existingClientID, existingClientSecret)
    }

    private func registerNewOAuthApp(with server: ServerModel) async throws -> OAuthConfig {
        logger.info("Registering new OAuth app with server: \(server.url.absoluteString, privacy: .public)")
        let newConfig = try await networkService.registerOAuthApp(instanceURL: server.url)

        guard !newConfig.clientId.isEmpty, !newConfig.clientSecret.isEmpty else {
            logger.error("Invalid OAuth credentials from registerOAuthApp.")
            throw AppError(mastodon: .invalidCredentials)
        }

        try await KeychainHelper.shared.save(newConfig.clientId, service: keychainService, account: "clientID")
        try await KeychainHelper.shared.save(newConfig.clientSecret, service: keychainService, account: "clientSecret")
        logger.info("Successfully registered and saved new OAuth app")
        return newConfig
    }

    // MARK: - Token Management and User Information
    private func saveInstanceURL(_ url: URL) async throws {
        try await KeychainHelper.shared.save(url.absoluteString, service: keychainService, account: "baseURL")
        logger.info("Instance URL saved to Keychain")
    }

    private func fetchAndUpdateUser(instanceURL: URL) async throws {
        let user = try await networkService.fetchCurrentUser(instanceURL: instanceURL)
        currentUser = user
        NotificationCenter.default.post(name: .didAuthenticate, object: user)
        logger.info("Current user fetched and updated: \(user.username)")
    }

    // MARK: - User Update
    func updateAuthenticatedUser(_ user: User) {
        currentUser = user
        logger.info("Updated authenticated user: \(user.username, privacy: .public)")
    }

    // MARK: - ASWebAuthenticationSession Handling
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }) else {
            logger.error("No key window available for ASWebAuthenticationSession.")
            return ASPresentationAnchor()
        }
        return window
    }

    private func startWebAuthSession(config: OAuthConfig, instanceURL: URL) async throws -> String {
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
            ) { callbackURL, error in
                if let error = error {
                    continuation.resume(throwing: AppError(mastodon: .webAuthSessionFailed))
                    return
                }

                guard let callbackURL = callbackURL else {
                    continuation.resume(throwing: AppError(mastodon: .missingAuthorizationCode))
                    return
                }

                if let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
                        .queryItems?.first(where: { $0.name == "code" })?.value {
                    continuation.resume(returning: code)
                } else {
                    continuation.resume(throwing: AppError(mastodon: .missingAuthorizationCode))
                }
            }

            session.presentationContextProvider = self
            if !session.start() {
                continuation.resume(throwing: AppError(mastodon: .webAuthSessionFailed))
            }

            webAuthSession = session
        }
    }

    private func exchangeAuthorizationCode(_ code: String, config: OAuthConfig, instanceURL: URL) async throws {
        try await networkService.exchangeAuthorizationCode(code, config: config, instanceURL: instanceURL)
    }

    // MARK: - Logout
    func logout() async {
        do {
            try await clearCredentials()
            logger.info("User logged out successfully.")
        } catch {
            logger.error("Logout failed: \(error.localizedDescription)")
        }
    }

    private func clearCredentials() async throws {
        try await KeychainHelper.shared.delete(service: keychainService, account: "baseURL")
        try await KeychainHelper.shared.delete(service: keychainService, account: "accessToken")
        currentUser = nil
        isAuthenticated = false
        NotificationCenter.default.post(name: .authenticationFailed, object: nil)
    }

    // MARK: - Error Handling
    func handleError(_ error: Error) {
        logger.error("Authentication error: \(error.localizedDescription, privacy: .public)")

        if let appError = error as? AppError {
            alertError = appError
        } else {
            alertError = AppError(message: "Authentication failed", underlyingError: error)
        }
    }
}
