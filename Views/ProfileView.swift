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
    @State private var followers: [User] = []
    @State private var following: [User] = []
    @State private var userPosts: [Post] = []
    @State private var mediaPosts: [Post] = []
    @State private var isLoadingUserPosts: Bool = false
    @State private var isLoadingMediaPosts: Bool = false
    @State private var alertMessage: String?
    @State private var showAlert: Bool = false
    @EnvironmentObject var authViewModel: AuthenticationViewModel
    @EnvironmentObject var timelineViewModel : TimelineViewModel // For PostView actions

    // State
    @State private var showFollowers = false
    @State private var showFollowing = false
    @State private var showEditProfile = false
    @State private var selectedTab = 0 // Posts = 0, Posts & Replies = 1, Media = 2
    
    // Navigation path for profile-specific post detail views
    @State private var profileNavigationPath = NavigationPath()
    @State private var showGlow = false


    var body: some View {
        ZStack {
            if showGlow {
                GlowEffect()
                    .edgesIgnoringSafeArea(.all)
                    .transition(.opacity)
            }

            // Wrap with NavigationStack to handle navigation from PostView
            NavigationStack(path: $profileNavigationPath) {
                ScrollView {
                    VStack(spacing: 20) {
                        ProfileHeaderView(user: user)

                    if let bioNote = user.note, !bioNote.isEmpty {
                        // Use PostContentView for rich text display of bio
                        // Need to wrap it or adjust PostContentView if it's too post-specific
                        // For now, simple text with HTML conversion.
                        // If complex HTML (links, etc.) in bio, consider a dedicated BioView.
                         Text(HTMLUtils.convertHTMLToPlainText(html: bioNote))
                            .font(.custom("Verdana", size: UIFont.systemFontSize)) // Using systemFontSize for bio
                            .foregroundColor(Color(.label)) // Adapts to light/dark
                            .padding(.horizontal)
                            .frame(maxWidth: .infinity, alignment: .leading)

                    }

                    ProfileStatsView(user: user,
                                     onFollowersTapped: { showFollowers.toggle() },
                                     onFollowingTapped: { showFollowing.toggle() })

                    ProfileActionsView(user: user, showEditProfile: $showEditProfile)

                    ProfileContentView(user: user, selectedTab: $selectedTab, profileNavigationPath: $profileNavigationPath, followers: $followers, following: $following, userPosts: $userPosts, mediaPosts: $mediaPosts, isLoadingUserPosts: $isLoadingUserPosts, isLoadingMediaPosts: $isLoadingMediaPosts, alertMessage: $alertMessage, showAlert: $showAlert)
                }
                .padding(.bottom)
            }
            .navigationTitle(user.display_name ?? user.username)
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showFollowers) {
                 FollowersListView(userId: user.id, followers: $followers)
                     .environmentObject(authViewModel)
            }
            .sheet(isPresented: $showFollowing) {
                 FollowingListView(userId: user.id, following: $following)
                     .environmentObject(authViewModel)
            }
            .sheet(isPresented: $showEditProfile) {
                 EditProfileView(user: user, alertMessage: $alertMessage, showAlert: $showAlert)
                     .environmentObject(authViewModel)
            }
            .task(id: user.id) {
                triggerGlow()
                await fetchFollowers(for: user.id)
                await fetchFollowing(for: user.id)
                // Determine which posts to fetch based on the initially selected tab
                if selectedTab == 2 {
                    await loadMediaPosts(accountID: user.id)
                } else {
                    // excludeReplies: selectedTab == 0 (Posts only) vs false for Posts & Replies
                    await fetchUserPosts(for: user.id /*, excludeReplies: selectedTab == 0 */)
                }
            }
             .alert(isPresented: $showAlert) {
                 Alert(title: Text("Profile Info"), message: Text(alertMessage ?? "An unknown error occurred."), dismissButton: .default(Text("OK")))
             }
             // Navigation destination for posts tapped within the profile
             .navigationDestination(for: Post.self) { postDestination in
                 PostDetailView(post: postDestination, showDetail: .constant(true))
             }
             // Navigation destination for user profiles tapped within posts on the profile
             .navigationDestination(for: User.self) { userDestination in
                 // Ensure this doesn't create a loop if tapping the same user's profile link
                 if userDestination.id != user.id {
                     ProfileView(user: userDestination)
                 } else {
                     // Potentially do nothing or show a subtle feedback if tapping current profile user
                     // For simplicity, just allow it. It might refresh the view.
                     ProfileView(user: userDestination)
                 }
             }
        }
    }

    private func triggerGlow() {
        withAnimation {
            showGlow = true
        }
        Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { _ in
            withAnimation(.easeOut(duration: 1.0)) {
                showGlow = false
            }
        }
    }
}

    func fetchFollowers(for accountId: String) async {
        let profileService = ProfileService(mastodonAPIService: MastodonAPIService.shared)
        do {
            self.followers = try await profileService.fetchFollowers(for: accountId)
        } catch {
            self.alertMessage = "Error fetching followers: \(error.localizedDescription)"
            self.showAlert = true
        }
    }

    func fetchFollowing(for accountId: String) async {
        let profileService = ProfileService(mastodonAPIService: MastodonAPIService.shared)
        do {
            self.following = try await profileService.fetchFollowing(for: accountId)
        } catch {
            self.alertMessage = "Error fetching following: \(error.localizedDescription)"
            self.showAlert = true
        }
    }

    func fetchUserPosts(for accountId: String) async {
        let profileService = ProfileService(mastodonAPIService: MastodonAPIService.shared)
        isLoadingUserPosts = true
        self.userPosts = []
        do {
            self.userPosts = try await profileService.fetchStatuses(for: accountId)
        } catch {
            self.alertMessage = "Error fetching user posts: \(error.localizedDescription)"
            self.showAlert = true
        }
        isLoadingUserPosts = false
    }

    func loadMediaPosts(accountID: String) async {
        let profileService = ProfileService(mastodonAPIService: MastodonAPIService.shared)
        isLoadingMediaPosts = true
        self.mediaPosts = []
        do {
            self.mediaPosts = try await profileService.fetchUserMediaPosts(accountID: accountID, maxId: nil)
        } catch {
            self.alertMessage = "Error fetching media posts: \(error.localizedDescription)"
            self.showAlert = true
        }
        isLoadingMediaPosts = false
    }
}

