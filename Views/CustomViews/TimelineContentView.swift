//
//  TimelineContentView.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 07/02/25.
// (REVISED: Added missing supporting view definitions)

import SwiftUI
import OSLog

// MARK: - Supporting View: TrendingPostCardView

struct TrendingPostCardView: View {
    let post: Post

    private let lineLimit = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Mini Header
            HStack {
                AvatarView(url: post.account?.avatar, size: 30)
                VStack(alignment: .leading, spacing: 1) {
                    Text(post.account?.display_name ?? post.account?.username ?? "Unknown")
                        .font(.caption).bold().lineLimit(1)
                    Text("@\(post.account?.acct ?? "unknown")")
                        .font(.caption2).foregroundColor(.gray).lineLimit(1)
                }
                Spacer()
            }
            .padding([.horizontal, .top], 8)

            // Content Snippet
            Text(HTMLUtils.convertHTMLToPlainText(html: post.content))
                .font(.footnote)
                .lineLimit(lineLimit)
                .padding(.horizontal, 8)

            // Media Thumbnail
            if let firstAttachment = post.mediaAttachments.first,
               let previewUrl = firstAttachment.previewURL ?? firstAttachment.url {
                Spacer()
                AsyncImage(url: previewUrl) { phase in
                    if let image = phase.image {
                        image.resizable().aspectRatio(contentMode: .fill).frame(height: 60).clipped()
                    } else if phase.error != nil {
                        Rectangle().fill(Color.gray.opacity(0.2)).frame(height: 60)
                            .overlay(Image(systemName: "photo").foregroundColor(.gray))
                    } else {
                        Rectangle().fill(Color.gray.opacity(0.1)).frame(height: 60)
                    }
                }
            } else {
                 Spacer()
            }

            // Footer Counts
            HStack {
                 Spacer()
                 Image(systemName: "heart").font(.caption2).foregroundColor(.gray)
                 Text("\(post.favouritesCount)").font(.caption2).foregroundColor(.gray)
                 Image(systemName: "arrow.2.squarepath").font(.caption2).foregroundColor(.gray).padding(.leading, 5)
                 Text("\(post.reblogsCount)").font(.caption2).foregroundColor(.gray)
            }
            .padding([.horizontal, .bottom], 8)
        }
        .frame(width: 200, height: 170)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
        .overlay(
             RoundedRectangle(cornerRadius: 10)
                 .stroke(Color.gray.opacity(0.2), lineWidth: 1)
         )
    }
}

// MARK: - Supporting View: PostFooterView

struct PostFooterView: View {
    let isLoadingMore: Bool
    @ObservedObject var viewModel: TimelineViewModel // Pass only if actions are needed directly here

    var body: some View {
        if isLoadingMore {
            HStack { Spacer(); ProgressView(); Spacer() }.padding()
        } else {
            // Provides a consistent space at the bottom when not loading more
            // Adjust height as needed for visual spacing
            Spacer().frame(height: 40)
        }
    }
}


// MARK: - Main View: TimelineContentView

struct TimelineContentView: View {
    @ObservedObject var viewModel: TimelineViewModel
    // Logout button removed, so authViewModel is likely not needed directly here anymore
    // @EnvironmentObject var authViewModel: AuthenticationViewModel

    @State private var isShowingFullScreenImage = false
    @State private var selectedImageURL: URL?

    private let logger = Logger(subsystem: "titan.mustard.app.ao", category: "TimelineContentView")

