//
//  HashtagAnalyticsView.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 18/02/25.
//  (REVISED & FIXED)

import SwiftUI
import Charts

struct HashtagAnalyticsView: View {
    let hashtag: String
    let history: [TagHistory]
    @State private var selectedTimeRange: TimeRange = .day
    @Binding var showHashtagAnalytics: Bool

    @State private var sortOrder: SortOrder = .latest
    @State private var posts: [Post] = []
    @State private var isLoading = false
    @State private var error: Error?
    @EnvironmentObject var timelineViewModel: TimelineViewModel

    enum SortOrder: String, Identifiable, CaseIterable {
        case latest = "Latest"
        case topLiked = "Top Liked"
        var id: String { rawValue }
    }

    var sortedPosts: [Post] {
        switch sortOrder {
        case .latest:
            return posts
        case .topLiked:
            return posts.sorted { $0.favouritesCount > $1.favouritesCount }
        }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Analytics for #\(hashtag)")
                        .font(.largeTitle).bold()
                        .padding([.top, .horizontal])

                    timeRangePicker
                    usageTrendSection
                    sortSegment
                    postsSection
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showHashtagAnalytics = false
                    }
                }
            }
            .alert(isPresented: .constant(error != nil), content: {
                Alert(title: Text("Error"), message: Text(error?.localizedDescription ?? ""), dismissButton: .default(Text("OK")))
            })
            .onAppear {
                fetchPosts(for: hashtag)
            }
        }
    }

    private var timeRangePicker: some View {
        Picker("Time Range", selection: $selectedTimeRange) {
            ForEach(TimeRange.allCases) { range in
                Text(range.rawValue).tag(range)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding(.horizontal)
        .onChange(of: selectedTimeRange) {
            fetchPosts(for: hashtag)
        }
    }

    private var usageTrendSection: some View {
        VStack(alignment: .leading) {
            Text("Usage Trend (\(selectedTimeRange.rawValue))")
                .font(.title2).bold()
                .padding(.horizontal)
            HashtagChartView(history: filteredHistory(for: selectedTimeRange))
                .padding(.bottom, 10)
        }
    }

    private var sortSegment: some View {
        HStack {
            Text(sortOrder == .latest ? "Latest Posts" : "Top Liked Posts")
                .font(.title2).bold()
            Spacer()
            Menu {
                Picker("Sort By", selection: $sortOrder) {
                    ForEach(SortOrder.allCases) { order in
                        Text(order.rawValue).tag(order)
                    }
                }
            } label: {
                Label("Sort", systemImage: "arrow.up.arrow.down")
                    .font(.subheadline)
            }
        }
        .padding(.horizontal)
    }

    private var postsSection: some View {
        Group {
            if isLoading {
                ProgressView("Loading Posts...")
            } else if posts.isEmpty {
                Text("No posts found for #\(hashtag) in the last \(selectedTimeRange.rawValue).")
                    .foregroundColor(.gray)
            } else {
                HashtagPostsView(posts: sortedPosts)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .environmentObject(timelineViewModel)
    }

    private func filteredHistory(for range: TimeRange) -> [TagHistory] {
        let now = Date()
        let calendar = Calendar.current
        let startDate: Date
        switch range {
        case .day: startDate = calendar.date(byAdding: .day, value: -1, to: now)!
        case .week: startDate = calendar.date(byAdding: .day, value: -7, to: now)!
        case .month: startDate = calendar.date(byAdding: .month, value: -1, to: now)!
        case .year: startDate = calendar.date(byAdding: .year, value: -1, to: now)!
        }
        let df = DateFormatter(); df.dateFormat = "yyyyMMdd"; df.timeZone = TimeZone(secondsFromGMT: 0)
        return history
            .compactMap { item -> TagHistory? in
                guard let date = df.date(from: item.day), let uses = Int(item.uses), date >= startDate else { return nil }
                return TagHistory(day: df.string(from: date), uses: String(uses), accounts: "")
            }
    }

    private func fetchPosts(for hashtag: String) {
        Task {
            isLoading = true
            do {
                let searchService = SearchService(mastodonAPIService: MastodonAPIService.shared)
                let fetchedPosts = try await searchService.fetchHashtagPosts(hashtag: hashtag)

                let now = Date()
                let calendar = Calendar.current
                var startDate: Date

                switch selectedTimeRange {
                case .day: startDate = calendar.date(byAdding: .day, value: -1, to: now)!
                case .week: startDate = calendar.date(byAdding: .day, value: -7, to: now)!
                case .month: startDate = calendar.date(byAdding: .month, value: -1, to: now)!
                case .year: startDate = calendar.date(byAdding: .year, value: -1, to: now)!
                }

                self.posts = fetchedPosts.filter { post in
                    post.createdAt >= startDate
                 }
            } catch {
                self.error = error
            }
            isLoading = false
        }
    }
}

struct HashtagChartView: View {
    let history: [TagHistory]

    private var chartData: [(Date, Int)] {
        history.compactMap { item in
            guard let date = formattedDate(from: item.day), let uses = Int(item.uses) else { return nil }
            return (date, uses)
        }
        .sorted { $0.0 < $1.0 }
    }

    var body: some View {
        Chart {
            ForEach(chartData, id: \.0) { date, uses in
                AreaMark(x: .value("Date", date), y: .value("Uses", uses))
                LineMark(x: .value("Date", date), y: .value("Uses", uses))
            }
        }
        .frame(height: 200)
        .padding(.horizontal)
        .chartXAxis { AxisMarks(values: .stride(by: .day)) }
        .chartYAxis { AxisMarks(position: .leading) }
        .chartYScale(domain: 0...(max(10, (chartData.map { $0.1 }.max() ?? 0) * 12 / 10)))
    }

    private func formattedDate(from str: String) -> Date? {
        let df = DateFormatter(); df.dateFormat = "yyyyMMdd"; df.timeZone = TimeZone(secondsFromGMT: 0)
        return df.date(from: str)
    }
}

struct HashtagPostsView: View {
    let posts: [Post]
    @EnvironmentObject var timelineViewModel: TimelineViewModel

    var body: some View {
        LazyVStack(spacing: 0) {
            ForEach(posts) { post in
                PostView(
                    post: post,
                    viewProfileAction: { user in
                        timelineViewModel.navigateToProfile(user)
                    },
                    interestScore: 0.0 // FIX: Added missing interestScore parameter with a default value
                )
                Divider().padding(.horizontal)
            }
        }
    }
}
