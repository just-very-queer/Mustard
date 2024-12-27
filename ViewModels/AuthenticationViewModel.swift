//
//  AuthenticationViewModel.swift
//  Mustard
//
//  Created by Your Name on [Date].
//

import SwiftUI
import Combine
import AuthenticationServices

@MainActor
class AuthenticationViewModel: NSObject, ObservableObject, ASWebAuthenticationPresentationContextProviding {
    
    // MARK: - Published Properties
    
    /// If `true`, the user is considered logged in.
    @Published var isAuthenticated: Bool = false
    
    /// The currently selected instance URL.
    @Published var instanceURL: URL? = nil
    
    /// Used to display error messages in the UI.
    @Published var alertError: AppError?
    
    /// Indicates whether we are currently in the process of authenticating (showing a spinner).
    @Published var isAuthenticating: Bool = false
    
    /// The user-provided custom instance URL string (e.g., "https://mastodon.social").
    @Published var customInstanceURL: String = ""
    
    // MARK: - Private Properties
    
    /// We use `var` instead of `let` so we can assign `mastodonService.baseURL = ...`.
    private var mastodonService: MastodonServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(mastodonService: MastodonServiceProtocol) {
        self.mastodonService = mastodonService
        super.init()
        
        // Observe changes to instanceURL; auto-load token from Keychain if present.
        $instanceURL
            .sink { [weak self] url in
                guard let self = self, let url = url else { return }
                do {
                    self.mastodonService.baseURL = url
                    
                    // Attempt to retrieve an existing token from Keychain.
                    if let token = try self.mastodonService.retrieveAccessToken(),
                       !token.isEmpty {
                        self.isAuthenticated = true
                        print("[AuthenticationViewModel] Found stored token for \(url). User is authenticated.")
                    } else {
                        self.isAuthenticated = false
                        print("[AuthenticationViewModel] No token found for \(url).")
                    }
                } catch {
                    self.alertError = AppError(message: "Failed to retrieve token: \(error.localizedDescription)")
                    print("[AuthenticationViewModel] Error retrieving token: \(error)")
                }
            }
            .store(in: &cancellables)
        
        // If the user had a previously set baseURL (e.g., from last session), load it.
        if let existingURL = try? mastodonService.retrieveInstanceURL() {
            self.instanceURL = existingURL
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Public Methods
    
    /// Called to authenticate with a user-input custom URL (or default).
    /// You might do an OAuth flow or a direct token exchange here.
    func authenticate() async {
        guard let url = URL(string: customInstanceURL.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            self.alertError = AppError(message: "Invalid URL. Please try again.")
            return
        }
        
        // Update the instance URL (this will trigger the sink above).
        self.instanceURL = url
        
        isAuthenticating = true
        defer { isAuthenticating = false }
        
        // Simulate success by storing a mock token in Keychain.
        do {
            try mastodonService.saveAccessToken("mockAccessToken1234")
            print("[AuthenticationViewModel] Access token saved. Marking user as authenticated.")
            self.isAuthenticated = true
        } catch {
            self.alertError = AppError(message: "Failed to save token: \(error.localizedDescription)")
            self.isAuthenticated = false
        }
    }
    
    /// Logs out the user by clearing the Keychain token, flipping isAuthenticated to false.
    func logout() {
        do {
            try mastodonService.clearAccessToken()
            isAuthenticated = false
            print("[AuthenticationViewModel] User logged out.")
        } catch {
            alertError = AppError(message: "Failed to clear access token: \(error.localizedDescription)")
            print("[AuthenticationViewModel] Failed to clear access token: \(error)")
        }
    }
    
    // MARK: - ASWebAuthenticationPresentationContextProviding
    
    /// Returns the presentation anchor (UIWindow) for ASWebAuthenticationSession.
    /// `UIApplication.shared.windows` is deprecated on iOS 15; prefer UIWindowScene.
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        #if os(iOS)
        // iOS 15+ approach:
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first(where: { $0.isKeyWindow })
        else {
            // Fallback if no main window found
            return UIWindow()
        }
        return window
        #else
        return ASPresentationAnchor()
        #endif
    }
}