struct ProfileContentView: View {
    let user: User
    @Binding var selectedTab: Int
    @Binding var profileNavigationPath: NavigationPath // Added for navigating from PostView
    @Binding var followers: [User]
    @Binding var following: [User]
    @Binding var userPosts: [Post]
    @Binding var mediaPosts: [Post]
    @Binding var isLoadingUserPosts: Bool
    @Binding var isLoadingMediaPosts: Bool
    @Binding var alertMessage: String?
    @Binding var showAlert: Bool

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                Text("Posts").tag(0)
                Text("Posts & Replies").tag(1) // This might require a different fetch or filter
                Text("Media").tag(2)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding([.horizontal, .bottom])
            .onChange(of: selectedTab) { oldTab, newTab in
                // Fetch data based on the new tab
                Task {
                    if newTab == 2 {
                        if mediaPosts.first?.account?.id != user.id || mediaPosts.isEmpty {
                             // await loadMediaPosts(accountID: user.id)
                        }
                    } else {
                        // Assuming fetchUserPosts is smart enough or we add excludeReplies
                        // For simplicity, let's say fetchUserPosts always gets what's needed for tab 0/1 for now
                        // and ProfileViewModel filters or ProfileService handles `excludeReplies`
                         if userPosts.first?.account?.id != user.id || userPosts.isEmpty {
                            // Example: tell service to fetch posts, optionally excluding replies for tab 0
                            // await fetchUserPosts(for: user.id, excludeReplies: newTab == 0)
                            // await fetchUserPosts(for: user.id) // Simplified
                        }
                    }
                }
            }

             if selectedTab == 2 { // Media Tab
                 if isLoadingMediaPosts && mediaPosts.isEmpty {
                     ProgressView("Loading Media...")
                         .frame(maxWidth: .infinity)
                         .padding()
                 } else {
                     UserMediaView(user: user, profileNavigationPath: $profileNavigationPath, mediaPosts: $mediaPosts, isLoadingMediaPosts: $isLoadingMediaPosts) // Pass NavigationPath
                 }
             } else { // Posts or Posts & Replies Tab
                 if isLoadingUserPosts && userPosts.isEmpty {
                     ProgressView("Loading Posts...")
                         .frame(maxWidth: .infinity)
                         .padding()
                 } else {
                     LazyVStack(spacing: 0) {
                         switch selectedTab {
                         case 0: // Posts
                              UserPostsView(user: user, excludeReplies: true, profileNavigationPath: $profileNavigationPath, userPosts: $userPosts, isLoadingUserPosts: $isLoadingUserPosts)
                         case 1: // Posts & Replies
                              UserPostsView(user: user, excludeReplies: false, profileNavigationPath: $profileNavigationPath, userPosts: $userPosts, isLoadingUserPosts: $isLoadingUserPosts)
                         default:
                              EmptyView()
                         }
                     }
                 }
             }
        }
    }
}

struct UserPostsView: View {
    let user: User
    let excludeReplies: Bool
    @Binding var profileNavigationPath: NavigationPath
    @Binding var userPosts: [Post]
    @Binding var isLoadingUserPosts: Bool

