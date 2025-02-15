//
//  Server.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 30/12/24.
//

import SwiftUI
import Foundation
import SwiftData

@Model
class ServerModel: Identifiable {
    @Attribute(.unique) var id: String
    var name: String
    var url: URL
    var serverDescription: String
    var logoURL: URL?
    var isUserAdded: Bool

    init(
        id: String = UUID().uuidString,
        name: String,
        url: URL,
        serverDescription: String,
        logoURL: URL? = nil,
        isUserAdded: Bool = false
    ) {
        self.id = id
        self.name = name
        self.url = url
        self.serverDescription = serverDescription
        self.logoURL = logoURL
        self.isUserAdded = isUserAdded
    }
}
