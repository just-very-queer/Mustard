//
//  ProfileView.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 24/01/25.
// (REVISED & FIXED)

import SwiftUI

struct ProfileView: View {
    let user: User // The user whose profile is being viewed

    // Environment Objects
    @EnvironmentObject var profileViewModel: ProfileViewModel
    @EnvironmentObject var authViewModel: AuthenticationViewModel
    @EnvironmentObject var timelineViewModel : TimelineViewModel // For PostView actions

    // State
    @State private var showFollowers = false
    @State private var showFollowing = false
    @State private var showEditProfile = false
    @State private var selectedTab = 0 // Posts = 0, Posts & Replies = 1, Media = 2

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                ProfileHeaderView(user: user)

                if let bio = user.note, !bio.isEmpty {
                    Text(HTMLUtils.convertHTMLToPlainText(html: bio)) // Assumes HTMLUtils exists
                        .font(.body)
                        .padding(.horizontal)
                }

                ProfileStatsView(user: user,
                                 onFollowersTapped: { showFollowers.toggle() },
                                 onFollowingTapped: { showFollowing.toggle() })

                ProfileActionsView(user: user, showEditProfile: $showEditProfile)

                // --- Profile Content (Posts/Replies/Media) ---
                ProfileContentView(user: user, selectedTab: $selectedTab)
                     // Pass needed ViewModels down
                    .environmentObject(timelineViewModel) // Needed for PostView actions
                    .environmentObject(profileViewModel) // Needed for userPosts data

            }
            .padding(.bottom) // Add padding at the bottom
        }
        .navigationTitle(user.display_name ?? user.username)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showFollowers) {
             FollowersListView(userId: user.id)
                 // Pass EnvironmentObjects if FollowersListView needs them
                 .environmentObject(profileViewModel)
                 .environmentObject(authViewModel)
                 .environmentObject(timelineViewModel)
        }
        .sheet(isPresented: $showFollowing) {
             FollowingListView(userId: user.id)
                 // Pass EnvironmentObjects if FollowingListView needs them
                 .environmentObject(profileViewModel)
                 .environmentObject(authViewModel)
                 .environmentObject(timelineViewModel)
        }
        .sheet(isPresented: $showEditProfile) {
             EditProfileView(user: user) // Assumes user is the authenticated user
                 .environmentObject(profileViewModel)
                 .environmentObject(authViewModel)
        }
        .task(id: user.id) { // Re-run task when user.id changes
            // Fetch all profile data when the view appears or the user changes
            await profileViewModel.fetchFollowers(for: user.id)
            await profileViewModel.fetchFollowing(for: user.id)
            await profileViewModel.fetchUserPosts(for: user.id) // <-- Fetch user posts
        }
        // Add alert presentation for profileViewModel errors
         .alert(isPresented: $profileViewModel.showAlert) {
             Alert(title: Text("Profile Info"), message: Text(profileViewModel.alertMessage ?? "An unknown error occurred."), dismissButton: .default(Text("OK")))
         }
    }
}

// MARK: - ProfileContentView (Segmented Tabs) - Uses Corrected Subviews
struct ProfileContentView: View {
    let user: User
    @Binding var selectedTab: Int
    // Get ViewModels from Environment (already passed from ProfileView)
    @EnvironmentObject var profileViewModel: ProfileViewModel
    @EnvironmentObject var timelineViewModel: TimelineViewModel

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                Text("Posts").tag(0)
                Text("Posts & Replies").tag(1) // API might need parameter exclude_replies=false
                Text("Media").tag(2)         // API might need parameter only_media=true
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding([.horizontal, .bottom])

            // --- Content Based on Tab ---
            // Add loading indicator based on profileViewModel state
             if profileViewModel.isLoadingUserPosts && selectedTab != 2 { // Show loading for posts/replies tabs
                 ProgressView("Loading Posts...")
                     .frame(maxWidth: .infinity)
                     .padding()
             } else {
                // Use LazyVStack for performance if lists are long
                LazyVStack(spacing: 0) {
                    switch selectedTab {
                    case 0:
                         UserPostsView(user: user) // Passes env objects implicitly
                    case 1:
                         UserPostsAndRepliesView(user: user) // Passes env objects implicitly
                    case 2:
                         UserMediaView(user: user) // Passes env objects implicitly
                    default:
                         EmptyView()
                    }
                }
            }
        }
    }
}


