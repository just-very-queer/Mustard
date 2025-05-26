import Foundation

// Define the protocol based on methods used by RecommendedTimelineViewModel
protocol TimelineServiceProtocol {
    func WorkspaceHomeTimeline(maxId: String?, minId: String?, limit: Int?) async throws -> [Post]
    // Add other methods from TimelineService if they are needed by other ViewModels
    // that might adopt this protocol for testability.
    // For now, only adding what's immediately required.
}
