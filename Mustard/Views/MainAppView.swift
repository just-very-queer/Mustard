// Mustard/Views/MainAppView.swift
import SwiftUI

struct MainAppView: View {
    @State private var isPresentingComposer = false

    var body: some View {
        NavigationView {
            VStack {
                Text("Main Application View Content")
                    .font(.largeTitle)
                    .padding()

                // Placeholder for actual content like a timeline
                Spacer()
            }
            .navigationTitle("Mustard")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isPresentingComposer = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2) // Adjust size as needed
                    }
                }
            }
            .sheet(isPresented: $isPresentingComposer) {
                ComposerView() // Present the ComposerView as a sheet
            }
        }
    }
}

struct MainAppView_Previews: PreviewProvider {
    static var previews: some View {
        MainAppView()
    }
}
