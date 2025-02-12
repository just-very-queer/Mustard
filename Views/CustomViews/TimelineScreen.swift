//
//  File.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 07/02/25.
//

import SwiftUI

/// This replaces the accidental use of SwiftUI’s built-in TimelineView
struct TimelineScreen: View {
    @ObservedObject var viewModel: TimelineViewModel

    var body: some View {
        TimelineContentView(
            posts: viewModel.posts,
            isLoading: viewModel.isLoading,
            viewModel: viewModel
        )
        .onAppear {
            // Initialize/fetch data once the view appears
            Task {
                await viewModel.initializeData()
            }
        }
    }
}

