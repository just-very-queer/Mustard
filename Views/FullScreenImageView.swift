//
//  FullScreenImageView.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 14/09/24.
//

import SwiftUI

struct FullScreenImageView: View {
    let imageURL: URL
    @Binding var isPresented: Bool

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black
                .edgesIgnoringSafeArea(.all)
            
            // AsyncImage to load the image
            AsyncImage(url: imageURL) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .transition(.opacity)
                case .failure:
                    Image(systemName: "photo")
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(.gray)
                        .padding()
                @unknown default:
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Close Button
            Button(action: {
                isPresented = false
            }) {
                Image(systemName: "xmark.circle.fill")
                    .resizable()
                    .frame(width: 30, height: 30)
                    .foregroundColor(.white)
                    .shadow(radius: 2)
            }
            .padding()
            .accessibilityLabel("Close Image")
        }
    }
}

struct FullScreenImageView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleURL = URL(string: "https://example.com/image.png")!
        FullScreenImageView(imageURL: sampleURL, isPresented: .constant(true))
    }
}
