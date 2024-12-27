//
//  Notifications.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 14/09/24.
//

import Foundation

/// Extension to define custom notification names used within the app.
extension Notification.Name {
    /// Notification posted when an OAuth callback is received.
    static let didReceiveOAuthCallback = Notification.Name("didReceiveOAuthCallback")
    
    /// Notification posted when authentication succeeds.
    static let didAuthenticate = Notification.Name("didAuthenticate")
    
    /// New Notification If account is slected or not.
    static let didSelectAccount = Notification.Name("didSelectAccount") // New Notification
}


