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
    // In AuthenticationViewModel.swift
    func authenticate(to server: Server) async {
        guard !isAuthenticating else { return }
        isAuthenticating = true
        alertError = nil
        
        do {
            // Register OAuth App and get OAuthConfig
            let config = try await mastodonService.registerOAuthApp(instanceURL: server.url)
            let fetchedUser = try await mastodonService.fetchCurrentUser()
            self.currentUser = fetchedUser
            self.isAuthenticated = true
            
            // Post notification of successful authentication with user info
            NotificationCenter.default.post(name: .didAuthenticate, object: nil, userInfo: ["user": fetchedUser])
            logger.info("Fetched current user: \(fetchedUser.username)")

            // Use the config directly, no need for oauthConfig
            guard !config.clientID.isEmpty, !config.clientSecret.isEmpty else {
                throw AppError(mastodon: .invalidResponse, underlyingError: nil)
            }
            logger.info("OAuth App registered with clientID: \(config.clientID, privacy: .public)")
            
            // Start Web Authentication Session to get authorization code
            let authorizationCode = try await startWebAuthSession(config: config, instanceURL: server.url)
            logger.info("Received authorization code.")
            
            // Exchange authorization code for access token
            try await mastodonService.exchangeAuthorizationCode(
                authorizationCode,
                config: config, // Pass config directly
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
            logger.error("Authentication failed: \(error.localizedDescription, privacy: .public)")
        }
        self.isAuthenticating = false
    }
    
    /// Validates if the user has a valid base URL.
    func validateBaseURL() throws -> URL {
        if let baseURLString = UserDefaults.standard.string(forKey: "baseURL"),
           let baseURL = URL(string: baseURLString) {
            return baseURL
        } else {
            throw AppError(message: "Please enter a valid Mastodon URL.")
        }
    }
    
    /// Validates if the user is already authenticated.
    func validateAuthentication() async {
        isAuthenticating = true
        alertError = nil
        
        do {
            guard let token = try await mastodonService.retrieveAccessToken(),
                  let _ = try await mastodonService.retrieveInstanceURL(),
                  !token.isEmpty else {
                throw AppError(mastodon: .missingCredentials, underlyingError: nil)
            }
            
            try await mastodonService.validateToken()
            self.currentUser = try await mastodonService.fetchCurrentUser()
            self.isAuthenticated = true
            logger.info("User is authenticated: \(self.currentUser?.username ?? "Unknown")")
        } catch {
            handleError(error)
            self.isAuthenticated = false
            logger.error("Authentication validation failed: \(error.localizedDescription, privacy: .public)")
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
            logger.error("Logout failed: \(error.localizedDescription, privacy: .public)")
        }
        isAuthenticating = false
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
        
        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: finalURL,
                callbackURLScheme: redirectScheme
            ) { callbackURL, error in
                if let error = error {
                    self.logger.error("ASWebAuthenticationSession error: \(error.localizedDescription, privacy: .public)")
                    continuation.resume(throwing: AppError(mastodon: .oauthError(message: error.localizedDescription), underlyingError: error))
                    return
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
    
    /// Handles errors by setting the alertError property.
    private func handleError(_ error: Error) {
        if let appError = error as? AppError {
            self.alertError = appError
            logger.error("AppError encountered: \(appError.message, privacy: .public)")
        } else if let decodingError = error as? DecodingError {
            self.alertError = AppError(mastodon: .decodingError, underlyingError: decodingError)
            logger.error("Decoding error: \(decodingError.localizedDescription, privacy: .public)")
        } else {
            self.alertError = AppError(message: "An unexpected error occurred.", underlyingError: error)
            logger.error("Unknown error: \(error.localizedDescription, privacy: .public)")
        }
    }
    
    // MARK: - ASWebAuthenticationPresentationContextProviding
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // Attempt to retrieve the key window for presenting the authentication session
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first(where: { $0.isKeyWindow }) {
            return window
        }
        // Fallback to creating a new window if none found
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.makeKeyAndVisible()
        return window
    }
}
