//
//  UtilityComponents.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 21/02/25.
//

import SwiftUI

// MARK: - Utility Components

struct LoadingOverlay: View {
    let isLoading: Bool
    let message: String

    var body: some View {
        Group {
            if isLoading {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                ProgressView(message)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(10)
            }
        }
    }
}

struct LinkPreview: View {
    let url: URL
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "link.circle")
                Text(url.absoluteString).lineLimit(1).truncationMode(.middle)
            }
            .foregroundColor(.blue)
        }
    }
}