    var postsToDisplay: [Post] {
        if excludeReplies {
            // Filter out posts that are replies to someone else, but keep original posts and reblogs of originals
            return userPosts.filter { post in
                if post.reblog != nil { return true } // Keep all reblogs
                // Check if 'inReplyToId' or similar field exists and is nil for original posts
                // Assuming Post model has 'inReplyToPostId: String?' or 'inReplyToAccountId: String?'
                // For simplicity, if Post.inReplyTo (another Post object) is nil, it's not a reply to someone else.
                return post.inReplyTo == nil // Modify based on your Post model's reply indication
            }
        } else {
            return userPosts // Show all, including replies to others
        }
    }

    var body: some View {
        if postsToDisplay.isEmpty && !isLoadingUserPosts {
            Text(excludeReplies ? "No original posts found." : "No posts or replies found.")
                .foregroundColor(.gray)
                .padding()
                .frame(maxWidth: .infinity)
        } else {
            ForEach(postsToDisplay) { post in
                // NavigationLink to navigate to PostDetailView for the *displayed* post
                NavigationLink(value: post.reblog ?? post) {
                    PostView(
                        post: post, // Pass the full post object (could be a reblog wrapper)
                        viewProfileAction: { profileUser in
                            // Use the passed-in NavigationPath for profile navigation
                            if profileUser.id != user.id { // Avoid navigating to self again from here
                                profileNavigationPath.append(profileUser)
                            }
                        },
                        interestScore: 0.0 // Or fetch if needed
                    )
                }
                .buttonStyle(.plain)
                CustomDivider().padding(.horizontal)
            }
        }
    }
}


// UserMediaView also needs profileNavigationPath if media items are tappable to PostDetailView
struct UserMediaView: View {
    let user: User
    @Binding var profileNavigationPath: NavigationPath // Added for navigation
    @Binding var mediaPosts: [Post]
    @Binding var isLoadingMediaPosts: Bool

    private let gridItems: [GridItem] = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]
    
    // Using NavigationLink value for the sheet's .item
    @State private var selectedPostForSheet: Post? = nil

    var body: some View {
        Group {
            if mediaPosts.isEmpty && !isLoadingMediaPosts {
                Text("No media posts yet.")
                    .foregroundColor(.gray)
                    .padding()
                    .frame(maxWidth: .infinity)
            } else {
                ScrollView { // Added ScrollView
                    LazyVGrid(columns: gridItems, spacing: 2) {
                        ForEach(mediaPosts) { post in
                            let postWithMedia = post.reblog ?? post
                            
                            if let attachments = postWithMedia.mediaAttachments, let firstAttachment = attachments.first,
                               let thumbnailUrlString = firstAttachment.previewURL?.absoluteString ?? firstAttachment.url?.absoluteString,
                               let thumbnailUrl = URL(string: thumbnailUrlString) {
                                
                                // Using a button to set the selectedPostForSheet, which triggers the .sheet
                                Button(action: {
                                    self.selectedPostForSheet = postWithMedia
                                }) {
                                    AsyncImage(url: thumbnailUrl) { phase in
                                        switch phase {
                                        case .empty: ProgressView().aspectRatio(1, contentMode: .fill)
                                        case .success(let image): image.resizable().aspectRatio(1, contentMode: .fill)
                                        case .failure: Image(systemName: "photo.fill").resizable().aspectRatio(1, contentMode: .fit).foregroundColor(.gray).padding().background(Color.gray.opacity(0.1))
                                        @unknown default: EmptyView()
                                        }
                                    }
                                }
                                .aspectRatio(1, contentMode: .fill)
                                .clipped()
                                .background(Color.gray.opacity(0.1))
                            } else {
                                Rectangle().fill(Color.gray.opacity(0.1)).aspectRatio(1, contentMode: .fill)
                            }
                        }
                    }
                }
                .sheet(item: $selectedPostForSheet) { postToDetail in
                     // The sheet now presents PostDetailView
                     PostDetailView(
                         post: postToDetail,
                         showDetail: Binding( // This binding controls this sheet
                             get: { selectedPostForSheet != nil },
                             set: { if !$0 { selectedPostForSheet = nil } }
                         )
                     )
                     // If PostDetailView needs to navigate further and is in a NavigationView itself,
                     // it will use its own navigation stack.
                }
            }
        }
        .task(id: user.id) {
             if mediaPosts.first?.account?.id != user.id && !isLoadingMediaPosts {
                 // await loadMediaPosts(accountID: user.id)
            }
        }
    }
}


// Unchanged subviews (ProfileHeaderView, ProfileStatsView, etc.) remain the same
// Ensure HTMLUtils.convertHTMLToPlainText and .attributedStringFromHTML exist and work as expected.
// Ensure AvatarView, CustomDivider also exist.