    var body: some View {
        VStack(spacing: 0) {
            // --- Filter Picker ---
            Picker("Filter", selection: $viewModel.selectedFilter) {
                ForEach(TimelineViewModel.TimelineFilter.allCases) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            .padding(.bottom, 8)

            // --- Main ScrollView ---
            ScrollView {
                VStack(spacing: 16) {
                    // --- Top Posts Section ---
                    topPostsSection
                        .padding(.top, 10)

                    // --- Divider ---
                    if !viewModel.posts.isEmpty {
                        Divider().padding(.horizontal)
                    }

                    // --- Main Timeline Section ---
                    timelineSection
                }
            }
        }
        .refreshable {
            await viewModel.refreshTimeline()
        }
        // --- Sheet Modifiers ---
        .sheet(isPresented: $isShowingFullScreenImage) {
            if let imageURL = selectedImageURL {
                FullScreenImageView(imageURL: imageURL, isPresented: $isShowingFullScreenImage)
            }
        }
        .sheet(isPresented: $viewModel.showingCommentSheet) {
             if let post = viewModel.selectedPostForComments {
                  NavigationView {
                      ExpandedCommentsSection(
                          post: post,
                          isExpanded: .constant(true),
                          commentText: $viewModel.commentText,
                          viewModel: viewModel
                      )
                      .navigationTitle("Reply")
                      .navigationBarTitleDisplayMode(.inline)
                      .toolbar{
                          ToolbarItem(placement: .navigationBarLeading) {
                              Button("Cancel") { viewModel.showingCommentSheet = false }
                          }
                          ToolbarItem(placement: .navigationBarTrailing) {
                              Button("Post") {
                                  viewModel.comment(on: post, content: viewModel.commentText)
                              }
                              .disabled(viewModel.commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                          }
                      }
                  }
             }
        }
        // --- Navigation Destinations ---
        .navigationDestination(for: User.self) { user in
             ProfileView(user: user) // Assumes ProfileViewModel injected higher up
        }
        .navigationDestination(for: Post.self) { post in
             PostDetailView(post: post, viewModel: viewModel, showDetail: .constant(true)) // Needs fixing if showDetail binding is incorrect
        }
        // --- Error Alert ---
        .alert(item: $viewModel.alertError) { error in
             Alert(title: Text("Error"), message: Text(error.message), dismissButton: .default(Text("OK")))
         }
         // --- Loading Overlay ---
         .overlay {
             if viewModel.isLoading && viewModel.posts.isEmpty {
                 ProgressView("Loading \(viewModel.selectedFilter.rawValue)...")
                     .padding()
                     .background(.thinMaterial)
                     .cornerRadius(10)
                     .transition(.opacity)
             }
         }
    } // End of body

    // MARK: - Top Posts Section
    @ViewBuilder
    private var topPostsSection: some View {
        if !viewModel.topPosts.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Trending Posts")
                    .font(.title2).bold()
                    .padding(.horizontal)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 15) {
                        ForEach(viewModel.topPosts) { post in
                            NavigationLink(value: post) {
                                 TrendingPostCardView(post: post) // Use the defined view
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                    .scrollTargetLayout()
                }
                .frame(height: 180)
            }
            .padding(.bottom, 10)
        } else if viewModel.isLoading {
             HStack { Spacer(); ProgressView(); Spacer() }
             .frame(height: 180)
             .padding(.bottom, 10)
        }
    }

    // MARK: - Main Timeline Section
    private var timelineSection: some View {
        LazyVStack(spacing: 0) {
            if viewModel.posts.isEmpty && !viewModel.isLoading {
                 Text(viewModel.selectedFilter == .latest ? "Your timeline is empty." : "No posts found for \(viewModel.selectedFilter.rawValue).")
                    .foregroundColor(.gray)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                ForEach(viewModel.posts) { post in
                    NavigationLink(value: post) {
                         PostView(
                             post: post,
                             viewModel: viewModel,
                             viewProfileAction: { user in
                                 viewModel.navigateToProfile(user)
                             },
                             interestScore: 0.0
                         )
                         .onImageTap { imageUrl in
                             if let url = imageUrl {
                                 self.selectedImageURL = url
                                 self.isShowingFullScreenImage = true
                             }
                         }
                     }
                     .buttonStyle(.plain)

                    CustomDivider().padding(.horizontal)

                    // Pagination Trigger
                    if post.id == viewModel.posts.last?.id && !viewModel.isFetchingMore {
                         PostFooterView(isLoadingMore: viewModel.isFetchingMore, viewModel: viewModel)
                             .padding(.vertical)
                             .onAppear {
                                 logger.debug("Last item appeared, fetching more.")
                                 // FIX: Wrap the async call in a Task
                                 Task {
                                     await viewModel.fetchMoreTimeline()
                                 }
                             }
                     }
                }

                // Loading indicator
                 if viewModel.isFetchingMore {
                     ProgressView().padding(.vertical).frame(maxWidth: .infinity)
                 }
            }
        }
    }
}


// MARK: - PostView Extension (Example for Image Tap)
// Add this extension or integrate the `onImageTap` callback into your existing PostView definition

extension PostView {
    func onImageTap(_ action: @escaping (URL?) -> Void) -> some View {
        // Modify PostView's internal structure to detect taps on its MediaAttachmentView
        // and call the provided action. This is a conceptual example.
        // You'll need to adapt this based on PostView's actual implementation.
        // For instance, find the MediaAttachmentView inside PostView and add an onTapGesture there
        // that calls `action(post.mediaAttachments.first?.url)`.
        self // Return self for modifier chaining
    }
}
