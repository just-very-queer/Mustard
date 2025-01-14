//
//  Server.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 30/12/24.
//

import Foundation

/// Represents a Mastodon server instance.
struct Server: Identifiable, Equatable {
    let id: UUID  // ✅ Allow explicit assignment in initializer
    let name: String
    let url: URL
    let description: String
    let logoURL: URL?  // Optional logo URL
    
    init(name: String, url: URL, description: String, logoURL: URL? = nil) {
        self.id = UUID()  // ✅ Now correctly initialized inside the initializer
        self.name = name
        self.url = url
        self.description = description
        self.logoURL = logoURL
    }
}

/// Sample servers for UI previews & testing
struct SampleServers {
    static let servers: [Server] = [
        Server(
            name: "Mastodon Social",
            url: URL(string: "https://mastodon.social")!,
            description: "Official Mastodon instance.",
            logoURL: URL(string: "https://mastodon.social/logo.png")
        ),
        Server(
            name: "Mastodon Cloud",
            url: URL(string: "https://mastodon.cloud")!,
            description: "Cloud-hosted Mastodon instance.",
            logoURL: URL(string: "https://mastodon.cloud/logo.png")
        ),
        Server(
            name: "Mstdn Social",
            url: URL(string: "https://mstdn.social")!,
            description: "Another Mastodon instance."
        )
    ]
}
