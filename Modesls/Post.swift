//
//  Post.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 14/09/24.
//

import Foundation
import SwiftData

@Model
class Post: Identifiable {
    @Attribute(.unique) var id: String
    var content: String
    var createdAt: Date
    var account: Account
    var mediaAttachments: [MediaAttachment]
    var isFavourited: Bool
    var isReblogged: Bool
    var reblogsCount: Int
    var favouritesCount: Int
    var repliesCount: Int

    init(
        id: String,
        content: String,
        createdAt: Date,
        account: Account,
        mediaAttachments: [MediaAttachment],
        isFavourited: Bool,
        isReblogged: Bool,
        reblogsCount: Int,
        favouritesCount: Int,
        repliesCount: Int
    ) {
        self.id = id
        self.content = content
        self.createdAt = createdAt
        self.account = account
        self.mediaAttachments = mediaAttachments
        self.isFavourited = isFavourited
        self.isReblogged = isReblogged
        self.reblogsCount = reblogsCount
        self.favouritesCount = favouritesCount
        self.repliesCount = repliesCount
    }
}

