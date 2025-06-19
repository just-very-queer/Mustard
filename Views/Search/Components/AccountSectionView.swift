import SwiftUI

struct AccountSectionView: View {
    let accounts: [Account]
    // Assuming ProfileView is available and User is Navigable via .navigationDestination(for: User.self)
    // AccountRow is defined in Utilities/AccountRow.swift
    // Account.toUser() is defined in Models/Account.swift

    var body: some View {
        Section(header: Text("Accounts").font(.headline)) {
            ForEach(accounts) { account in
                NavigationLink(value: account.toUser()) {
                    AccountRow(account: account)
                }
            }
        }
    }
}
