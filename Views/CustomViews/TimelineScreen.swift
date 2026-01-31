//
//  TimelineScreen.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 07/02/25.
// (FIXED: Always fetch data on appear)

import SwiftUI

struct TimelineScreen: View {
    @State private var navigationPath = NavigationPath()
    @State private var selectedFilter: TimelineFilter = .recommended
    
    @Environment(TimelineProvider.self) private var timelineProvider

    var body: some View {
        NavigationStack(path: $navigationPath) {
            TimelineContentView(
                selectedFilter: $selectedFilter,
                navigationPath: $navigationPath
            )
            .navigationTitle("Timeline")
            .navigationDestination(for: User.self) { user in
                ProfileView(user: user)
            }
        }
        .onAppear {
            Task {
                await timelineProvider.initializeTimelineData(for: selectedFilter)
            }
        }
    }
}
