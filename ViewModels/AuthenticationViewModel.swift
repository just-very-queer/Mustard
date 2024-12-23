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
    
    /// Make this `var` so we can modify `baseURL`.
    private var mastodonService: MastodonServiceProtocol
    
    // MARK: - Nested Structures
    
    struct AppCredentials: Codable {
        let id: String
        let client_id: String
        let client_secret: String
        let redirect_uri: String
        let vapid_key: String?
    }
    
    struct TokenResponse: Codable {
        let access_token: String
        let token_type: String
        let scope: String
        let created_at: Int
    }
    
    // MARK: - Initialization
    
    init(mastodonService: MastodonServiceProtocol) {
        self.mastodonService = mastodonService
        super.init()
        
        // If there's already an access token in the Keychain, we consider ourselves authenticated.
        if accessToken != nil {
            isAuthenticated = true
            // Attempt to set the baseURL from instanceURL if we have it
            self.mastodonService.baseURL = instanceURL
        }
    }
    
    // MARK: - Computed Properties
    
    /// Reads/writes the access token from Keychain.
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
    
    // MARK: - Public Methods
    
    /// Starts the authentication flow by registering our app with the Mastodon instance.
    func authenticate() async {
        guard instanceURL != nil else {
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
    
    /// Logs out the user, clearing credentials and resetting flags.
    func logout() {
        accessToken = nil
        isAuthenticated = false
        clientID = nil
        clientSecret = nil
        mastodonService.baseURL = nil
    }
    
    // MARK: - Private Methods
    
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
            "website": "https://yourappwebsite.com"
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
    
    private func startAuthentication() async throws {
        guard let instanceURL = instanceURL,
              let clientID = clientID else {
            throw MustardAppError(message: "Instance URL or client ID not set.")
        }
        
        // Build the authorize URL
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
        
        // Parse the "code" out of the callback URL
        guard let queryItems = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?.queryItems,
              let code = queryItems.first(where: { $0.name == "code" })?.value else {
            throw MustardAppError(message: "No authorization code found.")
        }
        
        try await fetchAccessToken(code: code)
    }
    
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
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
            .joined(separator: "&")
            .data(using: .utf8)
        
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response)
        
        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        
        // Store the access token
        self.accessToken = tokenResponse.access_token
        // Mark ourselves as authenticated
        self.isAuthenticated = true
        
        // Finally, set the Mastodon service baseURL
        mastodonService.baseURL = instanceURL
    }
    
    /// Launch an ASWebAuthenticationSession to open the login page and capture the callback.
    private func authenticateWithWeb(url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: "mustard"
            ) { callbackURL, error in
                if let error = error {
                    continuation.resume(
                        throwing: MustardAppError(message: "Authentication failed: \(error.localizedDescription)")
                    )
                    return
                }
                
                guard let callbackURL = callbackURL else {
                    continuation.resume(
                        throwing: MustardAppError(message: "No callback URL received.")
                    )
                    return
                }
                
                continuation.resume(returning: callbackURL)
            }
            
            #if os(iOS)
            session?.presentationContextProvider = self
            session?.prefersEphemeralWebBrowserSession = true
            #endif
            session?.start()
        }
    }
    
    private func validateResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw MustardAppError(message: "Invalid response.")
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw MustardAppError(message: "HTTP Error: \(httpResponse.statusCode)")
        }
    }
    
    // MARK: - ASWebAuthenticationPresentationContextProviding
    
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
        return UIWindow()
        #endif
    }
}

