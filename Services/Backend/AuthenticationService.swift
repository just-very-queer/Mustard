//
//  AuthenticationService.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 24/01/25.
//
//  This service handles the authentication flow using OAuth 2.0. The flow includes registering a new OAuth app,
//  starting the web authentication session, exchanging the authorization code for an access token, and saving the
//  token and user information in the Keychain. This service also handles error scenarios like missing credentials
//  or failed token exchanges, providing logging for troubleshooting.

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
    
    private let logger = Logger(subsystem: "titan.mustard.app.ao", category: "AuthenticationService")
    private let keychainService = "\(Bundle.main.bundleIdentifier ?? "com.yourcompany").MustardKeychain"
    private let networkService = NetworkService.shared
    private var webAuthSession: ASWebAuthenticationSession?
    private var cancellables = Set<AnyCancellable>()
    private var alertErrorTimer: Timer?
    
    // MARK: - Singleton Instance
    
    static let shared = AuthenticationService()
    
    private override init() {
        super.init()
    }
    
    // MARK: - Authentication Flow
    
    /// Main authentication method that triggers the OAuth flow
    /// - Parameter server: The server model representing the Mastodon instance
    /// - Throws: An error if authentication fails at any step
    func authenticate(to server: ServerModel) async throws {
        guard !isAuthenticating else {
            throw AppError(mastodon: .operationInProgress)
        }

        isAuthenticating = true
        alertError = nil

        do {
            let config = try await obtainOAuthConfig(for: server)

            // Use a Task to handle the web authentication session, ensuring it runs concurrently
            let authorizationCode = try await Task { [weak self] in
                guard let self = self else { throw AppError(message: "AuthenticationService deallocated during authentication") }
                return try await self.startWebAuthSession(config: config, instanceURL: server.url)
            }.value

            guard !authorizationCode.isEmpty else {
                throw AppError(mastodon: .missingAuthorizationCode)
            }

            let tokenResponse = try await exchangeAuthorizationCode(authorizationCode, config: config, instanceURL: server.url)
            try await saveInstanceURL(server.url)
            try await fetchAndUpdateUser(instanceURL: server.url)

            // Update isAuthenticated ONLY after all steps are successful
            await MainActor.run { // Ensure UI update is on the main thread
                isAuthenticated = true
            }
            logger.info("Authentication successful")
        } catch {
            // Update isAuthenticated to false on the main thread
            await MainActor.run {
                isAuthenticated = false
            }

            handleError(error)

            // Rethrow the error to be handled by the caller
            throw error
        }

        // Reset isAuthenticating only after the authentication process is complete (success or failure)
        do {
            isAuthenticating = false
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
        let clientID = try await KeychainHelper.shared.read(service: keychainService, account: "clientID")
        let clientSecret = try await KeychainHelper.shared.read(service: keychainService, account: "clientSecret")
        return (clientID, clientSecret)
    }
    
    private func registerNewOAuthApp(with server: ServerModel) async throws -> OAuthConfig {
        logger.info("Registering new OAuth app with server: \(server.url.absoluteString, privacy: .public)")
        
        try? await KeychainHelper.shared.delete(service: keychainService, account: "clientID")
        try? await KeychainHelper.shared.delete(service: keychainService, account: "clientSecret")
        
        let newConfig = try await networkService.registerOAuthApp(instanceURL: server.url)
        
        guard !newConfig.clientId.isEmpty, !newConfig.clientSecret.isEmpty else {
            logger.error("Invalid OAuth credentials from registerOAuthApp")
            throw AppError(mastodon: .invalidCredentials)
        }
        
        try await KeychainHelper.shared.save(newConfig.clientId, service: keychainService, account: "clientID")
        try await KeychainHelper.shared.save(newConfig.clientSecret, service: keychainService, account: "clientSecret")
        
        logger.info("Successfully registered and saved new OAuth app")
        return newConfig
    }
    
    // MARK: - Token Management
    
    /// Exchanging authorization code for an access token
    /// - Parameter code: The authorization code returned from the web auth flow
    /// - Parameter config: The OAuth configuration to be used
    /// - Parameter instanceURL: The URL of the Mastodon instance
    /// - Throws: An error if token exchange fails or response can't be decoded
    func exchangeAuthorizationCode(_ code: String, config: OAuthConfig, instanceURL: URL) async throws -> TokenResponse {
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
        request.httpBody = body
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
            .joined(separator: "&")
            .data(using: .utf8)
        
        logger.info("Exchanging authorization code at \(tokenEndpointURL.absoluteString)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Capture and log raw response data for debugging
        logger.debug("Raw response data (before validation): \(String(data: data, encoding: .utf8) ?? "Invalid data")")
        logger.debug("HTTP response (before validation): \(response)")
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError(mastodon: .networkError(message: "Network Error"))
        }
        
        guard httpResponse.statusCode == 200 else {
            // Decode the error response directly as a dictionary and handle it generically
            if let errorResponse = try? JSONDecoder().decode([String: String].self, from: data),
               let errorMessage = errorResponse["error_description"] ?? errorResponse["error"] {
                logger.error("Token exchange failed. Status code: \(httpResponse.statusCode), Error: \(errorMessage)")
                throw AppError(mastodon: .oauthError(message: errorMessage)) // Mapping the decoded message to oauthError
            } else {
                let responseBody = String(data: data, encoding: .utf8) ?? "No response body"
                logger.error("Token exchange failed. Status code: \(httpResponse.statusCode), Response body: \(responseBody)")
                throw AppError(mastodon: .oauthError(message: "Token exchange failed. Status code: \(httpResponse.statusCode), Response body: \(responseBody)"))
            }
        }
        
        // Isolate decoding and error handling for better diagnostics
        do {
            // 1. Log the raw data immediately
            logger.debug("Raw response data (IMMEDIATELY): \(String(data: data, encoding: .utf8) ?? "Invalid data")")

            // 2. Attempt decoding in a separate block
            let jsonDecoder = JSONDecoder()
            jsonDecoder.keyDecodingStrategy = .convertFromSnakeCase  // Automatically convert snake_case to camelCase
            
            let decodedResponse = try jsonDecoder.decode(TokenResponse.self, from: data)

            // 3. Log successful decoding
            logger.debug("Successfully decoded TokenResponse. Access Token: \(decodedResponse.accessToken), Expires In: \(decodedResponse.expiresIn)")

            // 4. Save the expiresIn to the keychain for later use
            try await KeychainHelper.shared.save(String(decodedResponse.expiresIn), service: keychainService, account: "expiresIn")

            // 5. Return the decoded TokenResponse
            return decodedResponse

        } catch let decodingError as DecodingError {
            logger.error("Decoding error: \(decodingError)")

            // 6. Provide more context for specific DecodingError cases
            switch decodingError {
            case .dataCorrupted(let context):
                logger.error("Data corrupted: \(context.debugDescription)")
            case .keyNotFound(let key, let context):
                logger.error("Key '\(key.stringValue)' not found: \(context.debugDescription), Coding Path: \(context.codingPath)")
            case .valueNotFound(let type, let context):
                logger.error("Value of type '\(type)' not found: \(context.debugDescription), Coding Path: \(context.codingPath)")
            case .typeMismatch(let type, let context):
                logger.error("Type '\(type)' mismatch: \(context.debugDescription), Coding Path: \(context.codingPath)")
            @unknown default:
                logger.error("Unknown decoding error")
            }

            // 7. Re-throw a custom error with more context if needed
            throw AppError(type: .mastodon(.decodingError), underlyingError: decodingError)
            
        } catch {
            logger.error("Failed to decode TokenResponse: \(error.localizedDescription)")
            let responseBody = String(data: data, encoding: .utf8) ?? ""
            logger.debug("Response body for debugging: \(responseBody)")
            throw AppError(type: .mastodon(.decodingError), underlyingError: error)
        }
    }

    
    private func saveTokenResponse(_ response: TokenResponse) async throws {
        try await KeychainHelper.shared.save(response.accessToken, service: keychainService, account: "accessToken")
        try await KeychainHelper.shared.save(String(response.createdAt), service: keychainService, account: "createdAt")
        logger.info("Successfully saved token information")
    }
    
    // MARK: - Error Handling
    
    /// Handles errors, logs them, and provides suggestions
    /// - Parameter error: The error to handle
    func handleError(_ error: Error) {
        logger.error("Authentication error: \(error.localizedDescription)")
        
        alertErrorTimer?.invalidate()
        if let appError = error as? AppError {
            alertError = appError
        } else {
            alertError = AppError(message: "Authentication failed", underlyingError: error)
        }
        
        alertErrorTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                self?.alertError = nil
                self?.alertErrorTimer = nil
            }
        }
        
        if case .mastodon(.tokenExpired) = (error as? AppError)?.type {
            Task { try? await clearCredentials() }
        }
    }
    
    // MARK: - Session Validation
    
    func validateAuthentication() async {
        do {
            try await verifyCredentials()
            logger.info("Authentication validation successful")
        } catch {
            handleError(error)
            try? await clearCredentials()
        }
    }
    
    private func verifyCredentials() async throws {
        async let baseURL = KeychainHelper.shared.read(service: keychainService, account: "baseURL")
        async let token = KeychainHelper.shared.read(service: keychainService, account: "accessToken")
        
        guard let baseURL = try await baseURL, let token = try await token, !baseURL.isEmpty, !token.isEmpty else {
            throw AppError(mastodon: .missingCredentials)
        }
        
        // Ensure fetchCurrentUser uses the token from Keychain
        currentUser = try await networkService.fetchCurrentUser(instanceURL: URL(string: baseURL)!)
        
        // Update isAuthenticated after successfully fetching the current user
        isAuthenticated = true
    }
    
    // MARK: - Web Auth Session
    
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
    
    func startWebAuthSession(config: OAuthConfig, instanceURL: URL) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            var components = URLComponents(url: instanceURL.appendingPathComponent("/oauth/authorize"), resolvingAgainstBaseURL: false)!
            components.queryItems = [
                URLQueryItem(name: "client_id", value: config.clientId),
                URLQueryItem(name: "redirect_uri", value: config.redirectUri),
                URLQueryItem(name: "response_type", value: "code"),
                URLQueryItem(name: "scope", value: config.scope),
                URLQueryItem(name: "force_login", value: "true")
            ]
            
            guard let finalURL = components.url, let callbackScheme = URL(string: config.redirectUri)?.scheme else {
                continuation.resume(throwing: AppError(mastodon: .invalidAuthorizationURL))
                return
            }

            // Ensure the presentation happens on the main thread, and after the view is fully loaded
            DispatchQueue.main.async {
                let session = ASWebAuthenticationSession(url: finalURL, callbackURLScheme: callbackScheme) { callbackURL, error in
                    if let error = error {
                        self.handleWebAuthError(error, continuation: continuation)
                        return
                    }

                    guard let callbackURL = callbackURL,
                          let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
                            .queryItems?.first(where: { $0.name == "code" })?.value else {
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

    
    private func handleWebAuthError(_ error: Error, continuation: CheckedContinuation<String, Error>) {
        if let authError = error as? ASWebAuthenticationSessionError, authError.code == .canceledLogin {
            continuation.resume(throwing: AppError(mastodon: .userCancelledAuth))
        } else {
            continuation.resume(throwing: error)
        }
    }
    
    // MARK: - User Management
    
    private func saveInstanceURL(_ url: URL) async throws {
        try await KeychainHelper.shared.save(url.absoluteString, service: keychainService, account: "baseURL")
        logger.info("Saved instance URL to Keychain")
    }
    
    private func fetchAndUpdateUser(instanceURL: URL) async throws {
        currentUser = try await networkService.fetchCurrentUser(instanceURL: instanceURL)
        NotificationCenter.default.post(name: .didAuthenticate, object: currentUser)
        logger.info("Updated authenticated user: \(self.currentUser?.username ?? "Unknown")")
    }
    
    func updateAuthenticatedUser(_ user: User) {
        currentUser = user
        logger.info("Manually updated user: \(user.username)")
    }
    
    // MARK: - Logout
    
    func logout() async {
        do {
            try await clearCredentials()
            logger.info("User logged out successfully")
        } catch {
            logger.error("Logout failed: \(error.localizedDescription)")
        }
    }
    
    func clearCredentials() async throws {
        let accounts = ["baseURL", "accessToken", "clientID", "clientSecret", "createdAt", "expiresIn"]
        
        for account in accounts {
            try await KeychainHelper.shared.delete(service: keychainService, account: account)
        }
        
        currentUser = nil
        isAuthenticated = false
        NotificationCenter.default.post(name: .authenticationFailed, object: nil)
        logger.info("Cleared all authentication credentials")
    }
}
