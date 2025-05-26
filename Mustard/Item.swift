//
//  Item.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 14/09/24.
//

import Foundation
import SwiftData
import CoreLocation
import Combine
import SwiftData

// MARK: - Notification.Name Extensions

extension Notification.Name {
    static let didAuthenticate = Notification.Name("didAuthenticate")
    static let authenticationFailed = Notification.Name("authenticationFailed")
    static let didReceiveOAuthCallback = Notification.Name("didReceiveOAuthCallback")
    static let didUpdateLocation = Notification.Name("didUpdateLocation")
    static let didDecodePostLocation = Notification.Name("didDecodePostLocatior")
    static let didRequestWeatherFetch = Notification.Name("didRequestWeatherFetch")
}
