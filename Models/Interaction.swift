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
    var tags: [String]? // Hashtags associated with the post
    var viewDuration: Double? // For timeSpent action, in seconds
    var linkURL: String? // For linkOpen action

    init(id: UUID = UUID(), 
         statusID: String? = nil, 
         actionType: InteractionType, 
         timestamp: Date = Date(), 
         accountID: String? = nil,
         authorAccountID: String? = nil,
         postURL: String? = nil,
         tags: [String]? = nil,
         viewDuration: Double? = nil,
         linkURL: String? = nil) {
        self.id = id
        self.statusID = statusID
        self.actionType = actionType
        self.timestamp = timestamp
        self.accountID = accountID
        self.authorAccountID = authorAccountID
        self.postURL = postURL
        self.tags = tags
        self.viewDuration = viewDuration
        self.linkURL = linkURL
    }
}
