import SwiftUI

struct FollowersListView: View {
    let userId: String
    @EnvironmentObject var profileViewModel: ProfileViewModel
    @EnvironmentObject var timelineViewModel: TimelineViewModel // Added as ProfileView uses it, might be needed by destination
    @EnvironmentObject var authViewModel: AuthenticationViewModel // Added as ProfileView uses it
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            List(profileViewModel.followers, id: \.id) { follower in
                NavigationLink(destination: ProfileView(user: follower)) {
                    HStack {
                        AvatarView(url: URL(string: follower.avatar ?? ""), size: 40)
                        VStack(alignment: .leading) {
                            Text(follower.display_name ?? follower.username).font(.headline)
                            Text("@\(follower.acct)").font(.subheadline).foregroundColor(.gray)
                        }
                    }
                }
            }
            .navigationTitle("Followers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) { Button("Done") { dismiss() } }
            }
            .listStyle(.plain)
        }
    }
}
