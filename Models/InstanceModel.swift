//
//  InstanceModel.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 14/02/25.
//

import Foundation
import SwiftData

@Model
class InstanceModel: Identifiable {
    @Attribute(.unique) var id: String
    var name: String
    var addedAt: String?
    var updatedAt: String?
    var checkedAt: String?
    var uptime: Int?
    var up: Bool?
    var dead: Bool?
    var version: String?
    var ipv6: Bool?
    var httpsScore: Int?
    var httpsRank: String?
    var obsScore: Int?
    var obsRank: String?
    var users: String?
    var statuses: String?
    var connections: String?
    var openRegistrations: Bool?
    var info: InstanceInformationModel?  // Nested Model
    var thumbnail: String?
    var thumbnailProxy: String?
    var activeUsers: Int?
    var email: String?
    var admin: String?
    var instanceDescription: String?

    init(id: String, name: String, addedAt: String? = nil, updatedAt: String? = nil, checkedAt: String? = nil, uptime: Int? = nil, up: Bool? = nil, dead: Bool? = nil, version: String? = nil, ipv6: Bool? = nil, httpsScore: Int? = nil, httpsRank: String? = nil, obsScore: Int? = nil, obsRank: String? = nil, users: String? = nil, statuses: String? = nil, connections: String? = nil, openRegistrations: Bool? = nil, info: InstanceInformationModel? = nil, thumbnail: String? = nil, thumbnailProxy: String? = nil, activeUsers: Int? = nil, email: String? = nil, admin: String? = nil, instanceDescription: String? = nil) {
        self.id = id
        self.name = name
        self.addedAt = addedAt
        self.updatedAt = updatedAt
        self.checkedAt = checkedAt
        self.uptime = uptime
        self.up = up
        self.dead = dead
        self.version = version
        self.ipv6 = ipv6
        self.httpsScore = httpsScore
        self.httpsRank = httpsRank
        self.obsScore = obsScore
        self.obsRank = obsRank
        self.users = users
        self.statuses = statuses
        self.connections = connections
        self.openRegistrations = openRegistrations
        self.info = info
        self.thumbnail = thumbnail
        self.thumbnailProxy = thumbnailProxy
        self.activeUsers = activeUsers
        self.email = email
        self.admin = admin
        self.instanceDescription = instanceDescription
    }

    // Convenience initializer to create an InstanceModel from an Instance
      convenience init(from instance: Instance) {
          self.init(
              id: instance.id,
              name: instance.name,
              addedAt: instance.addedAt,
              updatedAt: instance.updatedAt,
              checkedAt: instance.checkedAt,
              uptime: instance.uptime,
              up: instance.up,
              dead: instance.dead,
              version: instance.version,
              ipv6: instance.ipv6,
              httpsScore: instance.httpsScore,
              httpsRank: instance.httpsRank,
              obsScore: instance.obsScore,
              obsRank: instance.obsRank,
              users: instance.users,
              statuses: instance.statuses,
              connections: instance.connections,
              openRegistrations: instance.openRegistrations,
              info: instance.info.map { InstanceInformationModel(from: $0) }, // Convert nested struct
              thumbnail: instance.thumbnail,
              thumbnailProxy: instance.thumbnailProxy,
              activeUsers: instance.activeUsers,
              email: instance.email,
              admin: instance.admin,
              instanceDescription: instance.instanceDescription
          )
      }
}

@Model
class InstanceInformationModel {
    var shortDescription: String?
    var fullDescription: String?
    var topic: String?
    var languages: [String]?
    var otherLanguagesAccepted: Bool?
    var federatesWith: String?
    var prohibitedContent: [String]?
    var categories: [String]?
    var title: String?
    var thumbnail: URL?

    init(shortDescription: String? = nil, fullDescription: String? = nil, topic: String? = nil, languages: [String]? = nil, otherLanguagesAccepted: Bool? = nil, federatesWith: String? = nil, prohibitedContent: [String]? = nil, categories: [String]? = nil, title: String? = nil, thumbnail: URL? = nil) {
        self.shortDescription = shortDescription
        self.fullDescription = fullDescription
        self.topic = topic
        self.languages = languages
        self.otherLanguagesAccepted = otherLanguagesAccepted
        self.federatesWith = federatesWith
        self.prohibitedContent = prohibitedContent
        self.categories = categories
        self.title = title
        self.thumbnail = thumbnail
    }
    convenience init(from info: InstanceInformation) {
        self.init(
            shortDescription: info.shortDescription,
            fullDescription: info.fullDescription,
            topic: info.topic,
            languages: info.languages,
            otherLanguagesAccepted: info.otherLanguagesAccepted,
            federatesWith: info.federatesWith,
            prohibitedContent: info.prohibitedContent,
            categories: info.categories,
            title: info.title,
            thumbnail: info.thumbnail
        )
    }
}
