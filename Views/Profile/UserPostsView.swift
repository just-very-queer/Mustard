import SwiftUI

struct UserPostsView: View {
    let user: User
    let excludeReplies: Bool
    @Binding var profileNavigationPath: NavigationPath

    @EnvironmentObject var profileViewModel: ProfileViewModel
    @EnvironmentObject var timelineViewModel: TimelineViewModel

    var postsToDisplay: [Post] {
        if excludeReplies {
            // Filter out posts that are replies to someone else, but keep original posts and reblogs of originals
            return profileViewModel.userPosts.filter { post in
                if post.reblog != nil { return true } // Keep all reblogs
                // Check if 'inReplyToId' or similar field exists and is nil for original posts
                // Assuming Post model has 'inReplyToPostId: String?' or 'inReplyToAccountId: String?'
                // For simplicity, if Post.inReplyTo (another Post object) is nil, it's not a reply to someone else.
                return post.inReplyTo == nil // Modify based on your Post model's reply indication
            }
        } else {
            return profileViewModel.userPosts // Show all, including replies to others
        }
    }

    var body: some View {
        if postsToDisplay.isEmpty && !profileViewModel.isLoadingUserPosts {
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
                        viewModel: timelineViewModel,
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
