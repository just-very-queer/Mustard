//
//  MediaAttachment.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 14/09/24.
//

import Foundation
import SwiftData

@Model
class MediaAttachment: Identifiable {
    @Attribute(.unique) var id: String
    var type: String
    var url: URL
    var previewUrl: URL?

    init(id: String, type: String, url: URL, previewUrl: URL? = nil) {
        self.id = id
        self.type = type
        self.url = url
        self.previewUrl = previewUrl
    }
}

