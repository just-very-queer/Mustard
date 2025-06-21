// Mustard/Views/MainAppView.swift
import SwiftUI

struct MainAppView: View {
    @State private var isPresentingComposer = false

    var body: some View {
        TabView {
            // Tab 1: Timeline with Floating Action Button
            timelineTab()
                .tabItem {
                    Label("Timeline", systemImage: "list.dash")
                }

            // Example Tab 2: Placeholder for other content
            Text("Search Screen")
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
        }
        .sheet(isPresented: $isPresentingComposer) {
            ComposerView() // Present the ComposerView as a sheet
        }
    }

    @ViewBuilder
    private func timelineTab() -> some View {
        ZStack {
            // Placeholder for actual timeline content
            List {
                ForEach(0..<50) { index in
                    Text("Post item \(index)")
                        .padding(.vertical, 8)
                }
            }
            // Apply .tabViewBottomAccessory if needed for specific layout adjustments with TabView
            // .tabViewBottomAccessory { Color.clear.frame(height: 0) } // Example, may not be needed

            // Floating Action Button
            VStack {
                Spacer() // Pushes button to the bottom
                HStack {
                    Spacer() // Pushes button to the right
                    Button {
                        isPresentingComposer = true
                    } label: {
                        Image(systemName: "plus")
                            .resizable()
                            .frame(width: 24, height: 24)
                            .padding()
                            .foregroundColor(.white)
                            .background(Color.blue) // Example background
                            .clipShape(Circle())
                            .shadow(radius: 5)
                            // Apply the Liquid Glass effect
                            .glassEffect() // Assuming this modifier from iOS 26
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 10) // Adjust bottom padding as needed
                }
            }
        }
        // To ensure the list scrolls under the tab bar, no specific modifier is usually needed
        // as long as the List is not constrained by a frame that's too small.
        // The .tabBarMinimizeBehavior can be used on the TabView if needed,
        // but for simple scroll-under, it's often automatic.
        // Example: .tabBarMinimizeBehavior(.automatic) on TabView
    }
}

struct MainAppView_Previews: PreviewProvider {
    static var previews: some View {
        MainAppView()
    }
}