// MARK: - Corrected Views for Tab Content

// --- UserPostsView ---
struct UserPostsView: View {
    let user: User
    @EnvironmentObject var profileViewModel: ProfileViewModel // Source of userPosts
    @EnvironmentObject var timelineViewModel: TimelineViewModel // For PostView actions

    var body: some View {
        // Check if posts are loaded and not empty
        if profileViewModel.userPosts.isEmpty && !profileViewModel.isLoadingUserPosts {
            Text("No posts found.")
                .foregroundColor(.gray)
                .padding()
                .frame(maxWidth: .infinity) // Center text
        } else {
            // Iterate over userPosts from profileViewModel
            ForEach(profileViewModel.userPosts) { post in
                // *** FIXED: Use correct PostView signature ***
                PostView(
                    post: post,
                    viewModel: timelineViewModel, // Use timelineViewModel for actions
                    viewProfileAction: { profileUser in
                        // Already on a profile, maybe prevent recursive navigation
                         print("Profile tapped within UserPostsView: \(profileUser.id)")
                    }
                )
                CustomDivider().padding(.horizontal)
            }
        }
    }
}

// --- UserPostsAndRepliesView ---
// IMPORTANT: This requires profileViewModel.fetchUserPosts to fetch replies too.
// The standard /statuses endpoint might need parameters like `exclude_replies=false`.
// Adjust fetch logic in ProfileViewModel/ProfileService accordingly.
struct UserPostsAndRepliesView: View {
    let user: User
    @EnvironmentObject var profileViewModel: ProfileViewModel // Assumes userPosts includes replies
    @EnvironmentObject var timelineViewModel: TimelineViewModel // For actions

    var body: some View {
        let postsAndReplies = profileViewModel.userPosts // Use the fetched list
        if postsAndReplies.isEmpty && !profileViewModel.isLoadingUserPosts {
             Text("No posts or replies found.")
                 .foregroundColor(.gray)
                 .padding()
                 .frame(maxWidth: .infinity)
        } else {
             ForEach(postsAndReplies) { post in
                 // *** FIXED: Use correct PostView signature ***
                 PostView(
                     post: post,
                     viewModel: timelineViewModel, // Use timelineViewModel for actions
                     viewProfileAction: { profileUser in
                         print("Profile tapped within UserPostsAndRepliesView: \(profileUser.id)")
                     }
                 )
                 CustomDivider().padding(.horizontal)
             }
         }
    }
}

// --- UserMediaView ---
// IMPORTANT: This requires fetching posts with `only_media=true`.
// You'll need a separate property and fetch function in ProfileViewModel for this.
struct UserMediaView: View {
   let user: User
   @EnvironmentObject var profileViewModel: ProfileViewModel // Needs a specific `userMediaPosts` property

   var body: some View {
       // TODO: Fetch and display posts with media from profileViewModel
        // Example: ForEach(profileViewModel.userMediaPosts) { post ... }
        Text("Media View - Implementation Needed")
            .frame(maxWidth: .infinity) // Center text
            .foregroundColor(.gray)
            .padding()
            .onAppear {
                 // Task { await profileViewModel.fetchUserMediaPosts(for: user.id) } // Example fetch call
            }
   }
}

// MARK: - Subviews (ProfileHeaderView, ProfileStatsView, etc.) - No changes needed from previous version

struct ProfileHeaderView: View {
    let user: User
    var body: some View {
        HStack {
            AsyncImage(url: URL(string: user.avatar ?? "")) { phase in
                 switch phase {
                 case .empty: ProgressView()
                 case .success(let image): image.resizable().scaledToFill().frame(width: 100, height: 100).clipShape(Circle())
                 case .failure: Image(systemName: "person.crop.circle.fill").resizable().scaledToFill().frame(width: 100, height: 100).foregroundColor(.gray)
                 @unknown default: EmptyView()
                 }
            }.frame(width: 100, height: 100)
            VStack(alignment: .leading) {
                Text(user.display_name ?? user.username).font(.largeTitle).bold()
                Text("@\(user.acct)").font(.subheadline).foregroundColor(.gray) // Use acct
            }
            Spacer()
        }.padding()
    }
}

