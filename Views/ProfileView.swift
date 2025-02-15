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
    
    // State to show sheets
    @State private var showFollowers = false
    @State private var showFollowing = false
    @State private var showEditProfile = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                ProfileHeaderView(user: user)
                
                if let bio = user.note, !bio.isEmpty {
                    Text(HTMLUtils.convertHTMLToPlainText(html: bio))
                        .font(.body)
                        .padding(.horizontal)
                }
                
                // Tappable stats view: tapping the Followers or Following count opens the corresponding sheet
                ProfileStatsView(user: user,
                                 onFollowersTapped: { showFollowers.toggle() },
                                 onFollowingTapped: { showFollowing.toggle() })
                
                // Actions view: Only the Edit Profile button is needed here (visible only if current user)
                ProfileActionsView(user: user,
                                   showEditProfile: $showEditProfile)
                
                // Segmented control for additional profile content (Posts, Replies, Media, About)
                ProfileContentView(user: user)
            }
            .padding()
        }
        .navigationTitle("Profile")
        // Inject environment objects explicitly into the sheet views
        .sheet(isPresented: $showFollowers) {
            if let _ = authViewModel.currentUser?.id {
                FollowersListView(userId: user.id)  // Remove profileViewModel parameter
                    .environmentObject(profileViewModel)  // Inject via environment
                    .environmentObject(authViewModel)
            }
        }
        .sheet(isPresented: $showFollowing) {
            if let _ = authViewModel.currentUser?.id {
                FollowingListView(userId: user.id)  // Remove profileViewModel parameter
                    .environmentObject(profileViewModel)  // Inject via environment
                    .environmentObject(authViewModel)
            }
        }
        .sheet(isPresented: $showEditProfile) {
            EditProfileView(user: user)
                .environmentObject(profileViewModel)
                .environmentObject(authViewModel)
        }
    }
}

// MARK: - ProfileHeaderView

struct ProfileHeaderView: View {
    let user: User

    var body: some View {
        HStack {
            AsyncImage(url: URL(string: user.avatar ?? "")) { phase in
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

// MARK: - ProfileStatsView with Tappable Counts

struct ProfileStatsView: View {
    let user: User
    var onFollowersTapped: () -> Void
    var onFollowingTapped: () -> Void

    var body: some View {
        HStack {
            VStack {
                Text("Posts")
                Text("\(user.statuses_count ?? 0)")
                    .font(.title)
            }
            Spacer()
            VStack {
                Text("Followers")
                Text("\(user.followers_count ?? 0)")
                    .font(.title)
                    .onTapGesture {
                        onFollowersTapped()
                    }
            }
            Spacer()
            VStack {
                Text("Following")
                Text("\(user.following_count ?? 0)")
                    .font(.title)
                    .onTapGesture {
                        onFollowingTapped()
                    }
            }
        }
        .padding()
    }
}

// MARK: - ProfileActionsView (Edit Profile Only)

struct ProfileActionsView: View {
    let user: User
    @Binding var showEditProfile: Bool
    @EnvironmentObject var authViewModel: AuthenticationViewModel

    var body: some View {
        // Only show the Edit Profile button if viewing your own profile.
        if authViewModel.currentUser?.id == user.id {
            Button(action: { showEditProfile.toggle() }) {
                Text("Edit Profile")
                    .foregroundColor(.blue)
            }
            .padding(.top)
        }
    }
}

// MARK: - ProfileContentView (Segmented Tabs)

struct ProfileContentView: View {
    let user: User
    @State private var selectedTab = 0

    var body: some View {
        VStack {
            Picker("", selection: $selectedTab) {
                Text("Posts").tag(0)
                Text("Posts & Replies").tag(1)
                Text("Media").tag(2)
                Text("About").tag(3)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()

            Group {
                if selectedTab == 0 {
                    UserPostsView(user: user)
                } else if selectedTab == 1 {
                    UserPostsAndRepliesView(user: user)
                } else if selectedTab == 2 {
                    UserMediaView(user: user)
                } else if selectedTab == 3 {
                    UserAboutView(user: user)
                }
            }
            .padding()
        }
    }
}

// MARK: - Placeholder Views for Tab Content

struct UserPostsView: View {
    let user: User
    var body: some View {
        Text("User Posts for \(user.username)")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct UserPostsAndRepliesView: View {
    let user: User
    var body: some View {
        Text("Posts & Replies for \(user.username)")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct UserMediaView: View {
    let user: User
    var body: some View {
        Text("Media for \(user.username)")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct UserAboutView: View {
    let user: User
    var body: some View {
        Text("About \(user.username)")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - FollowersListView (Updated)

struct FollowersListView: View {
    @EnvironmentObject var profileViewModel: ProfileViewModel  // Use EnvironmentObject
    let userId: String

    var body: some View {
        NavigationView {
            List(profileViewModel.followers, id: \.id) { follower in
                NavigationLink(
                    destination: ProfileView(user: follower)  // Remove manual environment injection
                ) {
                    HStack {
                        AsyncImage(url: URL(string: follower.avatar ?? "")) { phase in
                            // ... (keep existing AsyncImage code)
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
        }
    }
}

// MARK: - FollowingListView (Updated)

struct FollowingListView: View {
    @EnvironmentObject var profileViewModel: ProfileViewModel  // Use EnvironmentObject
    let userId: String

    var body: some View {
        NavigationView {
            List(profileViewModel.following, id: \.id) { followingUser in
                NavigationLink(
                    destination: ProfileView(user: followingUser)  // Remove manual environment injection
                ) {
                    HStack {
                        AsyncImage(url: URL(string: followingUser.avatar ?? "")) { phase in
                            // ... (keep existing AsyncImage code)
                        }
                        VStack(alignment: .leading) {
                            Text(followingUser.display_name ?? followingUser.username)
                                .font(.headline)
                            Text("@\(followingUser.username)")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            .navigationTitle("Following")
        }
    }
}

struct EditProfileView: View {
    let user: User
    @EnvironmentObject var profileViewModel: ProfileViewModel
    @Environment(\.dismiss) var dismiss
    @State private var username: String
    @State private var displayName: String
    @State private var bio: String

    init(user: User) {
        self.user = user
        _username = State(initialValue: user.username)
        _displayName = State(initialValue: user.display_name ?? "")
        _bio = State(initialValue: user.note ?? "")
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Profile Information")) {
                    TextField("Username", text: $username)
                    TextField("Display Name", text: $displayName)
                    TextEditor(text: $bio)
                        .frame(height: 100)
                }
                Section {
                    Button("Save Changes") {
                        Task {
                            await profileViewModel.updateProfile(for: user.id, updatedFields: [
                                "username": username,
                                "display_name": displayName,
                                "note": bio
                            ])
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

