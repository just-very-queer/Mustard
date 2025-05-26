import Foundation
import SwiftData

@Model
final class HashtagAffinity {
    @Attribute(.unique) var tag: String // The hashtag string (without '#')
    var score: Double // Calculated affinity score
    var lastUpdated: Date // When the score was last calculated
    var interactionCount: Int // Number of interactions with posts containing this hashtag

    init(tag: String, score: Double = 0.0, lastUpdated: Date = Date(), interactionCount: Int = 0) {
        self.tag = tag
        self.score = score
        self.lastUpdated = lastUpdated
        self.interactionCount = interactionCount
    }
}