struct ProfileHeaderView: View {
    let user: User
    var body: some View {
        HStack {
            AvatarView(url: URL(string: user.avatar ?? ""), size: 80) // Slightly smaller avatar
            VStack(alignment: .leading) {
                Text(user.display_name ?? user.username).font(.title2).bold()
                Text("@\(user.acct)").font(.callout).foregroundColor(.gray)
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
            VStack { Text("\(user.statuses_count ?? 0)" ).font(.headline); Text("Posts").font(.caption).foregroundColor(.gray) }.frame(maxWidth: .infinity)
            Divider().frame(height: 30)
            Button(action: onFollowersTapped) { VStack { Text("\(user.followers_count ?? 0)").font(.headline); Text("Followers").font(.caption).foregroundColor(.gray) } }.buttonStyle(.plain).frame(maxWidth: .infinity)
            Divider().frame(height: 30)
            Button(action: onFollowingTapped) { VStack { Text("\(user.following_count ?? 0)").font(.headline); Text("Following").font(.caption).foregroundColor(.gray) } }.buttonStyle(.plain).frame(maxWidth: .infinity)
        }
        .padding(.horizontal)
    }
}

struct ProfileActionsView: View {
    let user: User
    @Binding var showEditProfile: Bool
    @EnvironmentObject var authViewModel: AuthenticationViewModel
     var body: some View {
         if authViewModel.currentUser?.id == user.id {
             Button { showEditProfile.toggle() } label: {
                 Text("Edit Profile")
                     .font(.headline)
                     .padding(.horizontal, 30)
                     .padding(.vertical, 8)
             }
             .buttonStyle(.borderedProminent)
             .padding(.top)
         } else {
             // Placeholder for follow/unfollow button
             Button {} label: {
                 Text("Follow") // Example
                     .font(.headline)
                     .padding(.horizontal, 30)
                     .padding(.vertical, 8)
             }
             .buttonStyle(.bordered) // Example style
             .padding(.top)
         }
     }
}

struct FollowersListView: View {
    let userId: String
    @Binding var followers: [User]
    @EnvironmentObject var authViewModel: AuthenticationViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            List(followers, id: \.id) { follower in
                NavigationLink(destination: ProfileView(user: follower)) {
                    HStack {
                        AvatarView(url: URL(string: follower.avatar ?? ""), size: 40)
                        VStack(alignment: .leading) {
                            Text(follower.display_name ?? follower.username).font(.headline)
                            Text("@\(follower.acct)").font(.subheadline).foregroundColor(.gray)
                        }
                    }
                }
            }
            .navigationTitle("Followers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) { Button("Done") { dismiss() } }
            }
            .listStyle(.plain)
        }
    }
}

struct FollowingListView: View {
    let userId: String
    @Binding var following: [User]
    @EnvironmentObject var authViewModel: AuthenticationViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
             List(following, id: \.id) { followingUser in
                 NavigationLink(destination: ProfileView(user: followingUser)) {
                     HStack {
                         AvatarView(url: URL(string: followingUser.avatar ?? ""), size: 40)
                         VStack(alignment: .leading) {
                             Text(followingUser.display_name ?? followingUser.username).font(.headline)
                             Text("@\(followingUser.acct)").font(.subheadline).foregroundColor(.gray)
                         }
                     }
                 }
             }
            .navigationTitle("Following")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) { Button("Done") { dismiss() } }
            }
            .listStyle(.plain)
        }
    }
}

struct EditProfileView: View {
    let user: User
    @Binding var alertMessage: String?
    @Binding var showAlert: Bool
    @Environment(\.dismiss) var dismiss
    @State private var displayName: String
    @State private var bio: String

    // Environment for color scheme
    @Environment(\.colorScheme) var colorScheme

    init(user: User, alertMessage: Binding<String?>, showAlert: Binding<Bool>) {
        self.user = user
        _alertMessage = alertMessage
        _showAlert = showAlert
        _displayName = State(initialValue: user.display_name ?? "")
        _bio = State(initialValue: HTMLUtils.convertHTMLToPlainText(html: user.note ?? ""))
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Profile Information")) {
                    TextField("Display Name", text: $displayName)
                    VStack(alignment: .leading) {
                        Text("Bio").font(.caption).foregroundColor(.gray)
                        TextEditor(text: $bio)
                            .frame(height: 150)
                            .border(colorScheme == .dark ? Color.gray.opacity(0.5) : Color.gray.opacity(0.2), width: 1) // Subtle border
                            .font(.custom("Verdana", size: UIFont.systemFontSize))
                    }
                }
                Section {
                    Button("Save Changes") {
                        Task {
                            let profileService = ProfileService(mastodonAPIService: MastodonAPIService.shared)
                            try await profileService.updateProfile(for: user.id, updatedFields: [
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
                ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { dismiss() } }
            }
        }
    }
}
