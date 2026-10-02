//
//  TimelineScreen.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 07/02/25.
//

import SwiftUI

struct TimelineScreen: View {
    @State private var navigationPath = NavigationPath()
    @State private var selectedFilter: TimelineFilter = .recommended
    
    @Environment(TimelineService.self) private var timelineService

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
        .task {
            if timelineService.posts.isEmpty {
                await timelineService.initializeTimelineData(for: selectedFilter)
            }
        }
    }
}
