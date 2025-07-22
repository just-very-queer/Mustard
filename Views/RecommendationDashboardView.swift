import SwiftUI

struct RecommendationDashboardView: View {
    @State private var userAffinities: [UserAffinity] = []
    @State private var hashtagAffinities: [HashtagAffinity] = []
    @State private var interactionSummary: [InteractionType: Int]? = nil
    @State private var summaryError: Error? = nil

    var body: some View {
        NavigationView {
            List {
                Section("Recent Interactions Summary (Last 90 Days)") {
                    if let summary = interactionSummary {
                        if summary.isEmpty {
                            Text("No recent interactions found.")
                        } else {
                            ForEach(summary.sorted(by: { $0.key.rawValue < $1.key.rawValue }), id: \.key) { key, value in
                                HStack {
                                    Text("\(key.rawValue.capitalized):")
                                    Spacer()
                                    Text("\(value)")
                                }
                            }
                        }
                    } else if summaryError != nil {
                        Text("Error loading summary: \(summaryError!.localizedDescription)")
                            .foregroundColor(.red)
                    } else {
                        ProgressView("Loading summary...")
                    }
                }

                Section("User Affinities") {
                    if userAffinities.isEmpty {
                        Text("No user affinities found. Interact with posts to build them.")
                    }
                    ForEach(userAffinities) { affinity in
                        HStack {
                            // Placeholder for avatar - assuming UserAffinity has an identifiable ID and maybe a display name
                            // Actual avatar loading would require more info on Account model and image handling
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .frame(width: 40, height: 40)
                                .clipShape(Circle())

                            VStack(alignment: .leading) {
                                Text(affinity.authorAccountID) // Assuming this is a displayable ID or name
                                    .font(.headline)
                                Text("Score: \(affinity.score, specifier: "%.2f")")
                                    .font(.subheadline)
                                Text("Interactions: \(affinity.interactionCount)")
                                    .font(.caption)
                            }

                            Spacer()

                            Button {
                                logManualAffinityAdjustment(type: .user, id: affinity.authorAccountID, boost: 1.0)
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.green)
                            }
                            .buttonStyle(BorderlessButtonStyle()) // Use BorderlessButtonStyle for buttons in a List row

                            Button {
                                logManualAffinityAdjustment(type: .user, id: affinity.authorAccountID, boost: -1.0) // Negative boost for dislike/decrease
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(BorderlessButtonStyle())
                        }
                    }
                }

                Section("Hashtag Affinities") {
                    if hashtagAffinities.isEmpty {
                        Text("No hashtag affinities found. Interact with posts to build them.")
                    }
                    ForEach(hashtagAffinities) { affinity in
                        HStack {
                            VStack(alignment: .leading) {
                                Text("#\(affinity.tag)")
                                    .font(.headline)
                                Text("Score: \(affinity.score, specifier: "%.2f")")
                                    .font(.subheadline)
                                Text("Interactions: \(affinity.interactionCount)")
                                    .font(.caption)
                            }

                            Spacer()

                            Button {
                                logManualAffinityAdjustment(type: .hashtag, id: affinity.tag, boost: 1.0)
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.green)
                            }
                            .buttonStyle(BorderlessButtonStyle())

                            Button {
                                logManualAffinityAdjustment(type: .hashtag, id: affinity.tag, boost: -1.0) // Negative boost
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(BorderlessButtonStyle())
                        }
                    }
                }
            }
            .navigationTitle("Recommendation Dashboard")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task {
                            await fetchAffinities()
                            do {
                                let recommendationService = RecommendationService.shared
                                self.interactionSummary = try await recommendationService.getInteractionSummary(forDays: 90)
                                self.summaryError = nil
                            } catch {
                                print("Error fetching interaction summary on refresh: \(error)")
                                self.summaryError = error
                            }
                        }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }
            }
            .task { // Replaces onAppear for async tasks
                await fetchAffinities()
                do {
                    let recommendationService = RecommendationService.shared
                    self.interactionSummary = try await recommendationService.getInteractionSummary(forDays: 90)
                    self.summaryError = nil
                } catch {
                    print("Error fetching interaction summary: \(error)")
                    self.summaryError = error
                    // self.interactionSummary = [:] // Example: set to empty on error to stop loading indicator
                }
            }
        }
    }

    func fetchAffinities() async {
        let recommendationService = RecommendationService.shared
        guard let context = recommendationService.modelContext else {
            print("Error: RecommendationService ModelContext not configured.")
            return
        }

        do {
            let userDescriptor = FetchDescriptor<UserAffinity>(sortBy: [SortDescriptor(\.score, order: .reverse)])
            self.userAffinities = try context.fetch(userDescriptor)

            let hashtagDescriptor = FetchDescriptor<HashtagAffinity>(sortBy: [SortDescriptor(\.score, order: .reverse)])
            self.hashtagAffinities = try context.fetch(hashtagDescriptor)
        } catch {
            print("Error fetching affinities: \(error.localizedDescription)")
        }
    }

    func logManualAffinityAdjustment(type: AffinityType, id: String, boost: Double) {
        let recommendationService = RecommendationService.shared
        let interactionType: InteractionType
        var authorAccountID: String? = nil
        var tags: [String]? = nil

        switch type {
        case .user:
            interactionType = .manualUserAffinity
            authorAccountID = id
        case .hashtag:
            interactionType = .manualHashtagAffinity
            tags = [id]
        }

        recommendationService.logInteraction(
            actionType: interactionType,
            authorAccountID: authorAccountID,
            tags: tags
        )

        Task {
            await recommendationService.calculateAffinities()
            await fetchAffinities()
        }
    }
}

// Preview (Optional - requires UserAffinity and HashtagAffinity to be mockable or sample data)
struct RecommendationDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        // Mock UserAffinity and HashtagAffinity for preview if needed
        // For now, just return the view with an empty ViewModel state
        RecommendationDashboardView()
            .environmentObject(RecommendationDashboardViewModel()) // Example of injecting for preview
    }
}

// Assuming UserAffinity and HashtagAffinity conform to Identifiable
// If not, you might need to use ForEach(viewModel.userAffinities, id: \.id) if they have a unique 'id' property
// For this example, I'm assuming they conform to Identifiable (e.g., via @Model)
// UserAffinity.swift (Simplified for context, assuming it's a SwiftData @Model)
/*
 @Model
 final class UserAffinity: Identifiable {
     @Attribute(.unique) var authorAccountID: String
     var score: Double
     var lastUpdated: Date
     var interactionCount: Int
     // ... other properties and init

     init(authorAccountID: String, score: Double, lastUpdated: Date, interactionCount: Int) {
         self.authorAccountID = authorAccountID
         self.score = score
         self.lastUpdated = lastUpdated
         self.interactionCount = interactionCount
     }
 }
 */

// HashtagAffinity.swift (Simplified for context, assuming it's a SwiftData @Model)
/*
 @Model
 final class HashtagAffinity: Identifiable {
     @Attribute(.unique) var tag: String
     var score: Double
     var lastUpdated: Date
     var interactionCount: Int
     // ... other properties and init

     init(tag: String, score: Double, lastUpdated: Date, interactionCount: Int) {
         self.tag = tag
         self.score = score
         self.lastUpdated = lastUpdated
         self.interactionCount = interactionCount
     }
 }
 */
