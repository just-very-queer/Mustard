//
//  AuthenticationViewModel.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 14/09/24.
//

import Foundation
import SwiftUI
import AuthenticationServices

/// A view model responsible for handling authentication with the Mastodon API.
@MainActor
class AuthenticationViewModel: NSObject, ObservableObject, ASWebAuthenticationPresentationContextProviding {
    
    // MARK: - Published Properties
    
    /// Indicates whether the user is authenticated.
    @Published var isAuthenticated: Bool = false
    
    /// The URL of the Mastodon instance being used.
    @Published var instanceURL: URL?
    
    /// An optional error to display alerts.
    @Published var alertError: MustardAppError?
    
    // MARK: - Private Properties
    
    private var clientID: String?
    private var clientSecret: String?
    private let redirectURI = "mustard://oauth-callback"
    private let scopes = "read write follow"
    
    private var session: ASWebAuthenticationSession?
    
    private var mastodonService: MastodonServiceProtocol // Changed from 'let' to 'var'
    
    // MARK: - Nested Structures
    
    /// Represents the credentials returned after registering the app with Mastodon.
    struct AppCredentials: Codable {
        let id: String
        let client_id: String
        let client_secret: String
        let redirect_uri: String
        let vapid_key: String?
    }
    
    /// Represents the token response received after exchanging the authorization code.
    struct TokenResponse: Codable {
        let access_token: String
        let token_type: String
        let scope: String
        let created_at: Int
    }
    
    // MARK: - Initialization
    
    /// Initializes the view model with a Mastodon service.
    /// - Parameter mastodonService: The service to use for Mastodon interactions.
    init(mastodonService: MastodonServiceProtocol) { // Removed default parameter
        self.mastodonService = mastodonService
        super.init()
        // Check if accessToken exists to determine authentication status
        if accessToken != nil {
            isAuthenticated = true
            // Set the baseURL in MastodonService if authenticated
            self.mastodonService.baseURL = instanceURL
        }
    }
    
    // MARK: - Computed Properties
    
    /// Retrieves the access token from the Keychain.
    private var accessToken: String? {
        get {
            guard let instanceURL = instanceURL else { return nil }
            let service = "Mustard-\(instanceURL.host ?? "")"
            return KeychainHelper.shared.read(service: service, account: "accessToken")
        }
        set {
            guard let instanceURL = instanceURL else { return }
            let service = "Mustard-\(instanceURL.host ?? "")"
            if let token = newValue {
                KeychainHelper.shared.save(token, service: service, account: "accessToken")
            } else {
                KeychainHelper.shared.delete(service: service, account: "accessToken")
            }
        }
    }
    
    // MARK: - Authentication Methods
    
    /// Initiates the authentication process by registering the app and starting the authentication session.
    func authenticate() async {
        guard instanceURL != nil else { // Replaced 'let baseURL = instanceURL' with a boolean test
            print("Instance URL not set.")
            self.alertError = MustardAppError(message: "Instance URL is not set.")
            return
        }
        
        do {
            try await registerApp()
            try await startAuthentication()
        } catch {
            print("Authentication process failed: \(error.localizedDescription)")
            self.alertError = MustardAppError(message: "Authentication process failed. Please try again.")
        }
    }
    
