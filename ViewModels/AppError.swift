//
//  AppError.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 14/09/24.
//

import Foundation

/// Represents a generic application error to be displayed in alerts.
struct MustardAppError: Identifiable, Error {
    var id = UUID()
    let message: String
}
