//
//  AuthenticationService.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 24/01/25.
//  Updated to use MastodonAPIService & NetworkSessionManager
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
    
    private let logger = Logger(subsystem: "titan.mustard.app.ao", category: "AuthenticationService")
    private let keychainService = "MustardKeychain"
    private let mastodonAPIService: MastodonAPIService
    private let sessionManager: NetworkSessionManager
    private var webAuthSession: ASWebAuthenticationSession?
    private var cancellables = Set<AnyCancellable>()
    private var alertErrorTimer: Timer?
    
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
    
    // MARK: - Credential Check
    
    private func checkExistingCredentials() {
        Task {
            do {
                try await verifyCredentials()
                logger.info("Credentials are valid.")
            } catch {
                logger.error("Credentials check failed: \(error.localizedDescription)")
                await MainActor.run { isAuthenticated = false }
                try? await clearCredentials()
            }
        }
    }
    
    private func verifyCredentials() async throws {
        // Validate by fetching current user
        currentUser = try await mastodonAPIService.fetchCurrentUser()
        isAuthenticated = true
    }
    
    // MARK: - Authentication Flow
    
    func authenticate(to server: ServerModel) async throws {
        guard !isAuthenticating else {
            throw AppError(mastodon: .operationInProgress)
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
            throw error
        }
        
        isAuthenticating = false
    }
    
    // MARK: - OAuth Config
    
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
    
    // MARK: - Token Exchange
    
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
    
    // MARK: - Error Handling
    
    func handleError(_ error: Error) {
        logger.error("Authentication error: \(error.localizedDescription)")
        alertErrorTimer?.invalidate()
        
        alertError = (error as? AppError) ?? AppError(message: "Authentication failed", underlyingError: error)
        
        alertErrorTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            self?.alertError = nil
        }
        
        if case .mastodon(.tokenExpired) = (error as? AppError)?.type {
            Task { try? await clearCredentials() }
        }
    }
    
    // MARK: - Web Auth
    
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.windows.first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
    
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
            
            DispatchQueue.main.async {
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
                
                session.presentationContextProvider = self
                session.prefersEphemeralWebBrowserSession = true
                if !session.start() {
                    cont.resume(throwing: AppError(mastodon: .webAuthSessionFailed))
                }
                self.webAuthSession = session
            }
        }
    }
    
    // MARK: - User Management
    
    private func saveInstanceURL(_ url: URL) async throws {
        try await KeychainHelper.shared.save(url.absoluteString, service: keychainService, account: "baseURL")
        logger.info("Saved instance URL to Keychain")
    }
    
    private func fetchAndUpdateUser() async throws {
        currentUser = try await mastodonAPIService.fetchCurrentUser()
        NotificationCenter.default.post(name: .didAuthenticate, object: self.currentUser)
        logger.info("Updated authenticated user: \(self.currentUser?.username ?? "Unknown")")
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
        NotificationCenter.default.post(name: .authenticationFailed, object: nil)
        logger.info("Cleared all authentication credentials")
    }
}
