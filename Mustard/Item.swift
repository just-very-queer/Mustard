//
//  Item.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 14/09/24.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}

// MARK: - Notification.Name Extensions

extension Notification.Name {
    static let didAuthenticate = Notification.Name("didAuthenticate")
    static let authenticationFailed = Notification.Name("authenticationFailed")
    static let didReceiveOAuthCallback = Notification.Name("didReceiveOAuthCallback")
    static let didUpdateLocation = Notification.Name("didUpdateLocation")
    static let didDecodePostLocation = Notification.Name("didDecodePostLocatior")
    static let didRequestWeatherFetch = Notification.Name("didRequestWeatherFetch")
}
