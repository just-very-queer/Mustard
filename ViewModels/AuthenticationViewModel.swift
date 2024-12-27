//
//  AuthenticationViewModel.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 26/04/25.
//

import Foundation
import SwiftUI
import AuthenticationServices

/// ViewModel responsible for handling authentication with the Mastodon API.
@MainActor
class AuthenticationViewModel: NSObject, ObservableObject, ASWebAuthenticationPresentationContextProviding {
    
    // MARK: - Published Properties
    
    /// Indicates whether the user is authenticated.
    @Published var isAuthenticated: Bool = false
    
    /// The URL of the Mastodon instance being used.
    @Published var instanceURL: URL?
    
    /// An optional error to display alerts.
    @Published var alertError: AppError?
    
    /// Indicates whether an authentication session is in progress.
    @Published var isAuthenticating: Bool = false
    
    /// The custom instance URL entered by the user.
    @Published var customInstanceURL: String = ""
    
    // MARK: - Private Properties
    
    private var clientID: String?
    private var clientSecret: String?
    private let redirectURI = "mustard://oauth-callback"
    private let scopes = "read write follow"
    
    private var session: ASWebAuthenticationSession?
    
    /// The Mastodon service handling API interactions.
    private var mastodonService: MastodonServiceProtocol // Changed from 'let' to 'var'
    
    // MARK: - Nested Structures
    
    /// Represents the app credentials received after registration.
    private struct AppCredentials: Codable {
        let id: String
        let client_id: String
        let client_secret: String
        let redirect_uri: String
        let vapid_key: String?
    }
    
    /// Represents the token response after successful authentication.
    private struct TokenResponse: Codable {
        let access_token: String
        let token_type: String
        let scope: String
        let created_at: Int
    }
    
    // MARK: - Initialization
    
    /// Initializes the AuthenticationViewModel with a Mastodon service.
    /// - Parameter mastodonService: The service to interact with Mastodon APIs.
    init(mastodonService: MastodonServiceProtocol) {
        self.mastodonService = mastodonService
        super.init()
        
        // If there's already an access token in the Mastodon service, consider the user authenticated.
        if mastodonService.accessToken != nil && mastodonService.baseURL != nil {
            self.isAuthenticated = true
            self.instanceURL = mastodonService.baseURL
        }
        
        // Listen for OAuth callback notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOAuthCallback(notification:)),
            name: .didReceiveOAuthCallback,
            object: nil
        )
        
        // Listen for Account Selection notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAccountSelection(notification:)),
            name: .didSelectAccount,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Public Methods
    
    /// Starts the authentication flow by registering the app and initiating OAuth.
    func authenticate() async {
        guard !customInstanceURL.isEmpty else {
            self.alertError = AppError(message: "Instance URL is empty.")
            return
        }
        
        guard let url = URL(string: customInstanceURL) else {
            self.alertError = AppError(message: "Invalid instance URL format.")
            return
        }
        
        // If the user selects a new instance, log out from the previous session.
        if isAuthenticated {
            logout()
        }
        
        self.instanceURL = url
        
        do {
            isAuthenticating = true
            try await registerApp()
            try await startAuthentication()
        } catch {
            print("Authentication process failed: \(error.localizedDescription)")
            self.alertError = AppError(message: "Authentication failed. Please try again.")
        }
        
        isAuthenticating = false
    }
    
    /// Logs out the user, clearing credentials and resetting flags.
    func logout() {
        // Clear access token and baseURL from the service
        mastodonService.baseURL = nil
        mastodonService.accessToken = nil
        
        isAuthenticated = false
        clientID = nil
        clientSecret = nil
        instanceURL = nil
    }
    
    // MARK: - Private Methods
    
    /// Registers the app with the Mastodon instance.
    private func registerApp() async throws {
        guard let instanceURL = instanceURL else {
            throw AppError(message: "Instance URL not set.")
        }
        
        let appsURL = instanceURL.appendingPathComponent("/api/v1/apps")
        var request = URLRequest(url: appsURL)
        request.httpMethod = "POST"
        
        let parameters = [
            "client_name": "Mustard",
            "redirect_uris": redirectURI,
            "scopes": scopes,
            "website": "https://yourappwebsite.com" // Replace with your app's website
        ]
        
        request.httpBody = parameters
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
            .joined(separator: "&")
            .data(using: .utf8)
        
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response)
        
