//
//  PostDetailView.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 18/02/25.
//

import Foundation
import SwiftUI

struct PostDetailView: View {
    let post: Post
    @ObservedObject var viewModel: TimelineViewModel
    @Binding var showDetail: Bool
    
    // Added state to pass as bindings to ExpandedCommentsSection.
    @State private var isCommentsExpanded: Bool = true
    @State private var commentText: String = ""
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView {
                VStack {
                    PostRow(post: post, viewModel: viewModel)
                    ExpandedCommentsSection(
                        post: post,
                        isExpanded: $isCommentsExpanded,
                        commentText: $commentText,
                        viewModel: viewModel
                    )
                }
            }
            
            Button {
                withAnimation { showDetail = false }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundColor(.gray)
                    .padding()
            }
        }
        .background(Color(.systemBackground))
        .edgesIgnoringSafeArea(.all)
    }
}

