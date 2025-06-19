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
    
    // Navigation path for profile-specific post detail views
    @State private var profileNavigationPath = NavigationPath()


    var body: some View {
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

                    ProfileContentView(user: user, selectedTab: $selectedTab, profileNavigationPath: $profileNavigationPath)
                        .environmentObject(timelineViewModel)
                        .environmentObject(profileViewModel)
                }
                .padding(.bottom)
            }
            .navigationTitle(user.display_name ?? user.username)
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showFollowers) {
                 FollowersListView(userId: user.id)
                     .environmentObject(profileViewModel)
                     .environmentObject(authViewModel)
                     .environmentObject(timelineViewModel)
            }
            .sheet(isPresented: $showFollowing) {
                 FollowingListView(userId: user.id)
                     .environmentObject(profileViewModel)
                     .environmentObject(authViewModel)
                     .environmentObject(timelineViewModel)
            }
            .sheet(isPresented: $showEditProfile) {
                 EditProfileView(user: user)
                     .environmentObject(profileViewModel)
                     .environmentObject(authViewModel)
            }
            .task(id: user.id) {
                await profileViewModel.fetchFollowers(for: user.id)
                await profileViewModel.fetchFollowing(for: user.id)
                // Determine which posts to fetch based on the initially selected tab
                if selectedTab == 2 {
                    await profileViewModel.loadMediaPosts(accountID: user.id)
                } else {
                    // excludeReplies: selectedTab == 0 (Posts only) vs false for Posts & Replies
                    await profileViewModel.fetchUserPosts(for: user.id /*, excludeReplies: selectedTab == 0 */)
                }
            }
             .alert(isPresented: $profileViewModel.showAlert) {
                 Alert(title: Text("Profile Info"), message: Text(profileViewModel.alertMessage ?? "An unknown error occurred."), dismissButton: .default(Text("OK")))
             }
             // Navigation destination for posts tapped within the profile
             .navigationDestination(for: Post.self) { postDestination in
                 PostDetailView(post: postDestination, viewModel: timelineViewModel, showDetail: .constant(true))
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
