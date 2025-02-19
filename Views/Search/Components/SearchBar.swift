//
//  SearchBar.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 18/02/25.
//

import Foundation
import SwiftUI

struct SearchBar: View {
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
            TextField("Search...", text: $text)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .focused(isFocused)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}
