//
//  TimelineView.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 14/09/24.
//

import SwiftUI

struct TimelineView: View {
    @EnvironmentObject var viewModel: TimelineViewModel

    var body: some View {
        VStack {
            if viewModel.isLoading {
                ProgressView("Loading...")
                    .padding()
            } else {
                List(viewModel.posts) { post in
                    PostRowView(post: post)
                        .environmentObject(viewModel)
                }
                .listStyle(PlainListStyle())
            }
        }
        .alert(item: $viewModel.alertError) { error in
            Alert(
                title: Text("Error"),
                message: Text(error.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}

struct TimelineView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a sample account
        let sampleAccount = Account(
            id: "a1",
            username: "user1",
            displayName: "User One",
            avatar: URL(string: "https://example.com/avatar1.png")!,
            acct: "user1"
        )
        // Create a sample post
        let samplePost = Post(
            id: "1",
            content: "<p>Hello, world!</p>",
            createdAt: Date(),
            account: sampleAccount,
            mediaAttachments: [],
            isFavourited: false,
            isReblogged: false,
            reblogsCount: 0,
            favouritesCount: 0,
            repliesCount: 0
        )
        
        // A local mock service just for preview
        class PreviewService: MastodonServiceProtocol {
            var baseURL: URL?
            
            // Store a reference to our sample post
            private let previewPost: Post
            
            init(samplePost: Post) {
                self.previewPost = samplePost
            }
            
            func fetchHomeTimeline() async throws -> [Post] {
                [previewPost]
            }
            func fetchPosts(keyword: String) async throws -> [Post] {
                []
            }
            func likePost(postID: String) async throws -> Post {
                previewPost
            }
            func unlikePost(postID: String) async throws -> Post {
                previewPost
            }
            func repost(postID: String) async throws -> Post {
                previewPost
            }
            func undoRepost(postID: String) async throws -> Post {
                previewPost
            }
            func comment(postID: String, content: String) async throws -> Post {
                previewPost
            }
        }
        
        // Instantiate the preview service, passing in the sample post
        let service = PreviewService(samplePost: samplePost)
        let viewModel = TimelineViewModel(mastodonService: service)
        
        // Give the view model the sample post
        viewModel.posts = [samplePost]

        return TimelineView()
            .environmentObject(viewModel)
    }
}

