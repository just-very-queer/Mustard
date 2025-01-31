//
//  AuthenticationViewModel.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 30/12/24.
//

import SwiftUI
import Combine
import OSLog

@MainActor
class AuthenticationViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var alertError: AppError?
    @Published var currentUser: User?

    private let logger = Logger(subsystem: "com.yourcompany.Mustard", category: "AuthenticationViewModel")
    private var authService = AuthenticationService.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        authService.$isAuthenticated
            .receive(on: RunLoop.main)
            .assign(to: \.isAuthenticated, on: self)
            .store(in: &cancellables)

        authService.$currentUser
            .receive(on: RunLoop.main)
            .assign(to: \.currentUser, on: self)
            .store(in: &cancellables)
        
        authService.$alertError
            .receive(on: RunLoop.main)
            .assign(to: \.alertError, on: self)
            .store(in: &cancellables)
    }

    func authenticate(to server: ServerModel) async {
        if authService.isAuthenticating {
            alertError = AppError(message: "Authentication is already in progress.")
            return
        }
        
        do {
            try await authService.authenticate(to: server)
            // On success, no action needed as isAuthenticated will be updated
        } catch let error as AppError {
            logger.error("Authentication failed: \(error.localizedDescription)")
            self.alertError = error
        } catch {
            logger.error("Unknown error during authentication.")
            self.alertError = AppError(message: "Authentication failed due to an unknown error.")
        }
    }

    func logout() {
        Task {
            await authService.logout()
        }
    }
}
