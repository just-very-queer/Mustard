import SwiftUI

struct ProfileContentView: View {
    let user: User
    @Binding var selectedTab: Int
    @Binding var profileNavigationPath: NavigationPath // Added for navigating from PostView

    @EnvironmentObject var profileViewModel: ProfileViewModel
    @EnvironmentObject var timelineViewModel: TimelineViewModel

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
                        if profileViewModel.mediaPosts.first?.account?.id != user.id || profileViewModel.mediaPosts.isEmpty {
                             await profileViewModel.loadMediaPosts(accountID: user.id)
                        }
                    } else {
                        // Assuming fetchUserPosts is smart enough or we add excludeReplies
                        // For simplicity, let's say fetchUserPosts always gets what's needed for tab 0/1 for now
                        // and ProfileViewModel filters or ProfileService handles `excludeReplies`
                         if profileViewModel.userPosts.first?.account?.id != user.id || profileViewModel.userPosts.isEmpty {
                            // Example: tell service to fetch posts, optionally excluding replies for tab 0
                            // await profileViewModel.fetchUserPosts(for: user.id, excludeReplies: newTab == 0)
                            await profileViewModel.fetchUserPosts(for: user.id) // Simplified
                        }
                    }
                }
            }

             if selectedTab == 2 { // Media Tab
                 if profileViewModel.isLoadingMediaPosts && profileViewModel.mediaPosts.isEmpty {
                     ProgressView("Loading Media...")
                         .frame(maxWidth: .infinity)
                         .padding()
                 } else {
                     UserMediaView(user: user, profileNavigationPath: $profileNavigationPath) // Pass NavigationPath
                 }
             } else { // Posts or Posts & Replies Tab
                 if profileViewModel.isLoadingUserPosts && profileViewModel.userPosts.isEmpty {
                     ProgressView("Loading Posts...")
                         .frame(maxWidth: .infinity)
                         .padding()
                 } else {
                     LazyVStack(spacing: 0) {
                         switch selectedTab {
                         case 0: // Posts
                              UserPostsView(user: user, excludeReplies: true, profileNavigationPath: $profileNavigationPath)
                         case 1: // Posts & Replies
                              UserPostsView(user: user, excludeReplies: false, profileNavigationPath: $profileNavigationPath)
                         default:
                              EmptyView()
                         }
                     }
                 }
             }
        }
    }
}
