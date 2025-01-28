//
//  ProfileView.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 24/01/25.
//

import SwiftUI

struct ProfileView: View {
    let user: User
    @EnvironmentObject var profileViewModel: ProfileViewModel
    @EnvironmentObject var authViewModel: AuthenticationViewModel
    @State private var showFollowers = false
    @State private var showFollowing = false
    @State private var showEditProfile = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                ProfileHeaderView(user: user)

                if let bio = user.note {
                    Text(HTMLUtils.convertHTMLToPlainText(html: bio))
                        .font(.body)
                        .padding(.horizontal)
                }

                ProfileStatsView(user: user)

                ProfileActionsView(
                    showFollowers: $showFollowers,
                    showFollowing: $showFollowing,
                    showEditProfile: $showEditProfile
                )
            }
            .padding()
        }
        .navigationTitle("Profile")
        .sheet(isPresented: $showFollowers) {
            if let currentUserId = authViewModel.currentUser?.id {
                FollowersListView(profileViewModel: profileViewModel, userId: currentUserId)
            }
        }
        .sheet(isPresented: $showFollowing) {
            if let currentUserId = authViewModel.currentUser?.id {
                FollowingListView(profileViewModel: profileViewModel, userId: currentUserId)
            }
        }
        .sheet(isPresented: $showEditProfile) {
            EditProfileView(user: user)
                .environmentObject(profileViewModel)
        }
    }
}

// MARK: - Profile Header View
struct ProfileHeaderView: View {
    let user: User

    var body: some View {
        HStack {
            AsyncImage(url: URL(string: user.avatar!)) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                case .success(let image):
                    image.resizable()
                         .scaledToFill()
                         .frame(width: 100, height: 100)
                         .clipShape(Circle())
                case .failure:
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 100, height: 100)
                        .foregroundColor(.gray)
                @unknown default:
                    EmptyView()
                }
            }
            .frame(width: 100, height: 100)
            
            VStack(alignment: .leading) {
                Text(user.display_name ?? user.username)
                    .font(.largeTitle)
                    .bold()
                Text("@\(user.username)")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            Spacer()
        }
        .padding()
    }
}

// MARK: - Profile Stats View
struct ProfileStatsView: View {
    let user: User

    var body: some View {
        HStack {
            VStack {
                Text("Posts")
                Text("\(user.statuses_count)")
                    .font(.title)
            }
            Spacer()
            VStack {
                Text("Followers")
                Text("\(user.followers_count)")
                    .font(.title)
            }
            Spacer()
            VStack {
                Text("Following")
                Text("\(user.following_count)")
                    .font(.title)
            }
        }
        .padding()
    }
}

// MARK: - Profile Actions View
struct ProfileActionsView: View {
    @Binding var showFollowers: Bool
    @Binding var showFollowing: Bool
    @Binding var showEditProfile: Bool

    var body: some View {
        VStack(spacing: 10) {
            Button(action: { showFollowers.toggle() }) {
                Text("View Followers")
                    .foregroundColor(.blue)
            }

            Button(action: { showFollowing.toggle() }) {
                Text("View Following")
                    .foregroundColor(.blue)
            }

            Button(action: { showEditProfile.toggle() }) {
                Text("Edit Profile")
                    .foregroundColor(.blue)
            }
        }
        .padding(.top)
    }
}

// MARK: - Followers List View
struct FollowersListView: View {
    @ObservedObject var profileViewModel: ProfileViewModel
    let userId: String

    var body: some View {
        NavigationView {
            List(profileViewModel.followers) { follower in
                NavigationLink(destination: ProfileView(user: follower)) {
                    HStack {
                        AsyncImage(url: URL(string: follower.avatar!)) { phase in
                            switch phase {
                            case .empty:
                                ProgressView()
                            case .success(let image):
                                image.resizable()
                                     .scaledToFill()
                                     .frame(width: 50, height: 50)
                                     .clipShape(Circle())
                            case .failure:
                                Image(systemName: "person.crop.circle.fill")
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 50, height: 50)
                                    .foregroundColor(.gray)
                            @unknown default:
                                EmptyView()
                            }
                        }
                        VStack(alignment: .leading) {
                            Text(follower.display_name ?? follower.username)
                                .font(.headline)
                            Text("@\(follower.username)")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            .navigationTitle("Followers")
            .task {
                await profileViewModel.fetchFollowers(for: userId)
            }
        }
    }
}

// MARK: - Following List View
struct FollowingListView: View {
    @ObservedObject var profileViewModel: ProfileViewModel
    let userId: String

    var body: some View {
        NavigationView {
            List(profileViewModel.following) { user in
                NavigationLink(destination: ProfileView(user: user)) {
                    HStack {
                        AsyncImage(url: URL(string: user.avatar!)) { phase in
                            switch phase {
                            case .empty:
                                ProgressView()
                            case .success(let image):
                                image.resizable()
                                     .scaledToFill()
                                     .frame(width: 50, height: 50)
                                     .clipShape(Circle())
                            case .failure:
                                Image(systemName: "person.crop.circle.fill")
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 50, height: 50)
                                    .foregroundColor(.gray)
                            @unknown default:
                                EmptyView()
                            }
                        }
                        VStack(alignment: .leading) {
                            Text(user.display_name ?? user.username)
                                .font(.headline)
                            Text("@\(user.username)")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            .navigationTitle("Following")
            .task {
                await profileViewModel.fetchFollowing(for: userId)
            }
        }
    }
}

// MARK: - Edit Profile View
struct EditProfileView: View {
    @EnvironmentObject var profileViewModel: ProfileViewModel
    @Environment(\.dismiss) var dismiss
    @State private var username: String
    @State private var displayName: String
    @State private var bio: String

    let user: User

    init(user: User) {
        self.user = user
        _username = State(initialValue: user.username)
        _displayName = State(initialValue: user.display_name ?? "")
        _bio = State(initialValue: user.note ?? "")
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                TextField("Username", text: $username)
                    .padding()
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                TextField("Display Name", text: $displayName)
                    .padding()
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                TextEditor(text: $bio)
                    .padding()
                    .frame(height: 100)
                    .border(Color.gray, width: 1)

                Button("Save Changes") {
                    Task {
                        // Ignore the result of the `updateProfile` call
                        _ = await profileViewModel.updateProfile(for: user.id, updatedFields: [
                            "username": username,
                            "display_name": displayName,
                            "note": bio
                        ])
                        dismiss()
                    }
                }
                .padding()
                .foregroundColor(.blue)
            }
            .padding()
            .navigationTitle("Edit Profile")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert(isPresented: $profileViewModel.showAlert) {
                Alert(title: Text("Error"), message: Text(profileViewModel.alertMessage ?? "Unknown error"), dismissButton: .default(Text("OK")))
            }
        }
    }
}
