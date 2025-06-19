import SwiftUI

struct TrendingHashtagsSectionView: View {
    let hashtags: [Tag] // Assuming Tag model from original file, Identifiable
    let onHashtagTap: (Tag) -> Void

    var body: some View {
        Section(header: Text("Trending Today").font(.headline)) {
            ForEach(hashtags) { hashtag in // Assumes Tag is Identifiable
                HStack {
                    Text("#\(hashtag.name)").foregroundColor(.blue)
                    Spacer()
                    // Assuming Tag.history is an optional array of some history object
                    // The original code checks `hashtag.history?.isEmpty == false`
                    if hashtag.history?.isEmpty == false {
                        Image(systemName: "chart.line.uptrend.xyaxis").foregroundColor(.gray)
                    }
                }
                .contentShape(Rectangle()) // Make the whole HStack tappable
                .onTapGesture { onHashtagTap(hashtag) }
            }
        }
    }
}
