//
//  Server.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 14/09/24.
//

import Foundation

struct Server: Identifiable {
    let id = UUID()
    let name: String
    let url: URL
    let description: String
}
