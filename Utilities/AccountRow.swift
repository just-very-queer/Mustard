//
//  AccountRow.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 21/02/25.
//

import SwiftUI

struct AccountRow: View {
    let account: Account

    var body: some View {
        HStack(spacing: 15) {
            AvatarView(url: account.avatar, size: 50)
            VStack(alignment: .leading) {
                Text(account.display_name ?? account.username)
                    .font(.headline)
                Text("@\(account.username)")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            Spacer()
        }
        .padding(.vertical, 5)
    }
}
