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

    var body: some View {
        NavigationView {
            List(servers) { server in
                VStack(alignment: .leading) {
                    Text(server.name)
                        .font(.headline)
                    Text(server.description)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .onTapGesture {
                    onSelect(server)
                }
            }
            .navigationTitle("Select Server")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        // Dismiss the sheet if needed
                        // Typically handled automatically, but can add custom behavior here
                    }
                }
            }
        }
    }
}
