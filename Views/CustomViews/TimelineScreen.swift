//
//  TimelineScreen.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 07/02/25.
// (FIXED: Always fetch data on appear)

import SwiftUI

struct TimelineScreen: View {
    // Use @StateObject if TimelineScreen *owns* the ViewModel instance
    // Use @ObservedObject if the ViewModel instance is created and passed *by a parent* view (like MainAppView)
    @ObservedObject var viewModel: TimelineViewModel // Assuming ViewModel is passed from MainAppView

    var body: some View {
        TimelineContentView(
            viewModel: viewModel // Pass the single ViewModel instance
        )
        .onAppear {
            Task {
                await viewModel.initializeTimelineData()
            }
        }
        // Modifiers like .navigationTitle should ideally be on the NavigationStack container
        // that holds TimelineScreen (e.g., in MainAppView or HomeView if used).
        // .navigationTitle("Timeline") // Move this modifier higher up if possible
    }
}
