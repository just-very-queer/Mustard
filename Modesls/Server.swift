//
//  Server.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 30/12/24.
//

import Foundation

/// Represents a Mastodon server instance.
struct Server: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let url: URL
    let description: String
}

