import SwiftUI

struct HashtagSectionView: View {
    let hashtags: [Tag] // Assumes Tag model is Identifiable and has 'name'
    let onHashtagTap: (Tag) -> Void

    var body: some View {
        Section(header: Text("Hashtags").font(.headline)) {
            ForEach(hashtags) { hashtag in // Assumes Tag is Identifiable
                HStack {
                    Text("#\(hashtag.name)")
                        .foregroundColor(.blue)
                    Spacer()
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .foregroundColor(.gray)
                }
                .contentShape(Rectangle()) // Make the whole HStack tappable
                .onTapGesture { onHashtagTap(hashtag) }
            }
        }
    }
}
