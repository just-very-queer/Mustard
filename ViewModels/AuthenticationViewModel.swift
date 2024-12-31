//
//  AuthenticationViewModel.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 30/12/24.
//

import SwiftUI
import Combine
import AuthenticationServices

@MainActor
class AuthenticationViewModel: NSObject, ObservableObject, ASWebAuthenticationPresentationContextProviding {
    
    // MARK: - Published Properties
    
    @Published var isAuthenticated: Bool = false
    @Published var alertError: AppError?
    @Published var isAuthenticating: Bool = false
    
    // MARK: - Private Properties
    
    private var mastodonService: MastodonServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(mastodonService: MastodonServiceProtocol) {
        self.mastodonService = mastodonService
        super.init()
    }
    
    // MARK: - Public Methods
    
    /// Initiates OAuth authentication with the selected server.
    /// - Parameter server: The selected Mastodon server.
    func authenticate(with server: Server) async throws {
        isAuthenticating = true
        alertError = nil

        do {
            // 1. Register OAuth App
            let config = try await mastodonService.registerOAuthApp(instanceURL: server.url)
            
            // 2. Set BaseURL and save to Keychain **before** exchanging the code
            if let service = mastodonService as? MastodonService {
                service.baseURL = server.url
                try KeychainHelper.shared.save(server.url.absoluteString, service: "Mustard-baseURL", account: "baseURL")
                print("[AuthenticationViewModel] baseURL set to: \(server.url.absoluteString)")
            }
            
            // 3. Authenticate OAuth and get authorization code
            let authorizationCode = try await mastodonService.authenticateOAuth(instanceURL: server.url, config: config)
            
            // 4. Exchange authorization code for access token
            try await mastodonService.exchangeAuthorizationCode(authorizationCode, config: config, instanceURL: server.url)
            
            // 5. Update authentication status
            self.isAuthenticated = true
            print("[AuthenticationViewModel] Authentication successful.")
        } catch {
            self.alertError = AppError(message: "Authentication failed: \(error.localizedDescription)")
            self.isAuthenticated = false
            print("[AuthenticationViewModel] Authentication failed with error: \(error.localizedDescription)")
            throw error
        }

        isAuthenticating = false
    }

    
    /// Logs out the user by clearing the access token.
    func logout() {
        do {
            try mastodonService.clearAccessToken()
            isAuthenticated = false
            print("[AuthenticationViewModel] Logged out successfully.")
        } catch {
            alertError = AppError(message: "Failed to log out: \(error.localizedDescription)")
            print("[AuthenticationViewModel] Logout failed with error: \(error.localizedDescription)")
        }
    }
    
    /// Validates existing authentication by checking the stored access token.
    func validateAuthentication() async {
        do {
            if let token = try mastodonService.retrieveAccessToken(),
               let baseURL = try mastodonService.retrieveInstanceURL(),
               !token.isEmpty {
                mastodonService.baseURL = baseURL
                print("[AuthenticationViewModel] Retrieved baseURL and token from MastodonService.")
                try await mastodonService.validateToken()
                self.isAuthenticated = true
                print("[AuthenticationViewModel] Token validated successfully.")
            } else {
                self.isAuthenticated = false
                print("[AuthenticationViewModel] No valid token or baseURL found.")
            }
        } catch {
            self.isAuthenticated = false
            self.alertError = AppError(message: "Authentication validation failed: \(error.localizedDescription)")
            print("[AuthenticationViewModel] Authentication validation failed with error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - ASWebAuthenticationPresentationContextProviding
    
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // Provide the current window as the presentation anchor
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first(where: { $0.isKeyWindow }) else {
            return UIWindow()
        }
        return window
    }
}

