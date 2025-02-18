//
//  HashtagAnalyticsView.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 18/02/25.
//

// HashtagAnalyticsView.swift
import SwiftUI
import Charts

struct HashtagAnalyticsView: View {
    let hashtag: String
    let posts: [Post]
    @Binding var selectedTimeRange: SearchView.TimeRange
    @Binding var showHashtagAnalytics: Bool // Add this binding

    @State private var sortOrder: SortOrder = .latest

    enum SortOrder {
        case latest
        case topLiked
    }

    var body: some View {
        NavigationView {
            VStack {
                Text("Analytics for #\(hashtag)")
                    .font(.title)
                    .padding()

                Picker("Time Range", selection: $selectedTimeRange) {
                    ForEach(SearchView.TimeRange.allCases) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()

                let filteredPosts = filteredPosts(for: selectedTimeRange)

                Chart {
                    ForEach(filteredPosts, id: \.id) { post in
                        LineMark(
                            x: .value("Date", post.createdAt),
                            y: .value("Likes", post.favouritesCount)
                        )
                        .foregroundStyle(Color.blue)
                        PointMark(
                            x: .value("Date", post.createdAt),
                            y: .value("Likes", post.favouritesCount)
                        )
                        .foregroundStyle(Color.blue)
                    }
                }
                .frame(height: 200)
                .padding()
                .chartXAxis {
                    AxisMarks(values: .stride(by: timeAxisStride(for: selectedTimeRange), count: timeAxisCount(for: selectedTimeRange))) { value in
                        AxisGridLine()
                        AxisTick()
                        if let date = value.as(Date.self) {
                            AxisValueLabel {
                                Text(date, format: timeAxisFormat(for: selectedTimeRange))
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        AxisTick()
                        if let count = value.as(Int.self) {
                            AxisValueLabel {
                                Text("\(count)")
                            }
                        }
                    }
                }

                List {
                    Section(header:
                                HStack {
                                    Text("Posts")
                                    Spacer()
                                    Picker("Sort Order", selection: $sortOrder) {
                                        Text("Latest").tag(SortOrder.latest)
                                        Text("Top Liked").tag(SortOrder.topLiked)
                                    }
                                    .pickerStyle(SegmentedPickerStyle())
                                }
                                .textCase(nil)
                            ) {
                        ForEach(sortedPosts(filteredPosts), id: \.id) { post in
                            PostRow(post: post)
                        }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Hashtag Analytics")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showHashtagAnalytics = false // Correct: Modifying the binding
                    }
                }
            }
        }
    }

    func sortedPosts(_ posts: [Post]) -> [Post] {
        switch sortOrder {
        case .latest:
            return posts.sorted { $0.createdAt > $1.createdAt }
        case .topLiked:
            return posts.sorted { $0.favouritesCount > $1.favouritesCount }
        }
    }

    func filteredPosts(for range: SearchView.TimeRange) -> [Post] {
        let now = Date()
        let calendar = Calendar.current
        let startDate: Date

        switch range {
        case .day:
            startDate = calendar.date(byAdding: .day, value: -1, to: now)!
        case .week:
            startDate = calendar.date(byAdding: .day, value: -7, to: now)!
        case .month:
            startDate = calendar.date(byAdding: .month, value: -1, to: now)!
        case .year:
            startDate = calendar.date(byAdding: .year, value: -1, to: now)!
        }

        return posts.filter { post in
            post.tags?.contains { $0.name.lowercased() == hashtag.lowercased() } ?? false &&
            post.createdAt >= startDate
        }
    }

    func timeAxisStride(for range: SearchView.TimeRange) -> Calendar.Component {
        switch range {
        case .day:         return .hour
        case .week:        return .day
        case .month:       return .day
        case .year:        return .month
        }
    }

    func timeAxisCount(for range: SearchView.TimeRange) -> Int {
        switch range {
        case .day:     return 6
        case .week:    return 7
        case .month:   return 6
        case .year:    return 12
        }
    }

    func timeAxisFormat(for range: SearchView.TimeRange) -> Date.FormatStyle {
        switch range {
        case .day:         return .dateTime.hour()
        case .week:        return .dateTime.weekday()
        case .month:       return .dateTime.day()
        case .year:        return .dateTime.month()
        }
    }
}
