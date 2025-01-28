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
    @Published var isAuthenticated = false
    @Published var isAuthenticating = false
    @Published var alertError: AppError?
    @Published var currentUser: User?
    
    private let authService: AuthenticationService
    private let logger = Logger(subsystem: "com.yourcompany.Mustard", category: "Authentication")
    
    var authenticationService: AuthenticationService {
        authService
    }
    
    private var authenticationTask: Task<Void, Never>?
    
    init(authenticationService: AuthenticationService) {
        self.authService = authenticationService
        super.init()
    }
    
    func authenticate(to server: ServerModel) async {
        guard !isAuthenticating else { return }
        isAuthenticating = true
        alertError = nil
        
        authenticationTask = Task {
            logger.info("Starting authentication for server: \(server.url.absoluteString, privacy: .public)")
            
            do {
                try await authService.authenticate(to: server)
                currentUser = authService.currentUser
                isAuthenticated = authService.isAuthenticated
                
                if isAuthenticated {
                    logger.info("Authentication successful for user: \(self.currentUser?.username ?? "Unknown", privacy: .public)")
                } else {
                    throw AppError(message: "Authentication failed without error")
                }
            } catch {
                isAuthenticated = false
                currentUser = nil
                logger.error("Authentication failed: \(error.localizedDescription, privacy: .public)")
                handleError(error)
            }
            
            isAuthenticating = false
        }
    }
    
    func validateAuthentication() async {
        isAuthenticating = true
        alertError = nil
        
        logger.info("Validating authentication status...")
        await authService.validateAuthentication()
        currentUser = authService.currentUser
        isAuthenticated = authService.isAuthenticated
        logger.info("Authentication validation completed. Status: \(self.isAuthenticated ? "Authenticated" : "Unauthenticated", privacy: .public)")
        isAuthenticating = false
    }
    
    func logout() async {
        isAuthenticating = true
        alertError = nil
        
        logger.info("Logging out...")
        await authService.logout()
        isAuthenticated = false
        currentUser = nil
        logger.info("Logout successful.")
        isAuthenticating = false
    }
    
    private func handleError(_ error: Error) {
        if let appError = error as? AppError {
            alertError = appError
            logger.error("AppError encountered: \(appError.message, privacy: .public)")
        } else {
            alertError = AppError(message: "An unexpected error occurred.", underlyingError: error)
            logger.error("Unknown error: \(error.localizedDescription, privacy: .public)")
        }
    }
    
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            logger.error("Could not get window scene.")
            return ASPresentationAnchor()
        }

        if let window = windowScene.windows.first(where: { $0.isKeyWindow }) {
            return window
        } else {
            logger.warning("No key window found, using a new window.")
            let fallbackWindow = UIWindow(windowScene: windowScene)
            fallbackWindow.makeKeyAndVisible()
            return fallbackWindow
        }
    }
}
