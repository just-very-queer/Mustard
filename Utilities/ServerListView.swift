//
//  ServerListView.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 14/09/24.
//

import SwiftUI

struct ServerListView: View {
    let servers: [Server]
    let onSelect: (Server) -> Void
    let onCancel: () -> Void  // Added onCancel closure

    var body: some View {
        NavigationStack {
            List(servers) { server in
                VStack(alignment: .leading) {
                    Text(server.name)
                        .font(.headline)
                    Text(server.description)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .contentShape(Rectangle()) // So the entire cell is tappable
                .onTapGesture {
                    onSelect(server)
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Select Server")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()  // Invoke the onCancel closure
                    }
                }
            }
        }
    }
}

struct SampleServers {
    static let servers: [Server] = [
        Server(name: "Mastodon Social",
               url: URL(string: "https://mastodon.social")!,
               description: "Official Mastodon instance."),
        Server(name: "Mastodon Cloud",
               url: URL(string: "https://mastodon.cloud")!,
               description: "Cloud-hosted Mastodon instance."),
        Server(name: "Mstdn Social",
               url: URL(string: "https://mstdn.social")!,
               description: "Another Mastodon instance.")
    ]
}

struct ServerListView_Previews: PreviewProvider {
    static var previews: some View {
        ServerListView(
            servers: SampleServers.servers,
            onSelect: { _ in },
            onCancel: { }
        )
    }
}

