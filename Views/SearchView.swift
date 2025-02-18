//
//  SearchView.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 18/02/25.
//

import SwiftUI
import Charts

struct SearchView: View {
    @EnvironmentObject var timelineViewModel: TimelineViewModel
    @State private var searchText = ""
    @State private var searchResults: [Post] = []
    @State private var trendingHashtags: [Tag] = [] // Correct type
    @State private var hashtags: [String] = []
    @State private var selectedHashtag: String?
    @State private var showHashtagAnalytics = false
    @State private var selectedTimeRange: TimeRange = .day // Default time range

    // Enum for time range selection
    enum TimeRange: String, CaseIterable, Identifiable {
        case day = "1 Day"
        case week = "7 Days"
        case month = "1 Month"
        case year = "1 Year"
        var id: String { self.rawValue }
    }


    var body: some View {
        NavigationView {
            VStack {
                SearchBar(text: $searchText)
                    .padding()
                    .onChange(of: searchText) { _, newValue in
                        Task {
                            await search(query: newValue)
                        }
                    }

                Picker("Search Results", selection: $selectedHashtag) {
                    Text("Posts").tag(nil as String?)
                    Text("Trending Hashtags").tag("trendingHashtags" as String?)
                    ForEach(hashtags, id: \.self) { hashtag in
                        Text("#\(hashtag)").tag(hashtag as String?)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()

                List {
                    if selectedHashtag == "trendingHashtags" {
                        // Correct:  Iterate over trendingHashtags, which are Tags
                        ForEach(trendingHashtags, id: \.name) { tag in
                            Button(action: {
                                self.selectedHashtag = tag.name
                                self.showHashtagAnalytics = true
                            }) {
                                Text("#\(tag.name)")  // Display the tag name
                            }
                        }
                    } else if let hashtag = selectedHashtag {
                        // Display posts for the selected hashtag
                        ForEach(searchResults.filter { post in
                            if let tags = post.tags {
                                return tags.contains { $0.name.lowercased() == hashtag.lowercased() }
                            }
                            return false
                        }, id: \.id) { post in
                            PostRow(post: post)
                        }
                    } else {
                        ForEach(searchResults, id: \.id) { post in
                            PostRow(post: post)
                        }
                    }
                }
                .listStyle(.plain)
                .navigationTitle("Search")
            }
            .sheet(isPresented: $showHashtagAnalytics) {
                if let selectedHashtag = selectedHashtag {
                    // Pass the selected hashtag to the analytics view
                    HashtagAnalyticsView(hashtag: selectedHashtag, posts: searchResults, selectedTimeRange: $selectedTimeRange, showHashtagAnalytics: $showHashtagAnalytics)
                }
            }
        }
        .task {
            await loadTrendingHashtags()
        }
    }

   func search(query: String) async {
           searchResults = [] // Assign an empty array
           hashtags = [] // Assign an empty array

           if query.isEmpty {
               return
           }

           do {
               let posts = try await timelineViewModel.searchPosts(query: query)
               searchResults = posts

               // Extract hashtags from search results
               for post in posts {
                   if let tags = post.tags {
                       hashtags.append(contentsOf: tags.map { $0.name })
                   }
               }
               hashtags = Array(Set(hashtags)) // Remove duplicates
           } catch {
               print("Error searching posts: \(error)")
               // Handle error appropriately (e.g., show an alert)
           }
       }

    func loadTrendingHashtags() async {
        do {
            trendingHashtags = try await timelineViewModel.fetchTrendingHashtags() // Correct type
        } catch {
            print("Error loading trending hashtags: \(error)")
        }
    }
}

struct SearchBar: View {
    @Binding var text: String

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
            TextField("Search...", text: $text)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

struct PostRow: View {
    let post: Post

    var body: some View {
        HStack {
            AvatarView(url: post.account?.avatar, size: 40)
            VStack(alignment:.leading) {
                Text(post.account?.username ?? "")
                    .font(.headline)
                Text(post.content)
                    .font(.body)
            }
        }
    }
}
