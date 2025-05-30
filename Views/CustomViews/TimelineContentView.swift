//
//  TimelineContentView.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 07/02/25.
// (REVISED: Added missing supporting view definitions and reply loading for comment sheet)

import SwiftUI
import OSLog

// MARK: - Supporting View: TrendingPostCardView

struct TrendingPostCardView: View {
    // This is the Post object whose content should be displayed (e.g., post.reblog ?? post)
    private var displayPost: Post {
        return post.reblog ?? post
    }
    
    let post: Post // The outer post object

    private let lineLimit = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Mini Header - Shows original author of the content
            HStack {
                AvatarView(url: displayPost.account?.avatar, size: 30)
                VStack(alignment: .leading, spacing: 1) {
                    Text(displayPost.account?.display_name ?? displayPost.account?.username ?? "Unknown")
                        .font(.caption).bold().lineLimit(1)
                    Text("@\(displayPost.account?.acct ?? "unknown")")
                        .font(.caption2).foregroundColor(.gray).lineLimit(1)
                }
                Spacer()
            }
            .padding([.horizontal, .top], 8)

            // Content Snippet - Shows original content
            Text(HTMLUtils.convertHTMLToPlainText(html: displayPost.content))
                .font(.footnote)
                .lineLimit(lineLimit)
                .padding(.horizontal, 8)

            // Media Thumbnail - Shows original media
            // CORRECTED LINE: Safely unwrap displayPost.mediaAttachments
            if let attachments = displayPost.mediaAttachments, let firstAttachment = attachments.first,
               let previewUrl = firstAttachment.previewURL ?? firstAttachment.url {
                Spacer() // Pushes AsyncImage to the bottom if content is short
                AsyncImage(url: previewUrl) { phase in
                    if let image = phase.image {
                        image.resizable().aspectRatio(contentMode: .fill).frame(height: 60).clipped()
                    } else if phase.error != nil {
                        Rectangle().fill(Color.gray.opacity(0.2)).frame(height: 60)
                            .overlay(Image(systemName: "photo").foregroundColor(.gray))
                    } else {
                        Rectangle().fill(Color.gray.opacity(0.1)).frame(height: 60) // Placeholder while loading
                    }
                }
            } else {
                 Spacer() // Ensure consistent height if no media
            }

            // Footer Counts - Shows original post's counts
            HStack {
                 Spacer()
                 Image(systemName: "heart").font(.caption2).foregroundColor(.gray)
                 Text("\(displayPost.favouritesCount)").font(.caption2).foregroundColor(.gray)
                 Image(systemName: "arrow.2.squarepath").font(.caption2).foregroundColor(.gray).padding(.leading, 5)
                 Text("\(displayPost.reblogsCount)").font(.caption2).foregroundColor(.gray)
            }
            .padding([.horizontal, .bottom], 8)
        }
        .frame(width: 200, height: 170) // Fixed height for consistency
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
    // Removed viewModel, as it's not directly used for actions here
    // @ObservedObject var viewModel: TimelineViewModel

    var body: some View {
        if isLoadingMore {
            HStack { Spacer(); ProgressView("Loading more..."); Spacer() }.padding()
        } else {
            Spacer().frame(height: 40)
        }
    }
}


// MARK: - Main View: TimelineContentView

struct TimelineContentView: View {
    @ObservedObject var viewModel: TimelineViewModel

    @State private var isShowingFullScreenImage = false
    @State private var selectedImageURL: URL?
    
    // State for replies in the comment sheet
    @State private var sheetReplies: [Post]? = nil
    @State private var sheetIsLoadingReplies: Bool = false

    private let logger = Logger(subsystem: "titan.mustard.app.ao", category: "TimelineContentView")

