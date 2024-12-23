//
//  Account.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 14/09/24.
//

import Foundation
import SwiftData

@Model
class Account: Identifiable {
    @Attribute(.unique) var id: String
    var username: String
    var displayName: String
    var avatar: URL
    var acct: String

    init(id: String, username: String, displayName: String, avatar: URL, acct: String) {
        self.id = id
        self.username = username
        self.displayName = displayName
        self.avatar = avatar
        self.acct = acct
    }
}
