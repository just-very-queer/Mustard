//
//  Interaction.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 30/12/24.
//


import Foundation
import SwiftData

enum InteractionType: String, Codable, Sendable {
    case like, unlike, repost, unrepost, comment, view, timeSpent, linkOpen
}

@Model
final class Interaction {
    @Attribute(.unique) var id: UUID
    var statusID: String? // Can be nil if interaction is not post-specific (e.g. app open)
    var actionType: InteractionType
    var timestamp: Date
    var accountID: String? // ID of the user performing the action, if relevant
    var authorAccountID: String? // ID of the post's author, if relevant
    var postURL: String? // URL of the post, if relevant
    
    // Changed from [String]? to Data?
    private var tagsData: Data?
    
    var tags: [String]? {
        get {
            guard let data = tagsData else { return nil }
            return try? JSONDecoder().decode([String].self, from: data)
        }
        set {
            if let newValue = newValue {
                tagsData = try? JSONEncoder().encode(newValue)
            } else {
                tagsData = nil
            }
        }
    }
    
    var viewDuration: Double? // For timeSpent action, in seconds
    var linkURL: String? // For linkOpen action

    init(id: UUID = UUID(),
         statusID: String? = nil,
         actionType: InteractionType,
         timestamp: Date = Date(),
         accountID: String? = nil,
         authorAccountID: String? = nil,
         postURL: String? = nil,
         tags: [String]? = nil, // Initializer can still accept [String]?
         viewDuration: Double? = nil,
         linkURL: String? = nil) {
        self.id = id
        self.statusID = statusID
        self.actionType = actionType
        self.timestamp = timestamp
        self.accountID = accountID
        self.authorAccountID = authorAccountID
        self.postURL = postURL
        // Use the setter for tags to ensure proper encoding
        self.tags = tags
        self.viewDuration = viewDuration
        self.linkURL = linkURL
    }
}
