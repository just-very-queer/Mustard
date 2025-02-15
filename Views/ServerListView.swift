//
//  ServerListView.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 27/01/25.
//

import SwiftUI
import SwiftData
import OSLog

// MARK: - ServerListView

struct ServerListView: View {
    @Query(sort: \ServerModel.name) private var serverModels: [ServerModel]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var showAddServerSheet = false
    @State private var errorMessage: String?
    @State private var fetchedInstances: [Instance] = []  // using Instance type
    @State private var isLoading = false
    @State private var isFetchingInstances = false
    @State private var selectedInstance: Instance?
    @State private var showInstanceDetailSheet = false

    private let instanceService = InstanceService()

    let onSelect: (ServerModel) -> Void
    let onCancel: () -> Void

    private let popularServers = [
        ServerModel(
            name: "Mastodon Social",
            url: URL(string: "https://mastodon.social")!,
            serverDescription: "The original server operated by Mastodon gGmbH",
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
            serverDescription: "Mastodon gGmbH flagship instance.",
            logoURL: nil,
            isUserAdded: false
        )
    ]

    var body: some View {
        NavigationStack {
            List {
                // Popular Servers Section
                Section(header: SectionHeaderView(title: "Popular Servers")) {
                    ForEach(popularServers) { server in
                        ServerRow(server: server) {
                            Task {
                                await fetchAndShowInstanceDetails(for: server.url)
                            }
                        }
                    }
                }
                
                // Fetched Instances Section
                Section(header: SectionHeaderView(title: "Fetched Instances")) {
                    if isLoading {
                        ProgressView()
                    } else {
                        ForEach(fetchedInstances) { instance in
                            // Create a temporary ServerModel from the Instance
                            ServerRow(server: ServerModel(
                                name: instance.name,
                                url: URL(string: "https://\(instance.name)")!,
                                serverDescription: instance.instanceDescription ?? instance.info?.shortDescription ?? "No description",
                                isUserAdded: false
                            )) {
                                selectedInstance = instance
                                showInstanceDetailSheet = true
                            }
                        }
                    }
                }
                
                // Your Added Servers Section
                Section(header: SectionHeaderView(title: "Your Added Servers")) {
                    ForEach(serverModels.filter { $0.isUserAdded }) { server in
                        ServerRow(server: server) {
                            onSelect(server)
                        }
                    }
                    .onDelete(perform: deleteUserAddedServer)
                }
            }
            .navigationTitle("Select Server")
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
            // Sheet for Adding a New Server
            .sheet(isPresented: $showAddServerSheet) {
                AddServerView(instanceService: instanceService) { newServer in
                    Task { @MainActor in
                        modelContext.insert(newServer)
                        try modelContext.save()
                        onSelect(newServer)
                        dismiss()
                    }
                }
            }
            // Sheet for Instance Detail
            .sheet(isPresented: $showInstanceDetailSheet) {
                if let instance = selectedInstance {
                    InstanceDetailView(instance: instance) { selectedServer in
                        Task { @MainActor in
                            modelContext.insert(selectedServer)
                            try modelContext.save()
                            onSelect(selectedServer)
                            dismiss()
                        }
                    }
                    .presentationDetents([.medium, .large])
                }
            }
            // Alert for Errors
            .alert(
                "Error",
                isPresented: Binding<Bool>(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                ),
                actions: {
                    Button("OK", role: .cancel) { }
                },
                message: {
                    Text(errorMessage ?? "Unknown error")
                }
            )
            .task {
                await fetchInstances()
            }
        }
    }

    private func fetchAndShowInstanceDetails(for url: URL) async {
        do {
            selectedInstance = try await instanceService.fetchInstanceInfo(url: url)
            showInstanceDetailSheet = true
        } catch {
            errorMessage = "Failed to fetch details: \(error.localizedDescription)"
        }
    }
    
