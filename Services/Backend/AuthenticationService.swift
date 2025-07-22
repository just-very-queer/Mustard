//
//  AuthenticationService.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 24/01/25.
//  Updated to use MastodonAPIService & NetworkSessionManager
//

import Foundation
import AuthenticationServices // Keep for potential shared elements, but ASWebAuthenticationSession will be conditional
import OSLog
import Combine

// Conditional import for UIKit and specific classes like UIApplication
#if os(iOS)
import UIKit
#endif

@MainActor
class AuthenticationService: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    
    @Published private(set) var isAuthenticated = false
    @Published private(set) var isAuthenticating = false // May have limited use on watchOS
    @Published private(set) var currentUser: User?
    @Published var alertError: AppError?
    
    // MARK: - Private Properties
    
    private let logger = Logger(subsystem: "titan.mustard.app.ao", category: "AuthenticationService")
    private let keychainService = "MustardKeychain" // Ensure KeychainHelper uses App Groups for sharing
    private let mastodonAPIService: MastodonAPIService
    private let sessionManager: NetworkSessionManager
    private var cancellables = Set<AnyCancellable>()
    private var alertErrorTimer: Timer?
    
    #if os(iOS)
    private var webAuthSession: ASWebAuthenticationSession?
    #endif
    
    // MARK: - Singleton Instance
    
    static let shared = AuthenticationService(
        mastodonAPIService: MastodonAPIService(),
        sessionManager: NetworkSessionManager.shared
    )
    
    /// Designated initializer for explicit injection (e.g. tests)
    internal init(
        mastodonAPIService: MastodonAPIService,
        sessionManager: NetworkSessionManager
    ) {
        self.mastodonAPIService = mastodonAPIService
        self.sessionManager = sessionManager
        super.init()
        checkExistingCredentials()
    }
    
    /// Private override for the shared singleton
    private override init() {
        self.mastodonAPIService = MastodonAPIService()
        self.sessionManager = NetworkSessionManager.shared
        super.init()
        checkExistingCredentials()
    }
    
    // MARK: - Credential Check (Shared Logic)
    
    private func checkExistingCredentials() {
        Task {
            do {
                try await verifyCredentials()
                logger.info("Credentials are valid.")
            } catch {
                logger.error("Credentials check failed: \(error.localizedDescription)")
                self.isAuthenticated = false // Already on MainActor
                try? await clearCredentials()
            }
        }
    }
    
    private func verifyCredentials() async throws {
        // This assumes a token is already in the Keychain (potentially shared from iOS)
        currentUser = try await mastodonAPIService.fetchCurrentUser()
        isAuthenticated = true
    }
    
    // MARK: - Authentication Flow
    
    func authenticate(to server: ServerModel?) async {
        #if os(iOS)
        guard let server = server else {
            alertError = AppError(message: "No server selected.")
            return
        }

        guard !isAuthenticating else {
            return
        }
        isAuthenticating = true
        alertError = nil
        
        do {
            let config = try await obtainOAuthConfig(for: server)
            let code = try await Task { [weak self] in
                guard let self = self else {
                    throw AppError(message: "AuthenticationService deallocated")
                }
                return try await self.startWebAuthSession(config: config, instanceURL: server.url)
            }.value
            
            guard !code.isEmpty else {
                throw AppError(mastodon: .missingAuthorizationCode)
            }
            
            _ = try await exchangeAuthorizationCode(code, config: config, instanceURL: server.url)
            try await saveInstanceURL(server.url)
            try await fetchAndUpdateUser()
            
            isAuthenticated = true
            logger.info("Authentication successful")
        } catch {
            isAuthenticated = false
            handleError(error)
        }
        
        isAuthenticating = false
        #else
        // watchOS does not initiate this OAuth flow. It relies on shared tokens.
        logger.warning("Full authentication flow is not supported on watchOS. Check for shared credentials.")
        #endif
    }
    
    // MARK: - OAuth Config (iOS-specific)
    
    #if os(iOS)
    private func obtainOAuthConfig(for server: ServerModel) async throws -> OAuthConfig {
        let (existingId, existingSecret) = try await fetchExistingOAuthCredentials()
        if let id = existingId, let secret = existingSecret,
           !id.isEmpty, !secret.isEmpty {
            logger.info("Reusing existing OAuth credentials")
            return OAuthConfig(
                clientId: id,
                clientSecret: secret,
                redirectUri: "mustard://oauth-callback",
                scope: "read write follow push"
            )
        } else {
            return try await registerNewOAuthApp(with: server)
        }
    }
    
    private func fetchExistingOAuthCredentials() async throws -> (String?, String?) {
        let id = try await KeychainHelper.shared.read(service: keychainService, account: "clientID")
        let secret = try await KeychainHelper.shared.read(service: keychainService, account: "clientSecret")
        return (id, secret)
    }
    
    private func registerNewOAuthApp(with server: ServerModel) async throws -> OAuthConfig {
        logger.info("Registering new OAuth app with server: \(server.url.absoluteString, privacy: .public)")
        try? await KeychainHelper.shared.delete(service: keychainService, account: "clientID")
        try? await KeychainHelper.shared.delete(service: keychainService, account: "clientSecret")
        
        let config = try await mastodonAPIService.registerOAuthApp(instanceURL: server.url)
        guard !config.clientId.isEmpty, !config.clientSecret.isEmpty else {
            logger.error("Invalid OAuth credentials from registerOAuthApp")
            throw AppError(mastodon: .invalidCredentials)
        }
        
        try await KeychainHelper.shared.save(config.clientId, service: keychainService, account: "clientID")
        try await KeychainHelper.shared.save(config.clientSecret, service: keychainService, account: "clientSecret")
        logger.info("Successfully registered and saved new OAuth app")
        return config
    }
    #endif
    
    // MARK: - Token Exchange (iOS-specific as part of its auth flow)
    #if os(iOS)
    func exchangeAuthorizationCode(
        _ code: String,
        config: OAuthConfig,
        instanceURL: URL
    ) async throws -> TokenResponse {
        let body = [
            "grant_type": "authorization_code",
            "code": code,
            "client_id": config.clientId,
            "client_secret": config.clientSecret,
            "redirect_uri": config.redirectUri,
            "scope": config.scope
        ]
        
        let tokenURL = instanceURL.appendingPathComponent("/oauth/token")
        let request = try sessionManager.buildRequest(
            url: tokenURL,
            method: "POST",
            body: body,
            contentType: "application/x-www-form-urlencoded",
            accessToken: nil
        )
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AppError(mastodon: .networkError(message: "Invalid response"))
        }
        guard http.statusCode == 200 else {
            let msg = String(data: data, encoding: .utf8) ?? "No body"
            logger.error("Token exchange failed: \(http.statusCode) – \(msg)")
            throw AppError(mastodon: .oauthError(message: msg))
        }
        
        let tokenResp = try sessionManager.jsonDecoder.decode(TokenResponse.self, from: data)
        logger.debug("Decoded TokenResponse: accessToken=\(tokenResp.accessToken)")
        
        // Save tokens
        try await KeychainHelper.shared.save(tokenResp.accessToken, service: keychainService, account: "accessToken")
        if let expires = tokenResp.expiresIn {
            try await KeychainHelper.shared.save(String(expires), service: keychainService, account: "expiresIn")
        } else {
            try await KeychainHelper.shared.delete(service: keychainService, account: "expiresIn")
        }
        
        return tokenResp
    }
    #endif
    
    // MARK: - Error Handling (Shared Logic)
    
    func handleError(_ error: Error) {
        logger.error("Authentication error: \(error.localizedDescription)")
        alertErrorTimer?.invalidate() // Invalidate existing timer
        
        let appErr = (error as? AppError) ?? AppError(message: "Authentication failed", underlyingError: error)
        self.alertError = appErr // This is fine as class is @MainActor
        
        // Schedule a new timer
        alertErrorTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            // Ensure update to @MainActor property is done on the main actor
            // Since the class is @MainActor, direct access to self?.alertError is okay here.
            // The Swift 6 warning implies the closure itself might not inherit actor context
            // as expected by the stricter checks. Dispatching explicitly is the safest.
            DispatchQueue.main.async {
                 self?.alertError = nil
            }
        }
        
        if case .mastodon(.tokenExpired) = appErr.type {
            Task { try? await clearCredentials() }
        }
    }
    
    // MARK: - Web Auth (iOS-specific)
    
    #if os(iOS)
    func startWebAuthSession(config: OAuthConfig, instanceURL: URL) async throws -> String {
        try await withCheckedThrowingContinuation { cont in
            var comps = URLComponents(url: instanceURL.appendingPathComponent("/oauth/authorize"), resolvingAgainstBaseURL: false)!
            comps.queryItems = [
                .init(name: "client_id", value: config.clientId),
                .init(name: "redirect_uri", value: config.redirectUri),
                .init(name: "response_type", value: "code"),
                .init(name: "scope", value: config.scope),
                .init(name: "force_login", value: "true")
            ]
            guard let url = comps.url,
                  let scheme = URL(string: config.redirectUri)?.scheme else {
                cont.resume(throwing: AppError(mastodon: .invalidAuthorizationURL))
                return
            }
            
            DispatchQueue.main.async { // ASWebAuthenticationSession must be started on the main thread
                let session = ASWebAuthenticationSession(url: url, callbackURLScheme: scheme) { callbackURL, error in
                    if let err = error {
                        if let ae = err as? ASWebAuthenticationSessionError, ae.code == .canceledLogin {
                            cont.resume(throwing: AppError(mastodon: .userCancelledAuth))
                        } else {
                            cont.resume(throwing: err)
                        }
                        return
                    }
                    guard let code = URLComponents(url: callbackURL!, resolvingAgainstBaseURL: false)?
                        .queryItems?.first(where: { $0.name == "code" })?.value else {
                        cont.resume(throwing: AppError(mastodon: .missingAuthorizationCode))
                        return
                    }
                    cont.resume(returning: code)
                }
                
                // 'self' conforms to ASWebAuthenticationPresentationContextProviding only on iOS
                session.presentationContextProvider = self
                session.prefersEphemeralWebBrowserSession = true
                if !session.start() {
                    cont.resume(throwing: AppError(mastodon: .webAuthSessionFailed))
                }
                self.webAuthSession = session
            }
        }
    }
    #endif
    
    // MARK: - User Management (Shared Logic)
    
    private func saveInstanceURL(_ url: URL) async throws {
        try await KeychainHelper.shared.save(url.absoluteString, service: keychainService, account: "baseURL")
        logger.info("Saved instance URL to Keychain")
    }
    
    private func fetchAndUpdateUser() async throws {
        currentUser = try await mastodonAPIService.fetchCurrentUser()
        // NotificationCenter might be used differently or not at all on watchOS for this
        #if os(iOS)
        NotificationCenter.default.post(name: .didAuthenticate, object: self.currentUser)
        #endif
        logger.info("Updated authenticated user: \(self.currentUser?.username ?? "Unknown")")
    }
    
    /// Updates the currently authenticated user's data.
    func updateAuthenticatedUser(_ user: User) {
        self.currentUser = user
        logger.info("Authenticated user data updated locally.")
    }

    func logout() async {
        do {
            try await clearCredentials()
            logger.info("User logged out successfully")
        } catch {
            logger.error("Logout failed: \(error.localizedDescription)")
        }
    }
    
    func clearCredentials() async throws {
        let keys = ["baseURL","accessToken","clientID","clientSecret","expiresIn"]
        for k in keys {
            try await KeychainHelper.shared.delete(service: keychainService, account: k)
        }
        currentUser = nil
        isAuthenticated = false
        // NotificationCenter might be used differently or not at all on watchOS
        #if os(iOS)
        NotificationCenter.default.post(name: .authenticationFailed, object: nil)
        #endif
        logger.info("Cleared all authentication credentials")
    }
}

// Conditionally conform to ASWebAuthenticationPresentationContextProviding on iOS
#if os(iOS)
extension AuthenticationService: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // This needs to return the key window.
        // Ensure this code runs on the main thread.
        // @MainActor on the class handles this for the method itself.
        guard let windowScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else {
            // Fallback if no active window scene is found (e.g., app is in background)
            // This might happen if the auth flow is triggered from a background task, which is unusual.
            // Consider logging this case or returning a default ASPresentationAnchor from a newly created UIWindow if necessary,
            // though that's more complex and usually not required for typical auth flows.
            logger.warning("Could not find active UIWindowScene for ASWebAuthenticationSession. Using fallback anchor.")
            return ASPresentationAnchor()
        }
        return windowScene.windows.first { $0.isKeyWindow } ?? ASPresentationAnchor() // Fallback to any window in the scene if no key window.
    }
}
#endif

// Removed the outer #if canImport(UIKit) ... #endif as the conditional compilation is now granular using #if os(iOS).
