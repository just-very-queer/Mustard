//
//  AppError.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 30/12/24.
//

import Foundation

/// Represents a generic application error to be displayed in alerts.
struct AppError: Identifiable, Error {
    var id = UUID()
    let message: String
    let underlyingError: Error?

    /// Initializes a new `AppError` with a message and an optional underlying error.
    ///
    /// - Parameters:
    ///   - message: The error message to display.
    ///   - underlyingError: The underlying error that caused this error, if any.
    init(message: String, underlyingError: Error? = nil) {
        self.message = message
        self.underlyingError = underlyingError
    }

    /// Convenience initializer to create an `AppError` from a `LocalizedError`.
    ///
    /// - Parameter error: The `LocalizedError` to convert.
    init(from error: LocalizedError) {
        self.message = error.errorDescription ?? "An unexpected error occurred."
        self.underlyingError = error
    }
    
    /// Provides a localized description of the error.
    var localizedDescription: String {
        return message
    }
}

