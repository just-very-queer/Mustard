//  BasicComponents.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 21/02/25.
//

import SwiftUI

// MARK: - Basic Components
struct AvatarView: View {
    let url: URL?
    let size: CGFloat

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .empty:
                ProgressView()
                    .frame(width: size, height: size)
            case .success(let image):
                image.resizable()
                    .scaledToFill()
                    .clipShape(Circle())
            case .failure:
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .scaledToFill()
                    .foregroundColor(.gray)
            @unknown default:
                EmptyView()
            }
        }
        .frame(width: size, height: size)
        .background(Circle().fill(Color.gray.opacity(0.3)))
        .clipShape(Circle())
    }
}

struct HeaderView: View {
    let headerURL: URL?

    var body: some View {
        AsyncImage(url: headerURL) { phase in
            switch phase {
            case .empty:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: 200)
            case .success(let image):
                image.resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: 200)
            case .failure:
                Color.gray
                    .frame(maxWidth: .infinity, maxHeight: 200)
            @unknown default:
                EmptyView()
            }
        }
    }
}

