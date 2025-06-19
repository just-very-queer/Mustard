import SwiftUI

struct FollowingListView: View {
    let userId: String
    @EnvironmentObject var profileViewModel: ProfileViewModel
    @EnvironmentObject var timelineViewModel: TimelineViewModel // Added as ProfileView uses it
    @EnvironmentObject var authViewModel: AuthenticationViewModel // Added as ProfileView uses it
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
             List(profileViewModel.following, id: \.id) { followingUser in
                 NavigationLink(destination: ProfileView(user: followingUser)) {
                     HStack {
                         AvatarView(url: URL(string: followingUser.avatar ?? ""), size: 40)
                         VStack(alignment: .leading) {
                             Text(followingUser.display_name ?? followingUser.username).font(.headline)
                             Text("@\(followingUser.acct)").font(.subheadline).foregroundColor(.gray)
                         }
                     }
                 }
             }
            .navigationTitle("Following")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) { Button("Done") { dismiss() } }
            }
            .listStyle(.plain)
        }
    }
}
