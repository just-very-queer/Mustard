import Foundation

struct Card: Codable, Hashable, Equatable {
    let url: String
    let title: String
    let description: String
    let type: String
    let image: String?
    let authorName: String?
    let authorUrl: String?
    let providerName: String?
    let providerUrl: String?
    let html: String?
    let width: Int?
    let height: Int?
    let embedUrl: String?
    let blurhash: String?

    enum CodingKeys: String, CodingKey {
        case url
        case title
        case description
        case type
        case image
        case authorName = "author_name"
        case authorUrl = "author_url"
        case providerName = "provider_name"
        case providerUrl = "provider_url"
        case html
        case width
        case height
        case embedUrl = "embed_url"
        case blurhash
    }
}