struct ProfileStatsView: View {
    let user: User
    var onFollowersTapped: () -> Void
    var onFollowingTapped: () -> Void
    var body: some View {
        HStack {
            VStack { Text("Posts"); Text("\(user.statuses_count ?? 0)").font(.title3).bold() }.frame(maxWidth: .infinity)
            Divider().frame(height: 30)
            Button(action: onFollowersTapped) { VStack { Text("Followers"); Text("\(user.followers_count ?? 0)").font(.title3).bold() } }.buttonStyle(.plain).frame(maxWidth: .infinity)
            Divider().frame(height: 30)
            Button(action: onFollowingTapped) { VStack { Text("Following"); Text("\(user.following_count ?? 0)").font(.title3).bold() } }.buttonStyle(.plain).frame(maxWidth: .infinity)
        }
        .font(.subheadline).foregroundColor(.secondary).padding()
    }
}

struct ProfileActionsView: View {
    let user: User
    @Binding var showEditProfile: Bool
    @EnvironmentObject var authViewModel: AuthenticationViewModel
     var body: some View {
         if authViewModel.currentUser?.id == user.id {
             Button { showEditProfile.toggle() } label: { Label("Edit Profile", systemImage: "pencil").padding(.horizontal).padding(.vertical, 8) }.buttonStyle(.bordered).padding(.top)
         } else {
             // Placeholder for Follow/Unfollow button
             Text("Follow Button Placeholder").font(.caption).foregroundColor(.gray).padding(.top)
         }
     }
}

// MARK: - Followers/Following List Views (No changes needed from previous version)

struct FollowersListView: View {
    let userId: String
    @EnvironmentObject var profileViewModel: ProfileViewModel
    @EnvironmentObject var timelineViewModel: TimelineViewModel
    @EnvironmentObject var authViewModel: AuthenticationViewModel
    var body: some View {
        NavigationView {
            List(profileViewModel.followers, id: \.id) { follower in
                NavigationLink(destination: ProfileView(user: follower)) {
                    HStack {
                        AvatarView(url: URL(string: follower.avatar ?? ""), size: 40)
                        VStack(alignment: .leading) {
                            Text(follower.display_name ?? follower.username).font(.headline)
                            Text("@\(follower.acct)").font(.subheadline).foregroundColor(.gray)
                        }
                    }
                }
                 .environmentObject(profileViewModel)
                 .environmentObject(timelineViewModel)
                 .environmentObject(authViewModel)
            }
            .navigationTitle("Followers").listStyle(.plain)
        }
    }
}

struct FollowingListView: View {
    let userId: String
    @EnvironmentObject var profileViewModel: ProfileViewModel
    @EnvironmentObject var timelineViewModel: TimelineViewModel
    @EnvironmentObject var authViewModel: AuthenticationViewModel
    var body: some View {
        NavigationView {
             List(profileViewModel.following, id: \.id) { followingUser in
                 NavigationLink(destination: ProfileView(user: followingUser)) {
                     HStack {
                         AvatarView(url: URL(string: followingUser.avatar ?? ""), size: 40)
                         VStack(alignment: .leading) {
                             Text(followingUser.display_name ?? followingUser.username).font(.headline)
                             Text("@\(followingUser.acct)").font(.subheadline).foregroundColor(.gray)
                         }
                     }
                 }
                 .environmentObject(profileViewModel)
                 .environmentObject(timelineViewModel)
                 .environmentObject(authViewModel)
             }
            .navigationTitle("Following").listStyle(.plain)
        }
    }
}

// EditProfileView (No changes needed from previous version)
struct EditProfileView: View {
    let user: User
    @EnvironmentObject var profileViewModel: ProfileViewModel
    @Environment(\.dismiss) var dismiss
    @State private var displayName: String
    @State private var bio: String

    init(user: User) {
        self.user = user
        _displayName = State(initialValue: user.display_name ?? "")
        _bio = State(initialValue: user.note ?? "")
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Profile Information")) {
                    TextField("Display Name", text: $displayName)
                    TextEditor(text: $bio).frame(height: 150)
                }
                Section {
                    Button("Save Changes") {
                        Task {
                            await profileViewModel.updateProfile(for: user.id, updatedFields: [
                                "display_name": displayName, "note": bio
                            ])
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) { Button("Cancel") { dismiss() } }
            }
        }
    }
}


// Ensure CustomDivider, AvatarView, HTMLUtils etc. are defined.
// struct CustomDivider: View { /* ... */ }
// struct AvatarView: View { /* ... */ }
// struct HTMLUtils { static func convertHTMLToPlainText(html: String) -> String { /* ... */ } }