    var body: some View {
        VStack(spacing: 0) {
            Picker("Filter", selection: $viewModel.selectedFilter) {
                ForEach(TimelineViewModel.TimelineFilter.allCases) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            .padding(.bottom, 8)

            ScrollView {
                VStack(spacing: 16) {
                    topPostsSection
                        .padding(.top, 10)

                    if !viewModel.posts.isEmpty {
                        Divider().padding(.horizontal)
                    }
                    timelineSection
                }
            }
            .task { // Replaces onAppear for async work tied to view lifecycle
                if viewModel.posts.isEmpty && !viewModel.isLoading {
                    await viewModel.initializeTimelineData()
                }
            }
        }
        .refreshable {
            await viewModel.refreshTimeline()
        }
        .sheet(isPresented: $isShowingFullScreenImage) {
            if let imageURL = selectedImageURL {
                FullScreenImageView(imageURL: imageURL, isPresented: $isShowingFullScreenImage)
            }
        }
        .sheet(isPresented: $viewModel.showingCommentSheet) {
            if let postForSheet = viewModel.selectedPostForComments {
                let targetPostForContext = postForSheet.reblog ?? postForSheet
                
                NavigationView {
                    // Assuming ExpandedCommentsSection is defined in PostView.swift or PostDetailView.swift
                    ExpandedCommentsSection(
                        post: targetPostForContext,
                        isExpanded: .constant(true),
                        commentText: $viewModel.commentText,
                        viewModel: viewModel,
                        repliesToDisplay: sheetReplies,
                        isLoadingReplies: $sheetIsLoadingReplies,
                        currentDetailPost: targetPostForContext // <<< FIXED: Added missing argument
                    )
                    .navigationTitle("Reply to @\(targetPostForContext.account?.acct ?? "user")")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Cancel") {
                                viewModel.showingCommentSheet = false
                                sheetReplies = nil // Reset sheet-specific state
                                sheetIsLoadingReplies = false
                            }
                        }
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Post") {
                                viewModel.comment(on: targetPostForContext, content: viewModel.commentText)
                                // Clearing commentText and potentially refreshing replies is handled in TimelineViewModel or PostDetailView's ExpandedCommentSection
                            }
                            .disabled(viewModel.commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                    .task(id: targetPostForContext.id) { // Load replies when the sheet appears or target post changes
                        sheetIsLoadingReplies = true
                        sheetReplies = nil // Clear old replies
                        if let context = await viewModel.fetchContext(for: targetPostForContext) {
                            sheetReplies = context.descendants
                        } else {
                            sheetReplies = [] // Default to empty on error
                        }
                        sheetIsLoadingReplies = false
                    }
                }
                .onDisappear { // Ensure state is reset when the sheet is dismissed
                    sheetReplies = nil
                    sheetIsLoadingReplies = false
                }
            }
        }
        .navigationDestination(for: User.self) { user in
             ProfileView(user: user)
        }
        .navigationDestination(for: Post.self) { post in
             PostDetailView(post: post, viewModel: viewModel, showDetail: .constant(true))
        }
        .alert(item: $viewModel.alertError) { error in
             Alert(title: Text("Error"), message: Text(error.message), dismissButton: .default(Text("OK")))
         }
         .overlay {
             if viewModel.isLoading && viewModel.posts.isEmpty {
                 ProgressView("Loading \(viewModel.selectedFilter.rawValue)...")
                     .padding()
                     .background(.thinMaterial)
                     .cornerRadius(10)
                     .transition(.opacity)
             }
         }
    }

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
                            NavigationLink(value: post.reblog ?? post) {
                                 TrendingPostCardView(post: post)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                    .scrollTargetLayout() // For newer iOS if targeting page scrolling behavior
                }
                .frame(height: 180) // Ensure consistent height
            }
            .padding(.bottom, 10)
        } else if viewModel.isLoading && viewModel.selectedFilter != .trending { // Show placeholder only if not on trending tab already
             // Placeholder for loading state of top posts if needed
             HStack { Spacer(); ProgressView(); Spacer() }
             .frame(height: 180)
             .padding(.bottom, 10)
        }
    }

    private var timelineSection: some View {
        LazyVStack(spacing: 0) { // Use LazyVStack for performance
            if viewModel.posts.isEmpty && !viewModel.isLoading {
                 Text(viewModel.selectedFilter == .latest ? "Your timeline is empty." : "No posts found for \(viewModel.selectedFilter.rawValue).")
                    .foregroundColor(.gray)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                ForEach(viewModel.posts) { post in
                    NavigationLink(value: post.reblog ?? post) { // Navigate to the content post
                         PostView(
                             post: post, // Pass the wrapper post (which might be a reblog)
                             viewModel: viewModel,
                             viewProfileAction: { user in
                                 viewModel.navigateToProfile(user)
                             },
                             interestScore: 0.0 // Replace with actual score if available
                         )
                         // Removed .onImageTap as it's handled within PostView/MediaAttachmentView
                     }
                     .buttonStyle(.plain) // Remove default button styling for the link

                    CustomDivider().padding(.horizontal) // Visual separator

                    // Pagination trigger
                    if post.id == viewModel.posts.last?.id && !viewModel.isFetchingMore && (viewModel.selectedFilter == .latest || viewModel.selectedFilter == .recommended) {
                         PostFooterView(isLoadingMore: viewModel.isFetchingMore) // Shows loading or spacer
                             .padding(.vertical)
                             .onAppear {
                                 logger.debug("Last item appeared for filter \(viewModel.selectedFilter.rawValue), fetching more.")
                                 Task {
                                     await viewModel.fetchMoreTimeline()
                                 }
                             }
                     }
                }

                // Show a loading indicator at the bottom if more posts are being fetched
                 if viewModel.isFetchingMore && (viewModel.selectedFilter == .latest || viewModel.selectedFilter == .recommended) {
                     ProgressView().padding(.vertical).frame(maxWidth: .infinity)
                 }
            }
        }
    }
}

// Ensure supporting views like AvatarView, FullScreenImageView, CustomDivider, HTMLUtils,
// and the Post/User/Account models are correctly defined elsewhere.
// The ExpandedCommentsSection definition is assumed to be in PostDetailView.swift
// or another accessible location.
