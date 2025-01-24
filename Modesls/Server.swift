//
//  Server.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 30/12/24.
//

import SwiftUI
import Foundation
import SwiftData

/// Represents a Mastodon server instance.
@Model
class Server: Identifiable {
    @Attribute(.unique) var id: String // Use String for ID, and mark as unique
    var name: String
    var url: URL
    var serverDescription: String // Renamed to avoid conflict with `description`
    var logoURL: URL? // Optional logo URL
    var isUserAdded: Bool // Indicates if the server is user-added or predefined

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

struct ServerListView: View {
    @Query(sort: \Server.name) private var servers: [Server]  // Fetch servers from SwiftData
    @Environment(\.modelContext) private var modelContext  // For saving to SwiftData
    @State private var showAddServerSheet = false  // Controls the visibility of the add server sheet
    @State private var errorMessage: String? // For error handling

    let onSelect: (Server) -> Void  // Closure to handle server selection
    let onCancel: () -> Void        // Closure to handle cancellation

    // MARK: - Popular Mastodon Servers
    private let popularServers = [
        Server(
            name: "Mastodon Social",
            url: URL(string: "https://mastodon.social")!,
            serverDescription: "The original server operated by the Mastodon gGmbH non-profit",
            logoURL: URL(string: "https://mastodon.social/logo.png"),
            isUserAdded: false
        ),
        Server(
            name: "Fediverse Observer",
            url: URL(string: "https://fediverse.observer")!,
            serverDescription: "Tracking the entirety of the Fediverse.",
            logoURL: nil,
            isUserAdded: false
        ),
        Server(
            name: "Mastodon Online",
            url: URL(string: "https://mastodon.online")!,
            serverDescription: "One of the flagship instances run by the Mastodon gGmbH non-profit.",
            logoURL: nil,
            isUserAdded: false
        )
    ]

    var body: some View {
        NavigationStack {
            List {
                // Display popular servers
                Section(header: SectionHeader(title: "Popular Mastodon Servers")) {
                    ForEach(popularServers) { server in
                        Button(action: { onSelect(server) }) {
                            ServerRow(server: server)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }

                // Display user-added servers
                Section(header: SectionHeader(title: "Your Added Servers")) {
                    ForEach(servers.filter { $0.isUserAdded }) { server in
                        Button(action: { onSelect(server) }) {
                            ServerRow(server: server)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .onDelete(perform: deleteUserAddedServer)
                }
            }
            .navigationTitle("Select Mastodon Server")
            .listStyle(InsetGroupedListStyle())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showAddServerSheet = true }) {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add Server")
                }
            }
            .sheet(isPresented: $showAddServerSheet) {
                AddServerSheet { newServer in
                    modelContext.insert(newServer)
                    do {
                        try modelContext.save()
                    } catch {
                        errorMessage = "Failed to save server: \(error.localizedDescription)"
                    }
                }
            }
            .alert("Error", isPresented: Binding<Bool>(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                }
            }
        }
    }

    private func deleteUserAddedServer(at offsets: IndexSet) {
        for index in offsets {
            let server = servers.filter { $0.isUserAdded }[index]
            modelContext.delete(server)
        }
        do {
            try modelContext.save()
        } catch {
            errorMessage = "Failed to delete server: \(error.localizedDescription)"
        }
    }
}

/// Section Header View
struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.headline)
            .foregroundColor(.primary)
            .padding(.top, 10)
            .padding(.bottom, 5)
    }
}

/// Server Row
struct ServerRow: View {
    let server: Server

    var body: some View {
        HStack(spacing: 16) {
            if let logoURL = server.logoURL {
                AsyncImage(url: logoURL) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(width: 50, height: 50)
                            .background(Color.gray.opacity(0.2))
                            .clipShape(Circle())
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 50, height: 50)
                            .clipShape(Circle())
                    case .failure:
                        Image(systemName: "photo")
                            .resizable()
                            .scaledToFill()
                            .frame(width: 50, height: 50)
                            .clipShape(Circle())
                            .foregroundColor(.gray)
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                Image(systemName: "photo")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
                    .foregroundColor(.gray)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(server.name)
                    .font(.headline)
                Text(server.serverDescription)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .lineLimit(2)
            }
            Spacer()
        }
        .padding(.vertical, 8)
    }
}

/// Add Server Sheet
struct AddServerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var serverURL = ""
    @State private var isVerifying = false
    @State private var errorMessage: String?

    let onAdd: (Server) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Add Mastodon Server")) {
                    TextField("Server URL (e.g., https://mastodon.social)", text: $serverURL)
                        .keyboardType(.URL)
                        .textContentType(.URL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
            }
            .navigationTitle("Add Server")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        Task {
                            await addServer()
                        }
                    }
                    .disabled(serverURL.isEmpty || isVerifying)
                }
            }
            .overlay {
                if isVerifying {
                    ProgressView("Verifying...")
                        .progressViewStyle(CircularProgressViewStyle())
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.4))
                        .ignoresSafeArea()
                }
            }
            .alert("Error", isPresented: Binding<Bool>(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                }
            }
        }
    }

    private func addServer() async {
        guard let url = URL(string: serverURL), url.scheme != nil else {
            errorMessage = "Invalid URL."
            return
        }

        isVerifying = true
        defer { isVerifying = false }

        do {
            let instanceInfo = try await fetchInstanceInfo(url: url)
            let newServer = Server(
                name: instanceInfo.name,
                url: url,
                serverDescription: instanceInfo.description,
                logoURL: instanceInfo.logoURL,
                isUserAdded: true
            )
            onAdd(newServer)
            dismiss()
        } catch {
            errorMessage = "Failed to verify server: \(error.localizedDescription)"
        }
    }

    private func fetchInstanceInfo(url: URL) async throws -> InstanceInfo {
        let apiURL = url.appendingPathComponent("/api/v1/instance")
        var request = URLRequest(url: apiURL)
        request.httpMethod = "GET"

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let instanceInfo = try JSONDecoder().decode(InstanceInfo.self, from: data)
        return instanceInfo
    }
}

/// Instance Info for Mastodon Verification
struct InstanceInfo: Decodable {
    let name: String
    let description: String
    let logoURL: URL?

    enum CodingKeys: String, CodingKey {
        case name = "title"
        case description
        case logoURL = "thumbnail"
    }
}
