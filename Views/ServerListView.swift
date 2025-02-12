//
//  ServerListView.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 27/01/25.
//

import SwiftUI
import SwiftData

/// A view that displays popular Mastodon servers, fetched instances, and user-added servers.
/// Allows user to select a server to authenticate against, or cancel.
struct ServerListView: View {
    // MARK: - SwiftData Query
    @Query(sort: \ServerModel.name) private var serverModels: [ServerModel]
    @Environment(\.modelContext) private var modelContext

    // MARK: - State
    @State private var showAddServerSheet = false
    @State private var errorMessage: String?
    @State private var fetchedInstances: [Instance] = []
    @State private var isLoading = false
    @State private var isFetchingInstances = false

    private let instanceService = InstanceService()

    // MARK: - Callbacks
    let onSelect: (ServerModel) -> Void
    let onCancel: () -> Void

    // MARK: - Hardcoded Popular Servers
    private let popularServers = [
        ServerModel(
            name: "Mastodon Social",
            url: URL(string: "https://mastodon.social")!,
            serverDescription: "The original server operated by the Mastodon gGmbH non-profit",
            logoURL: URL(string: "https://mastodon.social/logo.png"),
            isUserAdded: false
        ),
        ServerModel(
            name: "Fediverse Observer",
            url: URL(string: "https://fediverse.observer")!,
            serverDescription: "Tracking the entirety of the Fediverse.",
            logoURL: nil,
            isUserAdded: false
        ),
        ServerModel(
            name: "Mastodon Online",
            url: URL(string: "https://mastodon.online")!,
            serverDescription: "One of the flagship instances run by the Mastodon gGmbH non-profit.",
            logoURL: nil,
            isUserAdded: false
        )
    ]

    // MARK: - Body
    var body: some View {
        NavigationStack {
            List {
                // 1) Popular Servers
                Section(header: SectionHeaderView(title: "Popular Mastodon Servers")) {
                    ForEach(popularServers) { server in
                        Button(action: { onSelect(server) }) {
                            ServerRowView(server: server)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }

                // 2) Fetched Instances
                Section(header: SectionHeaderView(title: "Fetched Instances")) {
                    if isLoading {
                        ProgressView()
                    } else {
                        ForEach(fetchedInstances, id: \.id) { instance in
                            Button(action: {
                                addFetchedInstance(instance)
                            }) {
                                Text(instance.name)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }

                // 3) User-Added Servers
                Section(header: SectionHeaderView(title: "Your Added Servers")) {
                    ForEach(serverModels.filter { $0.isUserAdded }) { server in
                        Button(action: { onSelect(server) }) {
                            ServerRowView(server: server)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .onDelete(perform: deleteUserAddedServer)
                }
            }
            .navigationTitle("Select Mastodon Server")
            .listStyle(InsetGroupedListStyle())
            .toolbar {
                // Cancel Action
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                // Add Server Action
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddServerSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add Server")
                }
            }
            // Present a sheet for adding a server manually
            .sheet(isPresented: $showAddServerSheet) {
                AddServerView { newServer in
                    modelContext.insert(newServer)
                    do {
                        try modelContext.save()
                    } catch {
                        errorMessage = "Failed to save server: \(error.localizedDescription)"
                    }
                }
            }
            // Show errors as needed
            .alert("Error", isPresented: Binding<Bool>(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                }
            }
            // Automatically fetch instance list on appear
            .task {
                await fetchInstances()
            }
        }
    }

    // MARK: - Private Helpers

    /// Adds a newly fetched instance as a ServerModel in SwiftData and calls onSelect(server).
    private func addFetchedInstance(_ instance: Instance) {
        let server = ServerModel(
            name: instance.name,
            url: URL(string: "https://\(instance.name)")!,
            serverDescription: instance.instanceDescription ?? "No description available",
            isUserAdded: true
        )
        modelContext.insert(server)
        do {
            try modelContext.save()
            onSelect(server)
        } catch {
            errorMessage = "Failed to save server: \(error.localizedDescription)"
        }
    }

    /// Fetches Mastodon instances from the `instances.social` API via InstanceService.
    private func fetchInstances() async {
        guard !isFetchingInstances else { return }
        isFetchingInstances = true
        isLoading = true
        do {
            fetchedInstances = try await instanceService.fetchInstances()
        } catch {
            errorMessage = "Failed to fetch instances: \(error.localizedDescription)"
        }
        isLoading = false
        isFetchingInstances = false
    }

    /// Deletes user-added server(s) from SwiftData (triggered by swipe-to-delete).
    private func deleteUserAddedServer(at offsets: IndexSet) {
        let userAddedServers = serverModels.filter { $0.isUserAdded }
        for index in offsets {
            let server = userAddedServers[index]
            modelContext.delete(server)
        }
        do {
            try modelContext.save()
        } catch {
            errorMessage = "Failed to delete server: \(error.localizedDescription)"
        }
    }
}

// MARK: - SectionHeaderView

/// A simple view for styling section headers in a List.
struct SectionHeaderView: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.headline)
            .foregroundColor(.primary)
            .padding(.top, 10)
            .padding(.bottom, 5)
    }
}

// MARK: - ServerRowView

/// A row displaying a server's name, description, and optional logo image.
struct ServerRowView: View {
    let server: ServerModel

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
                        image.resizable()
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
                // If no logo is provided
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

// MARK: - AddServerView

/// A sheet allowing the user to manually add a Mastodon server by entering its base URL.
struct AddServerView: View {
    @Environment(\.dismiss) private var dismiss

    /// The closure to call when a new server is successfully created.
    let onAdd: (ServerModel) -> Void

    @State private var serverURL = ""
    @State private var isVerifying = false
    @State private var errorMessage: String?

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
                        Task { await addServer() }
                    }
                    .disabled(serverURL.isEmpty || isVerifying)
                }
            }
            // A loading overlay if verifying
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
                Button("OK", role: .cancel) { }
            } message: {
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                }
            }
        }
    }

    /// Attempts to fetch basic info from the server, then calls onAdd if successful.
    private func addServer() async {
        guard let url = URL(string: serverURL), url.scheme != nil else {
            errorMessage = "Invalid URL."
            return
        }

        isVerifying = true
        defer { isVerifying = false }

        do {
            let instanceInfo = try await fetchInstanceInfo(url: url)
            let newServer = ServerModel(
                name: instanceInfo.title,
                url: url,
                serverDescription: instanceInfo.description,
                logoURL: instanceInfo.thumbnail,
                isUserAdded: true
            )
            onAdd(newServer)
            dismiss()
        } catch {
            errorMessage = "Failed to verify server: \(error.localizedDescription)"
        }
    }

    /// Fetches minimal Mastodon server info from /api/v1/instance.
    private func fetchInstanceInfo(url: URL) async throws -> InstanceInfo {
        let apiURL = url.appendingPathComponent("/api/v1/instance")
        var request = URLRequest(url: apiURL)
        request.httpMethod = "GET"

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode(InstanceInfo.self, from: data)
    }
}
