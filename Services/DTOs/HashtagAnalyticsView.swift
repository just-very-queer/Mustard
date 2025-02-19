//
//  HashtagAnalyticsView.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 18/02/25.
//

import SwiftUI
import Charts

struct HashtagAnalyticsView: View {
    let hashtag: String
    let history: [TagHistory]
    @Binding var selectedTimeRange: SearchViewModel.TimeRange // Corrected
    @Binding var showHashtagAnalytics: Bool // Add this binding

    @State private var sortOrder: SortOrder = .latest

    enum SortOrder {
        case latest
        case topLiked //Not used for Chart, kept for future expansion to other view with list of posts
    }

    var body: some View {
        NavigationView {
            VStack {
                Text("Analytics for #\(hashtag)")
                    .font(.title)
                    .padding()

                Picker("Time Range", selection: $selectedTimeRange) {
                    ForEach(SearchViewModel.TimeRange.allCases) { range in // Corrected
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                .onChange(of: selectedTimeRange) { oldValue, newValue in //Listen to time range and update on change.  Important
                    //Could re-fetch data here if needed, based on the new time range
                }

                let (filteredHistory,maxUses) = filteredHistory(for: selectedTimeRange)


                Chart(filteredHistory, id: \.day) { item in
                        LineMark(
                            x: .value("Date", formattedDate(from: item.day)),
                            y: .value("Uses", Int(item.uses) ?? 0)
                        )
                        .foregroundStyle(Color.blue)
                        PointMark(
                            x: .value("Date", formattedDate(from: item.day)),
                            y: .value("Uses", Int(item.uses) ?? 0)
                        )
                        .foregroundStyle(Color.blue)

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
                .chartYScale(domain: 0...(maxUses + maxUses/5)) //Dynamic y Scale

            }
            .navigationTitle("Hashtag Analytics")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showHashtagAnalytics = false  //Correct: Modifying the binding
                    }
                }
            }
        }
    }



    func filteredHistory(for range: SearchViewModel.TimeRange) -> ([TagHistory], Int) { //Corrected
        let now = Date()
        let calendar = Calendar.current
        var startDate: Date
        var filteredData: [TagHistory] = []

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
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"  // Important for consistent comparison

        for item in history {
            guard let dayInt = Int(item.day),
                  let itemDate = dateFormatter.date(from: String(dayInt)) else {
                continue // Skip invalid data
            }
            if itemDate >= startDate {
                filteredData.append(item)
            }
        }
        let maxUses = filteredData.compactMap { Int($0.uses) }.max() ?? 0

        return (filteredData,maxUses)
    }


    func formattedDate(from timestampString: String) -> Date { //Corrected Return type
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd" //Match the API format
        return dateFormatter.date(from: timestampString) ?? Date() //Return a default date.

    }

    func timeAxisStride(for range: SearchViewModel.TimeRange) -> Calendar.Component { //Corrected
        switch range {
        case .day:       return .hour
        case .week:      return .day
        case .month:     return .day
        case .year:      return .month
        }
    }

    func timeAxisCount(for range: SearchViewModel.TimeRange) -> Int { //Corrected
        switch range {
        case .day:       return 6 // Show 6 hour intervals (24 / 6 = 4)
        case .week:      return 7 // Show 7 days
        case .month:     return 6  // Show roughly 6 intervals
        case .year:      return 12 //Show all 12 months
        }
    }

    func timeAxisFormat(for range: SearchViewModel.TimeRange) -> Date.FormatStyle { //Corrected
        switch range {
        case .day:       return .dateTime.hour()
        case .week:      return .dateTime.weekday() // Day of week name
        case .month:     return .dateTime.day()   // Day of the Month
        case .year:      return .dateTime.month()   // Month
        }
    }
}