    /// Registers the app with the Mastodon instance to obtain client credentials.
    private func registerApp() async throws {
        guard let instanceURL = instanceURL else {
            throw MustardAppError(message: "Instance URL not set.")
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
            .compactMap { key, value in "\(key)=\(value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
            .joined(separator: "&")
            .data(using: .utf8)
        
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // Perform the network request to register the app
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Validate response
        try validateResponse(response)
        
        do {
            let appCredentials = try JSONDecoder().decode(AppCredentials.self, from: data)
            self.clientID = appCredentials.client_id
            self.clientSecret = appCredentials.client_secret
        } catch {
            print("Failed to decode app credentials: \(error.localizedDescription)")
            throw MustardAppError(message: "Failed to decode app credentials.")
        }
    }
    
    /// Starts the web authentication session to obtain the authorization code.
    private func startAuthentication() async throws {
        guard let instanceURL = instanceURL,
              let clientID = clientID else {
            throw MustardAppError(message: "Instance URL or client ID not set.")
        }
        
        let authURL = instanceURL.appendingPathComponent("/oauth/authorize")
        var components = URLComponents(url: authURL, resolvingAgainstBaseURL: true)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scopes)
        ]
        
        guard let url = components.url else {
            throw MustardAppError(message: "Failed to construct authentication URL.")
        }
        
        let callbackURL = try await authenticateWithWeb(url: url)
        
        guard let queryItems = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?.queryItems,
              let code = queryItems.first(where: { $0.name == "code" })?.value else {
            throw MustardAppError(message: "No authorization code found.")
        }
        
        try await fetchAccessToken(code: code)
    }
    
    /// Exchanges the authorization code for an access token.
    /// - Parameter code: The authorization code received from the authentication session.
    private func fetchAccessToken(code: String) async throws {
        guard let instanceURL = instanceURL,
              let clientID = clientID,
              let clientSecret = clientSecret else {
            throw MustardAppError(message: "Instance URL or client credentials not set.")
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
            .compactMap { key, value in "\(key)=\(value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
            .joined(separator: "&")
            .data(using: .utf8)
        
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // Perform the network request to obtain the access token
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Validate response
        try validateResponse(response)
        
        do {
            let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
            self.accessToken = tokenResponse.access_token
            self.isAuthenticated = true
            mastodonService.baseURL = self.instanceURL // Allowed now as 'mastodonService' is mutable
        } catch {
            print("Token response decoding error: \(error.localizedDescription)")
            throw MustardAppError(message: "Failed to decode token response.")
        }
    }
    
    /// Logs out the user by clearing stored credentials.
    func logout() {
        accessToken = nil
        isAuthenticated = false
        clientID = nil
        clientSecret = nil
        mastodonService.baseURL = nil // Allowed now as 'mastodonService' is mutable
    }
    
    // MARK: - ASWebAuthenticationPresentationContextProviding
    
    /// Provides the presentation anchor for the authentication session.
    /// - Parameter session: The authentication session requesting the anchor.
    /// - Returns: The window to present the authentication session.
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        #if os(iOS)
        // Iterate through connected scenes to find the active UIWindowScene
        if let windowScene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
           let window = windowScene.windows.first(where: { $0.isKeyWindow }) {
            return window
        } else {
            return UIWindow()
        }
        #elseif os(macOS)
        return NSApplication.shared.windows.first ?? NSWindow()
        #else
        return UIWindow()
        #endif
    }
    
    // MARK: - Helper Methods
    
    /// Authenticates with the web by starting an ASWebAuthenticationSession and awaiting the callback URL.
    /// - Parameter url: The authentication URL to open.
    /// - Returns: The callback URL containing the authorization code.
    private func authenticateWithWeb(url: URL) async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in
            session = ASWebAuthenticationSession(url: url, callbackURLScheme: "mustard") { callbackURL, error in
                if let error = error {
                    print("Authentication error: \(error.localizedDescription)")
                    continuation.resume(throwing: MustardAppError(message: "Authentication failed. Please try again."))
                    return
                }
                
                guard let callbackURL = callbackURL else {
                    print("No callback URL received.")
                    continuation.resume(throwing: MustardAppError(message: "No callback URL received."))
                    return
                }
                
                continuation.resume(returning: callbackURL)
            }
            
            session?.presentationContextProvider = self
            session?.prefersEphemeralWebBrowserSession = true
            session?.start()
        }
    }
    
    /// Validates the HTTP response.
    /// - Parameter response: The URLResponse to validate.
    /// - Throws: `MustardAppError` if the response status code is not 200-299.
    private func validateResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw MustardAppError(message: "Invalid response.")
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw MustardAppError(message: "HTTP Error: \(httpResponse.statusCode)")
        }
    }
}