        let appCredentials = try JSONDecoder().decode(AppCredentials.self, from: data)
        self.clientID = appCredentials.client_id
        self.clientSecret = appCredentials.client_secret
    }
    
    /// Initiates the OAuth authentication process using ASWebAuthenticationSession.
    private func startAuthentication() async throws {
        guard let instanceURL = instanceURL,
              let clientID = clientID else {
            throw AppError(message: "Instance URL or client ID not set.")
        }
        
        // Build the authorization URL
        let authURL = instanceURL.appendingPathComponent("/oauth/authorize")
        var components = URLComponents(url: authURL, resolvingAgainstBaseURL: true)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scopes)
        ]
        
        guard let url = components.url else {
            throw AppError(message: "Failed to construct authentication URL.")
        }
        
        try await authenticateWithWeb(url: url)
    }
    
    /// Launches ASWebAuthenticationSession to perform OAuth authentication.
    /// - Parameter url: The authorization URL.
    private func authenticateWithWeb(url: URL) async throws {
        isAuthenticating = true
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: "mustard"
            ) { [weak self] callbackURL, error in
                guard let self = self else {
                    continuation.resume(throwing: AppError(message: "Self is nil."))
                    return
                }
                
                if let error = error {
                    // Check if the error is due to user cancellation
                    if (error as NSError).code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                        continuation.resume(throwing: AppError(message: "Authentication was canceled by the user."))
                    } else {
                        continuation.resume(throwing: AppError(message: "Authentication failed: \(error.localizedDescription)"))
                    }
                    return
                }
                
                guard let callbackURL = callbackURL else {
                    continuation.resume(throwing: AppError(message: "Invalid callback URL."))
                    return
                }
                
                // Handle the callback URL
                NotificationCenter.default.post(name: .didReceiveOAuthCallback, object: nil, userInfo: ["url": callbackURL])
                
                continuation.resume()
            }
            
            #if os(iOS)
            session?.presentationContextProvider = self
            session?.prefersEphemeralWebBrowserSession = true
            #endif
            session?.start()
        }
    }
    
    /// Fetches the access token using the authorization code.
    /// - Parameter code: The authorization code received from the OAuth callback.
    private func fetchAccessToken(code: String) async throws {
        guard let instanceURL = instanceURL,
              let clientID = clientID,
              let clientSecret = clientSecret else {
            throw AppError(message: "Instance URL or client credentials not set.")
        }
        
        let tokenURL = instanceURL.appendingPathComponent("/oauth/token")
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        
        let parameters = [
            "client_id": clientID,
            "client_secret": clientSecret,
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": redirectURI,
            "scope": scopes
        ]
        
        request.httpBody = parameters
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
            .joined(separator: "&")
            .data(using: .utf8)
        
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response)
        
        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        
        // Store the access token securely via MastodonServiceProtocol
        try mastodonService.saveAccessToken(tokenResponse.access_token)
        mastodonService.baseURL = instanceURL
        
        self.isAuthenticated = true
    }
    
    /// Validates the HTTP response.
    /// - Parameter response: The URL response to validate.
    private func validateResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError(message: "Invalid response.")
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw AppError(message: "HTTP Error: \(httpResponse.statusCode)")
        }
    }
    
    // MARK: - ASWebAuthenticationPresentationContextProviding
    
    /// Provides the presentation anchor for ASWebAuthenticationSession.
    /// - Parameter session: The authentication session requesting the anchor.
    /// - Returns: The presentation anchor.
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        #if os(iOS)
        // iOS-specific code
        if let windowScene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
           let window = windowScene.windows.first(where: { $0.isKeyWindow }) {
            return window
        }
        return UIWindow()
        #elseif os(macOS)
        return NSApplication.shared.windows.first ?? NSWindow()
        #else
        return ASPresentationAnchor()
        #endif
    }
    
    // MARK: - OAuth Callback Handling via Notification
    
    /// Handles the OAuth callback by extracting the authorization code.
    /// - Parameter notification: The notification containing the callback URL.
    @objc private func handleOAuthCallback(notification: Notification) {
        guard let url = notification.userInfo?["url"] as? URL else { return }
        Task {
            await handleCallback(url: url)
        }
    }
    
    /// Processes the OAuth callback URL to retrieve the authorization code and fetch the access token.
    /// - Parameter url: The callback URL containing the authorization code.
    private func handleCallback(url: URL) async {
        // Extract the "code" from the callback URL
        guard let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
              let code = queryItems.first(where: { $0.name == "code" })?.value else {
            self.alertError = AppError(message: "No authorization code found.")
            return
        }
        
        do {
            try await fetchAccessToken(code: code)
            // Notify that authentication succeeded
            NotificationCenter.default.post(name: .didAuthenticate, object: nil)
        } catch {
            self.alertError = AppError(message: "Authentication failed. Please try again.")
        }
    }
    
    /// Handles account selection by updating the instance URL and access token.
    /// - Parameter notification: The notification containing the selected account.
    @objc private func handleAccountSelection(notification: Notification) {
        guard let account = notification.userInfo?["account"] as? Account else { return }
        self.instanceURL = account.instanceURL
        
        // Set directly since accessToken is get and set
        mastodonService.baseURL = account.instanceURL
        mastodonService.accessToken = account.accessToken
        
        self.isAuthenticated = true
        
        // Fetch the timeline for the selected account
        Task {
            // Post a didAuthenticate notification to trigger TimelineViewModel's fetch
            NotificationCenter.default.post(name: .didAuthenticate, object: nil)
        }
    }
}

