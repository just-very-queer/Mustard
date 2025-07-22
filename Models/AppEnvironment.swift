//
//  AppEnvironment.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 22/07/25.
//

import SwiftUI
import Combine

@Observable
class AppEnvironment {
    var authState: AuthState = .checking
    var currentUser: User?
    var alertError: AppError?

    enum AuthState {
        case checking
        case unauthenticated
        case authenticating
        case authenticated
    }

    private var cancellables = Set<AnyCancellable>()

    init() {
        // This is a temporary solution to bridge the gap between the old and new architecture.
        // In the future, the AuthenticationService will be updated to directly publish
        // the required values without the need for this sink.
        AuthenticationService.shared.$isAuthenticated
            .sink { [weak self] isAuthenticated in
                if isAuthenticated {
                    self?.authState = .authenticated
                } else {
                    self?.authState = .unauthenticated
                }
            }
            .store(in: &cancellables)

        AuthenticationService.shared.$currentUser
            .assign(to: \.currentUser, on: self)
            .store(in: &cancellables)

        AuthenticationService.shared.$alertError
            .assign(to: \.alertError, on: self)
            .store(in: &cancellables)
    }
}
