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
        if let token = try? mastodonService.retrieveAccessToken(),
           let url = try? mastodonService.retrieveInstanceURL() {
            self.isAuthenticated = true
            self.instanceURL = url
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
    func authenticate() async {
        guard let url = URL(string: customInstanceURL.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            self.alertError = AppError(message: "Invalid instance URL.")
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
        }
    }

    func logout() {
        do {
            try mastodonService.clearAccessToken()
            isAuthenticated = false
            clientID = nil
            clientSecret = nil
            instanceURL = nil
        } catch {
            alertError = AppError(message: "Failed to clear access token: \(error.localizedDescription)")
        }
    }

    // MARK: - Private Methods
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
            "website": "https://yourappwebsite.com"
        ]

        request.httpBody = parameters
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
            .joined(separator: "&")
            .data(using: .utf8)

        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response)

        if let jsonResponse = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
            self.clientID = jsonResponse["client_id"] as? String
            self.clientSecret = jsonResponse["client_secret"] as? String
        } else {
            throw AppError(message: "Failed to parse app registration response.")
        }
    }

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

        try await authenticateWithWeb(url: url)
    }

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

    private func validateResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw AppError(message: "HTTP Error: \((response as? HTTPURLResponse)?.statusCode ?? 0)")
        }
    }

    @objc private func handleOAuthCallback(notification: Notification) {
        guard let url = notification.userInfo?["url"] as? URL else { return }

        // Extract "code" and fetch access token
        Task {
            guard let code = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?
                .first(where: { $0.name == "code" })?
                .value else {
                alertError = AppError(message: "No authorization code found.")
                return
            }

            do {
                try await fetchAccessToken(code: code)
                isAuthenticated = true
                // Post authentication success notification
                NotificationCenter.default.post(name: .didAuthenticate, object: nil)
            } catch {
                alertError = AppError(message: "Failed to fetch access token: \(error.localizedDescription)")
            }
        }
    }

    private func fetchAccessToken(code: String) async throws {
        guard let instanceURL = instanceURL, let clientID = clientID, let clientSecret = clientSecret else {
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

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response)

        if let jsonResponse = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
           let token = jsonResponse["access_token"] as? String {
            try mastodonService.saveAccessToken(token)
            mastodonService.baseURL = instanceURL
        } else {
            throw AppError(message: "Failed to parse token response.")
        }
    }

    // MARK: - ASWebAuthenticationPresentationContextProviding
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        #if os(iOS)
        return UIApplication.shared.windows.first(where: { $0.isKeyWindow }) ?? UIWindow()
        #else
        return ASPresentationAnchor()
        #endif
    }
}

