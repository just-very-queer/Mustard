import SwiftUI

struct PostSectionView: View {
    let posts: [Post]
    @ObservedObject var timelineViewModel: TimelineViewModel // For PostView's viewModel
    @Binding var navigationPath: NavigationPath // For navigating to user profiles from PostView
    let onPostTap: (Post) -> Void // For handling tap to show detail sheet

    var body: some View {
        Section(header: Text("Posts").font(.headline)) {
            ForEach(posts) { post in
                PostView(
                    post: post,
                    viewModel: timelineViewModel,
                    viewProfileAction: { user in navigationPath.append(user) },
                    interestScore: 0.0 // Or pass dynamically if available from search results
                )
                .contentShape(Rectangle()) // Make the whole area tappable
                .onTapGesture { onPostTap(post) }
                .listRowInsets(EdgeInsets()) // To make PostView take full width if needed
                .padding(.vertical, 5) // Consistent with original SearchView
            }
        }
    }
}