    // Ensure all modelContext work is done on the main actor.
    @MainActor
    private func fetchInstances() async {
        guard !isFetchingInstances else { return }
        isFetchingInstances = true
        isLoading = true
        
        do {
            // Fetch instances from the service (which returns [Instance])
            let instances = try await instanceService.fetchInstances(count: 5)
            fetchedInstances = instances
        } catch {
            errorMessage = "Failed to fetch: \(error.localizedDescription)"
        }
        isLoading = false
        isFetchingInstances = false
    }
    
    @MainActor
    private func deleteUserAddedServer(at offsets: IndexSet) {
        let userAddedServers = serverModels.filter { $0.isUserAdded }
        for index in offsets {
            let server = userAddedServers[index]
            modelContext.delete(server)
        }
        do {
            try modelContext.save()
        } catch {
            errorMessage = "Delete failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - InstanceDetailView

struct InstanceDetailView: View {
    let instance: Instance
    let onLogin: (ServerModel) -> Void
    @Environment(\.dismiss) var dismiss
    @Environment(\.openURL) var openURL

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerSection
                descriptionSection
                statsSection
                contactSection
                Spacer()
                loginButton
            }
            .padding()
        }
    }
    
    private var headerSection: some View {
        HStack {
            if let thumbnailURLString = instance.thumbnail,
               let thumbnailURL = URL(string: thumbnailURLString) {
                AsyncImage(url: thumbnailURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 80, height: 80)
                            .cornerRadius(10)
                    case .failure:
                        DefaultServerIcon()
                    case .empty:
                        ProgressView()
                            .frame(width: 80, height: 80)
                    @unknown default:
                        DefaultServerIcon()
                    }
                }
            } else {
                DefaultServerIcon()
            }
            Text(instance.name)
                .font(.largeTitle)
                .fontWeight(.bold)
            Spacer()
        }
    }
    
    private var descriptionSection: some View {
        Group {
            if let shortDesc = instance.info?.shortDescription, !shortDesc.isEmpty {
                Text("About")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text(shortDesc)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            if let fullDesc = instance.instanceDescription, !fullDesc.isEmpty {
                Text("Full Description")
                    .font(.title3)
                    .fontWeight(.semibold)
                Text(.init(fullDesc))
                    .font(.body)
            }
        }
    }
    
    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Statistics")
                .font(.title2)
                .fontWeight(.semibold)
            if let active = instance.activeUsers {
                InfoRow(title: "Active Users", value: String(active))
            }
            if let users = instance.users {
                InfoRow(title: "Total Users", value: users)
            }
            if let version = instance.version {
                InfoRow(title: "Version", value: version)
            }
        }
    }
    
    private var contactSection: some View {
        Group {
            if let email = instance.email {
                HStack {
                    Image(systemName: "envelope.fill")
                    Text("Contact Email:")
                    Button(email) {
                        if let url = URL(string: "mailto:\(email)") {
                            openURL(url)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            if let admin = instance.admin {
                HStack {
                    Image(systemName: "person.fill")
                    Text("Admin:")
                    Text(admin)
                }
            }
        }
    }
    
    private var loginButton: some View {
        Button(action: {
            let server = ServerModel(
                name: instance.name,
                url: URL(string: "https://\(instance.name)")!,
                serverDescription: instance.instanceDescription ?? instance.info?.shortDescription ?? "No description",
                isUserAdded: true
            )
            onLogin(server)
            // Delay dismissal slightly to allow the authentication view controller to be presented properly.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                dismiss()
            }
        }) {
            Text("Log in to \(instance.name)")
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.blue)
                .cornerRadius(10)
        }
    }
}

// MARK: - SectionHeaderView

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

// MARK: - ServerRow

struct ServerRow: View {
    let server: ServerModel
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                ServerLogoView(logoURL: server.logoURL)
                VStack(alignment: .leading) {
                    Text(server.name)
                        .font(.headline)
                    Text(server.serverDescription)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(2)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - ServerLogoView

struct ServerLogoView: View {
    let logoURL: URL?

    var body: some View {
        Group {
            if let url = logoURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(width: 50, height: 50)
                    case .success(let image):
                        image.resizable()
                            .scaledToFill()
                            .frame(width: 50, height: 50)
                            .clipShape(Circle())
                    case .failure:
                        DefaultServerIcon()
                    @unknown default:
                        DefaultServerIcon()
                    }
                }
            } else {
                DefaultServerIcon()
            }
        }
    }
}

