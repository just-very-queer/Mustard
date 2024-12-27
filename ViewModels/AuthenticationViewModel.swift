//
//  AuthenticationViewModel.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on [Date].
//

import Foundation
import SwiftUI
import AuthenticationServices

@MainActor
class AuthenticationViewModel: NSObject, ObservableObject, ASWebAuthenticationPresentationContextProviding {

    // MARK: - Published Properties
    @Published var isAuthenticated: Bool = false
    @Published var instanceURL: URL?
    @Published var alertError: AppError?
    @Published var isAuthenticating: Bool = false
    @Published var customInstanceURL: String = SampleServers.servers.first?.url.absoluteString ?? ""

    // MARK: - Private Properties
    private var clientID: String?
    private var clientSecret: String?
    private let redirectURI = "mustard://oauth-callback"
    private let scopes = "read write follow"
    private var session: ASWebAuthenticationSession?
    private var mastodonService: MastodonServiceProtocol

    // MARK: - Initialization
    init(mastodonService: MastodonServiceProtocol) {
        self.mastodonService = mastodonService
        super.init()

        // Attempt to retrieve access token and base URL from the service
        do {
            if let token = try mastodonService.retrieveAccessToken(),
               let url = try mastodonService.retrieveInstanceURL() {
                self.isAuthenticated = true
                self.instanceURL = url
                print("AuthenticationViewModel initialized with baseURL: \(url) and accessToken: \(token)") // Debug statement
            } else {
                print("AuthenticationViewModel initialized without authentication.") // Debug statement
            }
        } catch {
            self.alertError = AppError(message: "Failed to retrieve authentication details.")
            print("AuthenticationViewModel: Failed to retrieve authentication details: \(error.localizedDescription)")
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOAuthCallback(notification:)),
            name: .didReceiveOAuthCallback,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Public Methods

    /// Initiates the authentication process by registering the app and starting the OAuth flow.
    func authenticate() async {
        // Validate the custom instance URL
        guard let url = URL(string: customInstanceURL.trimmingCharacters(in: .whitespacesAndNewlines)),
              UIApplication.shared.canOpenURL(url) else {
            self.alertError = AppError(message: "Invalid or unreachable instance URL.")
            print("AuthenticationViewModel: Invalid or unreachable instance URL.")
            return
        }

        self.instanceURL = url

        do {
            isAuthenticating = true
            defer { isAuthenticating = false }
            try await registerApp()
            try await startAuthentication()
        } catch {
            self.alertError = AppError(message: "Authentication failed: \(error.localizedDescription)")
            print("AuthenticationViewModel: Authentication failed: \(error.localizedDescription)")
        }
    }

    /// Logs out the user by clearing the access token and resetting authentication state.
    func logout() {
        do {
            try mastodonService.clearAccessToken()
            isAuthenticated = false
            clientID = nil
            clientSecret = nil
            instanceURL = nil
            print("AuthenticationViewModel: User logged out successfully.")
        } catch {
            self.alertError = AppError(message: "Failed to clear access token: \(error.localizedDescription)")
            print("AuthenticationViewModel: Failed to clear access token: \(error.localizedDescription)")
        }
    }

    // MARK: - Private Methods

    /// Registers the app with the Mastodon instance to obtain client credentials.
    private func registerApp() async throws {
        guard let instanceURL = instanceURL else {
            throw AppError(message: "Instance URL is missing.")
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

        print("AuthenticationViewModel: Registering app at URL: \(appsURL)")
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response)

        // Parse the response to extract client_id and client_secret
        if let jsonResponse = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
            guard let clientID = jsonResponse["client_id"] as? String,
                  let clientSecret = jsonResponse["client_secret"] as? String else {
                throw AppError(message: "Failed to parse app registration response.")
            }
            self.clientID = clientID
            self.clientSecret = clientSecret
            print("AuthenticationViewModel: App registered successfully with clientID: \(clientID) and clientSecret: \(clientSecret)")
        } else {
            throw AppError(message: "Failed to parse app registration response.")
        }
    }

    /// Starts the OAuth authentication process by initiating a web authentication session.
    private func startAuthentication() async throws {
        guard let instanceURL = instanceURL, let clientID = clientID else {
            throw AppError(message: "Instance URL or client ID not set.")
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
            throw AppError(message: "Failed to construct authentication URL.")
        }

        print("AuthenticationViewModel: Starting authentication with URL: \(url)")
        try await authenticateWithWeb(url: url)
    }

    /// Initiates the web authentication session using ASWebAuthenticationSession.
    private func authenticateWithWeb(url: URL) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            session = ASWebAuthenticationSession(url: url, callbackURLScheme: "mustard") { callbackURL, error in
                if let error = error {
                    continuation.resume(throwing: AppError(message: "Authentication failed: \(error.localizedDescription)"))
                    return
                }

                guard let callbackURL = callbackURL else {
                    continuation.resume(throwing: AppError(message: "Invalid callback URL."))
                    return
                }

                NotificationCenter.default.post(name: .didReceiveOAuthCallback, object: nil, userInfo: ["url": callbackURL])
                continuation.resume() // Success case
            }

            session?.presentationContextProvider = self
            session?.start()
        }
    }

    /// Validates the HTTP response, throwing an error for unsuccessful status codes.
    private func validateResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            print("AuthenticationViewModel: HTTP Error: \(statusCode)")
            throw AppError(message: "HTTP Error: \(statusCode)")
        }
        print("AuthenticationViewModel: Response validated with status code: \((response as? HTTPURLResponse)?.statusCode ?? 0)")
    }

    /// Handles the OAuth callback by extracting the authorization code and fetching the access token.
    @objc private func handleOAuthCallback(notification: Notification) {
        guard let url = notification.userInfo?["url"] as? URL else { return }

        // Extract "code" and fetch access token
        Task {
            guard let code = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?
                .first(where: { $0.name == "code" })?
                .value else {
                alertError = AppError(message: "No authorization code found.")
                print("AuthenticationViewModel: No authorization code found in callback URL.")
                return
            }

            do {
                try await fetchAccessToken(code: code)
                isAuthenticated = true
                print("AuthenticationViewModel: Authentication successful.")
                // Post authentication success notification
                NotificationCenter.default.post(name: .didAuthenticate, object: nil)
            } catch {
                alertError = AppError(message: "Failed to fetch access token: \(error.localizedDescription)")
                print("AuthenticationViewModel: Failed to fetch access token: \(error.localizedDescription)")
            }
        }
    }

    /// Exchanges the authorization code for an access token and saves it securely.
    private func fetchAccessToken(code: String) async throws {
        guard let instanceURL = instanceURL,
              let clientID = clientID,
              let clientSecret = clientSecret else {
            throw AppError(message: "Missing parameters for token exchange.")
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

        print("AuthenticationViewModel: Exchanging code for access token at URL: \(tokenURL)")
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response)

        // Parse the response to extract the access token
        if let jsonResponse = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
           let token = jsonResponse["access_token"] as? String {
            mastodonService.baseURL = instanceURL // Set baseURL first
            print("AuthenticationViewModel: baseURL set to: \(instanceURL)")
            try mastodonService.saveAccessToken(token) // Then save access token
            print("AuthenticationViewModel: Access token saved successfully.")
        } else {
            throw AppError(message: "Failed to parse token response.")
        }
    }

    // MARK: - ASWebAuthenticationPresentationContextProviding

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        #if os(iOS)
        return UIApplication.shared.windows.first { $0.isKeyWindow } ?? UIWindow()
        #else
        return ASPresentationAnchor()
        #endif
    }
}

