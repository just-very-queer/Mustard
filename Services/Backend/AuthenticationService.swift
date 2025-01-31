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
    private var tokenCreationDate: Date?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Singleton Instance

    static let shared = AuthenticationService()

    private override init() {
        super.init()
    }

    // MARK: - Authentication Flow

    func authenticate(to server: ServerModel) async throws {
        // Prevents concurrent authentication attempts by ensuring only one authentication can happen at a time
        guard !isAuthenticating else {
            throw AppError(mastodon: .operationInProgress)
        }

        isAuthenticating = true // Set to true immediately after the guard
        
        alertError = nil

        // Resets `isAuthenticating` to `false` when the function exits, even if an error occurs.
        defer {
            isAuthenticating = false
        }

        do {
            let config = try await obtainOAuthConfig(for: server)
            let authorizationCode = try await startWebAuthSession(config: config, instanceURL: server.url)

            // Ensure that we only proceed if the authorization code is successfully received
            if authorizationCode.isEmpty {
                throw AppError(mastodon: .missingAuthorizationCode)
            }

            try await exchangeAuthorizationCode(authorizationCode, config: config, instanceURL: server.url)
            try await saveInstanceURL(server.url)
            try await fetchAndUpdateUser(instanceURL: server.url)
            self.isAuthenticated = true
            logger.info("Authentication successful")
            
        } catch {
            self.isAuthenticated = false
            self.alertError = AppError(message: "Authentication failed", underlyingError: error)
            logger.error("Authentication failed: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - OAuth Configuration Handling
    
    // Fetches existing OAuth credentials or registers a new app if needed.
    private func obtainOAuthConfig(for server: ServerModel) async throws -> OAuthConfig {
        let (existingClientID, existingClientSecret) = try await fetchExistingOAuthCredentials()

        if let clientId = existingClientID, let clientSecret = existingClientSecret,
           !clientId.isEmpty, !clientSecret.isEmpty {
            logger.info("Reusing existing OAuth credentials")
            return OAuthConfig(clientId: clientId, clientSecret: clientSecret, redirectUri: "mustard://oauth-callback", scope: "read write follow push")
        } else {
            return try await registerNewOAuthApp(with: server)
        }
    }

    // Retrieves existing OAuth credentials from the Keychain.
    private func fetchExistingOAuthCredentials() async throws -> (String?, String?) {
        let existingClientID = try await KeychainHelper.shared.read(service: keychainService, account: "clientID")
        let existingClientSecret = try await KeychainHelper.shared.read(service: keychainService, account: "clientSecret")
        return (existingClientID, existingClientSecret)
    }

    // Registers the app with the Mastodon server and saves the new credentials.
    private func registerNewOAuthApp(with server: ServerModel) async throws -> OAuthConfig {
        logger.info("Registering new OAuth app with server: \(server.url.absoluteString, privacy: .public)")

        let newConfig = try await networkService.registerOAuthApp(instanceURL: server.url)

        guard !newConfig.clientId.isEmpty, !newConfig.clientSecret.isEmpty else {
            logger.error("Invalid OAuth credentials from registerOAuthApp.")
            throw AppError(mastodon: .invalidCredentials)
        }

        // 🔥 Ensure credentials are saved before returning
        try await KeychainHelper.shared.save(newConfig.clientId, service: keychainService, account: "clientID")
        try await KeychainHelper.shared.save(newConfig.clientSecret, service: keychainService, account: "clientSecret")

        // Hardcoded API ID to prevent "Unknown Client" error
        let mastodonAPIClientID = "titan.Test.Learn.mastdon.Mustard"
        
        // If an "Unknown Client" error was encountered, retry registration with a known bundle identifier
        if let previousError = alertError, case .mastodon(.unknownClient) = previousError.type {
            alertError = nil // Clear previous error
            try await authenticateWithHardcodedClientID(server: server, mastodonAPIClientID: mastodonAPIClientID)
        }

        logger.info("Successfully registered and saved new OAuth app")
        return newConfig
    }

    private func authenticateWithHardcodedClientID(server: ServerModel, mastodonAPIClientID: String) async throws {
        logger.info("Authenticating with hardcoded Mastodon API Client ID: \(mastodonAPIClientID)")
        let config = OAuthConfig(clientId: mastodonAPIClientID, clientSecret: "", redirectUri: "mustard://oauth-callback", scope: "read write follow push")
        
        let authorizationCode = try await startWebAuthSession(config: config, instanceURL: server.url)

        if authorizationCode.isEmpty {
            throw AppError(mastodon: .missingAuthorizationCode)
        }

        try await exchangeAuthorizationCode(authorizationCode, config: config, instanceURL: server.url)
        try await saveInstanceURL(server.url)
        try await fetchAndUpdateUser(instanceURL: server.url)
        self.isAuthenticated = true
        logger.info("Authentication successful with hardcoded Client ID")
    }

    // MARK: - Token Management and User Information

    // Saves the instance URL to the Keychain.
    private func saveInstanceURL(_ url: URL) async throws {
        try await KeychainHelper.shared.save(url.absoluteString, service: keychainService, account: "baseURL")
        logger.info("Instance URL saved to Keychain")
    }

    // Fetches the current user's information and updates the state.
    private func fetchAndUpdateUser(instanceURL: URL) async throws {
        let user = try await networkService.fetchCurrentUser(instanceURL: instanceURL)
        currentUser = user
        NotificationCenter.default.post(name: .didAuthenticate, object: user)
        logger.info("Current user fetched and updated: \(user.username)")
    }

    // MARK: - ASWebAuthenticationSession Handling
    
    // Provides a presentation anchor for the web authentication session.
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }) else {
            logger.error("No key window available for ASWebAuthenticationSession.")
            return ASPresentationAnchor()
        }
        return window
    }

    // Starts the web authentication session and returns the authorization code.
    private func startWebAuthSession(config: OAuthConfig, instanceURL: URL) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let authURL = instanceURL.appendingPathComponent("/oauth/authorize")
            var components = URLComponents(url: authURL, resolvingAgainstBaseURL: false)!
            components.queryItems = [
                URLQueryItem(name: "client_id", value: config.clientId),
                URLQueryItem(name: "redirect_uri", value: config.redirectUri),
                URLQueryItem(name: "response_type", value: "code"),
                URLQueryItem(name: "scope", value: config.scope),
                URLQueryItem(name: "force_login", value: "true")
            ]

            guard let finalURL = components.url,
                  let redirectScheme = URL(string: config.redirectUri)?.scheme else {
                continuation.resume(throwing: AppError(mastodon: .invalidAuthorizationURL))
                return
            }

            // Ensure the main thread is used for UI-related operations
            DispatchQueue.main.async {
                let session = ASWebAuthenticationSession(
                    url: finalURL,
                    callbackURLScheme: redirectScheme
                ) { callbackURL, error in
                    if let error = error {
                        self.handleWebAuthError(error, continuation: continuation)
                        return
                    }

                    guard let callbackURL = callbackURL,
                          let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
                          .queryItems?.first(where: { $0.name == "code" })?
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

                self.webAuthSession = session
            }
        }
    }

    // Handles any errors that occur during the web authentication session.
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

    // MARK: - Token Exchange

    private func exchangeAuthorizationCode(_ code: String, config: OAuthConfig, instanceURL: URL) async throws {
        let body: [String: String] = [
            "grant_type": "authorization_code",
            "code": code,
            "client_id": config.clientId,
            "client_secret": config.clientSecret,
            "redirect_uri": config.redirectUri,
            "scope": config.scope
        ]

        let tokenEndpointURL = instanceURL.appendingPathComponent("/oauth/token")
        var request = URLRequest(url: tokenEndpointURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        request.httpBody = body.compactMap { (key, value) in
            guard let encodedValue = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
                return nil
            }
            return "\(key)=\(encodedValue)"
        }.joined(separator: "&").data(using: .utf8)

        logger.info("Exchanging authorization code for access token at \(tokenEndpointURL.absoluteString)")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            let responseBody = String(data: data, encoding: .utf8) ?? ""
            logger.error("Failed to exchange authorization code. Status: \(statusCode), Body: \(responseBody)")
            throw AppError(mastodon: .failedToExchangeCode)
        }

        do {
            let tokenResponse = try networkService.jsonDecoder.decode(TokenResponse.self, from: data)
            // Log the access token for debugging
            logger.debug("Received access token: \(tokenResponse.accessToken)")

            // Save the access token in Keychain
            try await KeychainHelper.shared.save(tokenResponse.accessToken, service: keychainService, account: "accessToken")
            tokenCreationDate = Date()
            logger.info("Successfully exchanged authorization code for access token and saved to Keychain.")
        } catch {
            logger.error("Failed to decode TokenResponse: \(error.localizedDescription)")
            let responseBody = String(data: data, encoding: .utf8) ?? ""
            logger.debug("Response body for debugging: \(responseBody)")
            throw AppError(type: .mastodon(.decodingError), underlyingError: error)
        }
    }
    
    // MARK: - Authentication State Validation
    func validateAuthentication() async {
        do {
            try await verifyCredentials()
            logger.info("Authentication validation successful")
        } catch {
            handleError(error)
            try? await clearCredentials()
        }
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

    // MARK: - Logout
    
    func logout() async {
        do {
            try await clearCredentials()
            logger.info("User logged out successfully.")
        } catch {
            logger.error("Logout failed: \(error.localizedDescription)")
        }
    }

    func clearCredentials() async throws {
        try await KeychainHelper.shared.delete(service: keychainService, account: "baseURL")
        try await KeychainHelper.shared.delete(service: keychainService, account: "accessToken")
        try await KeychainHelper.shared.delete(service: keychainService, account: "clientID")
        try await KeychainHelper.shared.delete(service: keychainService, account: "clientSecret")
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

