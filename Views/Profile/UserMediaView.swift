import SwiftUI

// UserMediaView also needs profileNavigationPath if media items are tappable to PostDetailView
struct UserMediaView: View {
    @EnvironmentObject var viewModel: ProfileViewModel // ProfileViewModel
    @EnvironmentObject var timelineViewModel: TimelineViewModel // For PostView inside PostDetailView
    let user: User
    @Binding var profileNavigationPath: NavigationPath // Added for navigation

    private let gridItems: [GridItem] = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]

    // Using NavigationLink value for the sheet's .item
    @State private var selectedPostForSheet: Post? = nil

    var body: some View {
        Group {
            if viewModel.mediaPosts.isEmpty && !viewModel.isLoadingMediaPosts {
                Text("No media posts yet.")
                    .foregroundColor(.gray)
                    .padding()
                    .frame(maxWidth: .infinity)
            } else {
                ScrollView { // Added ScrollView
                    LazyVGrid(columns: gridItems, spacing: 2) {
                        ForEach(viewModel.mediaPosts) { post in
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
                         viewModel: timelineViewModel,
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
             if viewModel.mediaPosts.first?.account?.id != user.id && !viewModel.isLoadingMediaPosts {
                 await viewModel.loadMediaPosts(accountID: user.id)
            }
        }
    }
}