// MARK: - DefaultServerIcon

struct DefaultServerIcon: View {
    var body: some View {
        Image(systemName: "server.rack")
            .resizable()
            .scaledToFit()
            .frame(width: 40, height: 40)
            .foregroundColor(.gray)
    }
}

// MARK: - InfoRow

struct InfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text("\(title):")
                .font(.subheadline)
                .foregroundColor(.gray)
            Text(value)
                .font(.subheadline)
            Spacer()
        }
    }
}

// MARK: - AddServerView

struct AddServerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let instanceService: InstanceService
    let onAdd: (ServerModel) -> Void

    @State private var serverURL = ""
    @State private var isVerifying = false
    @State private var errorMessage: String?
    @State private var fetchedInstance: Instance?

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Add Mastodon Server")) {
                    TextField("Server URL (e.g., https://mastodon.social)", text: $serverURL)
                        .keyboardType(.URL)
                        .textContentType(.URL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .onChange(of: serverURL) { newValue, _ in
                            fetchedInstance = nil
                        }
                    if let instance = fetchedInstance {
                        InstanceDetailView(instance: instance) { server in
                            onAdd(server)
                            dismiss()
                        }
                    }
                    
                    Button("Verify Server") {
                        Task {
                            await verifyServer()
                        }
                    }
                    .disabled(isVerifying || serverURL.isEmpty)
                }
            }
            .navigationTitle("Add Server")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        Task {
                            await addServer()
                        }
                    }
                    .disabled(fetchedInstance == nil)
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
            .alert(
                "Error",
                isPresented: Binding<Bool>(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                ),
                actions: {
                    Button("OK", role: .cancel) { }
                },
                message: {
                    Text(errorMessage ?? "Unknown Error")
                }
            )
        }
    }
    
    private func verifyServer() async {
        guard let url = URL(string: serverURL), url.scheme != nil else {
            errorMessage = "Invalid URL. Must start with 'http' or 'https'."
            return
        }
        isVerifying = true
        defer { isVerifying = false }
        do {
            fetchedInstance = try await instanceService.fetchInstanceInfo(url: url)
        } catch {
            errorMessage = "Verification failed: \(error.localizedDescription)"
        }
    }
    
    @MainActor
    private func addServer() async {
        guard let instance = fetchedInstance else {
            errorMessage = "Verify server first"
            return
        }
        
        let newServer = ServerModel(
            name: instance.name,
            url: URL(string: "https://\(instance.name)")!,
            serverDescription: instance.instanceDescription ?? instance.info?.shortDescription ?? "No description",
            isUserAdded: true
        )
        
        modelContext.insert(newServer)
        do {
            try modelContext.save()
            onAdd(newServer)
            dismiss()
        } catch {
            errorMessage = "Failed to save server: \(error.localizedDescription)"
        }
    }
}

// MARK: - Instance Conversion Extension

// This extension converts an InstanceModel into an Instance.
// Adjust the conversion as needed.
extension Instance {
    init(instanceModel: InstanceModel) {
        self.id = instanceModel.id
        self.name = instanceModel.name
        // Set other properties as needed.
        self.addedAt = nil
        self.updatedAt = nil
        self.checkedAt = nil
        self.uptime = nil
        self.up = nil
        self.dead = nil
        self.version = nil
        self.ipv6 = nil
        self.httpsScore = nil
        self.httpsRank = ""
        self.obsScore = nil
        self.obsRank = nil
        self.users = ""
        self.statuses = ""
        self.connections = ""
        self.openRegistrations = nil
        self.info = nil
        self.thumbnail = nil
        self.thumbnailProxy = nil
        self.activeUsers = nil
        self.email = nil
        self.admin = nil
        self.instanceDescription = ""
    }
}


