import SwiftUI

@main
struct MustardVisionApp: App {
    var body: some Scene {
        // Using a WindowGroup for the main content.
        // If the spatial feed is the primary experience, it can be hosted here.
        // Alternatively, a simple window could launch a volumetric experience.
        WindowGroup(id: "mainFeedWindow") { // Changed ID for clarity
            SpatialFeedView() // This will be our main content view for the prototype
        }
        // For a volumetric window directly, the WindowGroup itself can be styled.
        // If SpatialFeedView is designed to be presented in a volume,
        // you might use a default window that then opens a volume.
        // For this prototype, let's make the main window content our spatial feed.
        // If a distinct Volume window is preferred from the start:
        /*
        WindowGroup(id: "spatialFeedVolume") {
            SpatialFeedView()
        }
        .windowStyle(.volumetric)
        // Set a default size for the volumetric window if needed, e.g.,
        // .defaultSize(width: 0.8, height: 0.8, depth: 0.8, unit: .meters)
        // For this prototype, starting with a standard WindowGroup and letting SpatialFeedView
        // define its spatial characteristics within that window is also common.
        // Let's assume SpatialFeedView is designed to be the content of a standard,
        // potentially resizable, window that might contain 3D elements.
        // If the app should *only* be a volume, then the .volumetric style is key.
        // Given the prompt's example, it seems a WindowGroup containing the feed is fine,
        // and the "spatial" aspect comes from the content's 3D layout.
        */
    }
}
