//
//  Server.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 30/12/24.
//

import Foundation
import SwiftUI

/// Represents a Mastodon server instance.
struct Server: Identifiable, Equatable {
    let id: UUID  // Allow explicit assignment in initializer
    let name: String
    let url: URL
    let description: String
    let logoURL: URL?  // Optional logo URL

    init(name: String, url: URL, description: String, logoURL: URL? = nil) {
        self.id = UUID()  // Correctly initialized inside the initializer
        self.name = name
        self.url = url
        self.description = description
        self.logoURL = logoURL
    }
}

struct ServerListView: View {
    let servers: [Server]
    let onSelect: (Server) -> Void
    let onCancel: () -> Void

    @EnvironmentObject var authViewModel: AuthenticationViewModel

    var body: some View {
        NavigationView {
            List(servers) { server in
                Button(action: { onSelect(server) }) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(server.name)
                                .font(.headline)
                            Text(server.description)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        if let logoURL = server.logoURL {
                            AsyncImage(url: logoURL) { phase in
                                switch phase {
                                case .empty:
                                    ProgressView()
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 40, height: 40)
                                        .clipShape(Circle())
                                case .failure:
                                    Image(systemName: "photo")
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 40, height: 40)
                                        .clipShape(Circle())
                                @unknown default:
                                    EmptyView()
                                }
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Select Mastodon Instance")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
            }
        }
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

// MARK: - Preview
struct ServerListView_Previews: PreviewProvider {
    static var previews: some View {
        let mockService = MockMastodonService(shouldSucceed: true)
        let authViewModel = AuthenticationViewModel(mastodonService: mockService)

        return ServerListView(
            servers: SampleServers.servers,
            onSelect: { _ in },
            onCancel: {}
        )
        .environmentObject(authViewModel)
    }
}
