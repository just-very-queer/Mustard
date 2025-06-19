import SwiftUI

// HTMLUtils might be needed if bio saving involves converting plain text back to HTML,
// or if the initial user.note is complex and needs pre-processing for TextEditor.
// For now, assuming HTMLUtils.convertHTMLToPlainText is accessible.
// If it's in a separate module 'Utilities', an import Utilities might be needed,
// but typically static utils are available if linked in the target.

struct EditProfileView: View {
    let user: User
    @EnvironmentObject var profileViewModel: ProfileViewModel
    @Environment(\.dismiss) var dismiss
    @State private var displayName: String
    @State private var bio: String

    // Environment for color scheme
    @Environment(\.colorScheme) var colorScheme

    init(user: User) {
        self.user = user
        _displayName = State(initialValue: user.display_name ?? "")
        // Assuming HTMLUtils is available here.
        // If HTMLUtils is in a framework/module, this file would need `import Utilities` (or similar)
        _bio = State(initialValue: HTMLUtils.convertHTMLToPlainText(html: user.note ?? ""))
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Profile Information")) {
                    TextField("Display Name", text: $displayName)
                    VStack(alignment: .leading) {
                        Text("Bio").font(.caption).foregroundColor(.gray)
                        TextEditor(text: $bio)
                            .frame(height: 150)
                            .border(colorScheme == .dark ? Color.gray.opacity(0.5) : Color.gray.opacity(0.2), width: 1) // Subtle border
                            .font(.custom("Verdana", size: UIFont.systemFontSize))
                    }
                }
                Section {
                    Button("Save Changes") {
                        Task {
                            await profileViewModel.updateProfile(for: user.id, updatedFields: [
                                "display_name": displayName,
                                "note": bio // Assuming the backend expects plain text or service handles conversion
                            ])
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { dismiss() } }
            }
        }
    }
}
