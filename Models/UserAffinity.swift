import Foundation
import SwiftData

@Model
final class UserAffinity {
    @Attribute(.unique) var authorAccountID: String // The ID of the author this affinity score is for
    var score: Double // Calculated affinity score
    var lastUpdated: Date // When the score was last calculated
    var interactionCount: Int // Number of interactions with this author

    init(authorAccountID: String, score: Double = 0.0, lastUpdated: Date = Date(), interactionCount: Int = 0) {
        self.authorAccountID = authorAccountID
        self.score = score
        self.lastUpdated = lastUpdated
        self.interactionCount = interactionCount
    }
}
