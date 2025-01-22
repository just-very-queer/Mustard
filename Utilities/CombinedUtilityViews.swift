//
//  CombinedUtilityViews.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 13/01/25.
//

import SwiftUI
import OSLog
import SafariServices
import CoreLocation
import Combine
import SwiftData

// MARK: - WeatherData

struct WeatherData: Decodable {
    let temperature: Double
    let description: String
    let cityName: String
}

struct OpenWeatherResponse: Decodable {
    struct Main: Decodable {
        let temp: Double
        let feels_like: Double
        let temp_min: Double
        let temp_max: Double
        let pressure: Int
        let humidity: Int
        let sea_level: Int?
        let grnd_level: Int?
    }

    struct Weather: Decodable {
        let id: Int
        let main: String
        let description: String
        let icon: String
    }

    struct Wind: Decodable {
        let speed: Double
        let deg: Int
        let gust: Double? //gust is optional
    }

    struct Clouds: Decodable {
        let all: Int
    }
    struct Sys: Decodable {
        let type: Int?
        let id: Int?
        let country: String
        let sunrise: Int
        let sunset: Int
    }
    let coord: Coordinates
    let weather: [Weather]
    let base: String
    let main: Main
    let visibility: Int
    let wind: Wind
    let clouds: Clouds
    let dt: Int
    let sys: Sys
    let timezone: Int
    let id: Int
    let name: String
    let cod: Int
    
    struct Coordinates: Decodable {
        let lon: Double
        let lat: Double
    }
}

// MARK: - Cached

/// Cached timeline with posts and timestamp.
struct CachedTimeline {
    let posts: [Post]
    let timestamp: Date
}

// MARK: - User Model

struct User: Identifiable, Codable {
    let id: String
    let username: String
    let acct: String
    let display_name: String
    let locked: Bool
    let bot: Bool
    let discoverable: Bool?
    let indexable: Bool?
    let group: Bool
    let created_at: Date
    let note: String
    let url: URL
    let avatar: URL?
    let avatar_static: URL?
    let header: URL?
    let header_static: URL?
    let followers_count: Int
    let following_count: Int
    let statuses_count: Int
    let last_status_at: String?
    let hide_collections: Bool?
    let noindex: Bool?
    let source: Source?
    let emojis: [Emoji]
    let roles: [Role]?
    let fields: [Field]
    
    // Computed property to derive instanceURL from the account URL
    var instanceURL: URL? {
        guard let host = url.host else { return nil }
        return URL(string: "https://\(host)")
    }
    
    enum CodingKeys: String, CodingKey {
        case id, username, acct, locked, bot, group, note, url, avatar, emojis, fields, roles
        case display_name = "display_name"
        case discoverable, indexable, created_at, avatar_static, header, header_static, followers_count, following_count, statuses_count, last_status_at, hide_collections, noindex, source
    }
    
    // Custom initialization to provide the necessary defaults
    init(id: String, username: String, acct: String, display_name: String, locked: Bool, bot: Bool, discoverable: Bool?, indexable: Bool?, group: Bool, created_at: Date, note: String, url: URL, avatar: URL?, avatar_static: URL?, header: URL?, header_static: URL?, followers_count: Int, following_count: Int, statuses_count: Int, last_status_at: String?, hide_collections: Bool?, noindex: Bool?, source: Source?, emojis: [Emoji], roles: [Role]?, fields: [Field]) {
        self.id = id
        self.username = username
        self.acct = acct
        self.display_name = display_name
        self.locked = locked
        self.bot = bot
        self.discoverable = discoverable
        self.indexable = indexable
        self.group = group
        self.created_at = created_at
        self.note = note
        self.url = url
        self.avatar = avatar
        self.avatar_static = avatar_static
        self.header = header
        self.header_static = header_static
        self.followers_count = followers_count
        self.following_count = following_count
        self.statuses_count = statuses_count
        self.last_status_at = last_status_at
        self.hide_collections = hide_collections
        self.noindex = noindex
        self.source = source
        self.emojis = emojis
        self.roles = roles
        self.fields = fields
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        username = try container.decode(String.self, forKey: .username)
        acct = try container.decode(String.self, forKey: .acct)
        display_name = try container.decode(String.self, forKey: .display_name)
        locked = try container.decode(Bool.self, forKey: .locked)
        bot = try container.decode(Bool.self, forKey: .bot)
        discoverable = try container.decodeIfPresent(Bool.self, forKey: .discoverable)
        indexable = try container.decodeIfPresent(Bool.self, forKey: .indexable)
        group = try container.decode(Bool.self, forKey: .group)
        note = try container.decode(String.self, forKey: .note)
        url = try container.decode(URL.self, forKey: .url)
        avatar = try container.decodeIfPresent(URL.self, forKey: .avatar)
        avatar_static = try container.decodeIfPresent(URL.self, forKey: .avatar_static)
        header = try container.decodeIfPresent(URL.self, forKey: .header)
        header_static = try container.decodeIfPresent(URL.self, forKey: .header_static)
        followers_count = try container.decode(Int.self, forKey: .followers_count)
        following_count = try container.decode(Int.self, forKey: .following_count)
        statuses_count = try container.decode(Int.self, forKey: .statuses_count)
        last_status_at = try container.decodeIfPresent(String.self, forKey: .last_status_at)
        hide_collections = try container.decodeIfPresent(Bool.self, forKey: .hide_collections)
        noindex = try container.decodeIfPresent(Bool.self, forKey: .noindex)
        source = try container.decodeIfPresent(Source.self, forKey: .source)
        emojis = try container.decode([Emoji].self, forKey: .emojis)
        fields = try container.decode([Field].self, forKey: .fields)
        
        // Decode 'roles' (handle single object or array case)
        do {
            if let role = try container.decodeIfPresent(Role.self, forKey: .roles) {
                roles = [role]
            } else {
                roles = try container.decodeIfPresent([Role].self, forKey: .roles)
            }
        } catch {
            print("Error decoding roles: \(error)")
            roles = nil
        }
        
        // Decode 'created_at' as a Date
        let createdAtString = try container.decode(String.self, forKey: .created_at)
           let dateFormatter = ISO8601DateFormatter()
           dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
           if let date = dateFormatter.date(from: createdAtString) {
               created_at = date
           } else {
               throw DecodingError.dataCorruptedError(forKey: .created_at, in: container, debugDescription: "Date string does not match format expected by formatter.")
           }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(username, forKey: .username)
        try container.encode(acct, forKey: .acct)
        try container.encode(display_name, forKey: .display_name)
        try container.encode(locked, forKey: .locked)
        try container.encode(bot, forKey: .bot)
        try container.encodeIfPresent(discoverable, forKey: .discoverable)
        try container.encodeIfPresent(indexable, forKey: .indexable)
        try container.encode(group, forKey: .group)
        try container.encode(note, forKey: .note)
        try container.encode(url, forKey: .url)
        try container.encodeIfPresent(avatar, forKey: .avatar)
        try container.encodeIfPresent(avatar_static, forKey: .avatar_static)
        try container.encodeIfPresent(header, forKey: .header)
        try container.encodeIfPresent(header_static, forKey: .header_static)
        try container.encode(followers_count, forKey: .followers_count)
        try container.encode(following_count, forKey: .following_count)
        try container.encode(statuses_count, forKey: .statuses_count)
        try container.encodeIfPresent(last_status_at, forKey: .last_status_at)
        try container.encodeIfPresent(hide_collections, forKey: .hide_collections)
        try container.encodeIfPresent(noindex, forKey: .noindex)
        try container.encodeIfPresent(source, forKey: .source)
        try container.encode(emojis, forKey: .emojis)
        try container.encodeIfPresent(roles, forKey: .roles)
        try container.encode(fields, forKey: .fields)
        
        // Encode 'created_at' as ISO8601 string
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let createdAtString = dateFormatter.string(from: created_at)
        try container.encode(createdAtString, forKey: .created_at)
    }
    
    // Converts User to Account.
    func toAccount(instanceURL: URL) -> Account {
        return Account(
            id: id,
            username: username,
            displayName: display_name,
            avatar: avatar ?? URL(string: "https://example.com/default_avatar.png")!,
            acct: "@\(username)",
            url: instanceURL,
            accessToken: nil
        )
    }
    
    struct Source: Codable {
        let privacy: String?
        let sensitive: Bool?
        let language: String?
        let note: String
        let fields: [Field]
        let follow_requests_count: Int?
        let hide_collections: Bool?
        let discoverable: Bool?
        let indexable: Bool?
        
        enum CodingKeys: String, CodingKey {
            case privacy, sensitive, language, note, fields
            case follow_requests_count = "follow_requests_count"
            case hide_collections, discoverable, indexable
        }
    }
    
    struct Emoji: Codable, Identifiable {
        let shortcode: String
        let url: URL
        let static_url: URL
        let visible_in_picker: Bool
        let category: String?
        
        var id: String { shortcode }
        
        enum CodingKeys: String, CodingKey {
            case shortcode, url
            case static_url = "static_url"
            case visible_in_picker = "visible_in_picker"
            case category
        }
    }
    
    struct Field: Codable {
        let name: String
        let value: String
        let verified_at: String?
        
        enum CodingKeys: String, CodingKey {
            case name, value
            case verified_at = "verified_at"
        }
    }
    
    struct Role: Codable, Identifiable {
        let id: String?
        let name: String
        let permissions: String?
        let color: String?
        let highlighted: Bool?
        
        enum CodingKeys: String, CodingKey {
            case id, name, permissions, color, highlighted
        }
    }
    
    // MARK: - Avatar View
    
    struct AvatarView: View {
        let url: URL?
        let size: CGFloat
        
        var body: some View {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                case .success(let image):
                    image.resizable().scaledToFill().clipShape(Circle())
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
        }
    }
}

// MARK: - Action Button View

struct ActionButton: View {
    let image: String
    let text: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: image).foregroundColor(color)
                Text(text)
            }
        }
    }
}

// MARK: - Loading Overlay

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

// MARK: - Link Preview

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

// MARK: - Full-Screen Image View

struct FullScreenImageView: View {
    let imageURL: URL
    @Binding var isPresented: Bool

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            AsyncImage(url: imageURL) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                case .success(let image):
                    image.resizable().scaledToFit().transition(.opacity)
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

            Button(action: { isPresented = false }) {
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

// MARK: - Safari Web View

struct SafariWebView: View {
    let url: URL

    var body: some View {
        SafariView(url: url)
    }
}

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = true
        return SFSafariViewController(url: url, configuration: config)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}


// MARK: - AvatarView.

struct AvatarView: View {
    let url: URL?
    let size: CGFloat

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .empty:
                ProgressView()
            case .success(let image):
                image.resizable().scaledToFill().clipShape(Circle())
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
    }
}

// MARK: - HTML Utilities

struct HTMLUtils {
    /// Converts an HTML string to plain text
    static func convertHTMLToPlainText(html: String) -> String {
        guard let data = html.data(using: .utf16) else { return html }
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        return (try? NSAttributedString(data: data, options: options, documentAttributes: nil).string) ?? html
    }

    /// Extracts links from an HTML string
    static func extractLinks(from html: String) -> [URL] {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return [] }
        let matches = detector.matches(in: html, options: [], range: NSRange(location: 0, length: html.utf16.count))
        return matches.compactMap { $0.url }
    }
}

// MARK: - URL Detection Extension

extension URL {
    /// Detects the first URL in a given content string
    static func detect(from content: String) -> URL? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        return detector?.firstMatch(in: content, options: [], range: NSRange(location: 0, length: content.utf16.count))?.url
    }
}

// MARK: - PostLocationManager Struct

struct PostLocationManager {
    // MARK: - Properties
    private let logger = Logger(subsystem: "com.yourcompany.Mustard", category: "PostLocationManager")
    
    /// Decodes geo-coordinates from a Mastodon post's content.
    /// Assumes that the post content contains coordinates in a recognizable format.
    /// Example format: "Location: 37.7749,-122.4194"
    func decodeLocation(from post: Post) -> CLLocation? {
        // Regular expression to find latitude and longitude
        let pattern = #"Location:\s*(-?\d+\.\d+),\s*(-?\d+\.\d+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            logger.error("Failed to create regex for location decoding.")
            return nil
        }

        let range = NSRange(location: 0, length: post.content.utf16.count)
        if let match = regex.firstMatch(in: post.content, options: [], range: range),
           match.numberOfRanges == 3,
           let latRange = Range(match.range(at: 1), in: post.content),
           let lonRange = Range(match.range(at: 2), in: post.content),
           let latitude = Double(post.content[latRange]),
           let longitude = Double(post.content[lonRange]) {
            let location = CLLocation(latitude: latitude, longitude: longitude)
            logger.debug("Decoded location from post id: \(post.id) -> \(latitude), \(longitude)")
            return location
        }

        logger.debug("No geo-coordinates found in post id: \(post.id)")
        return nil
    }

    /// Processes a post to extract location and prepare for future GIS map integration.
    func processPost(_ post: Post) {
        if let location = decodeLocation(from: post) {
            // Post the decoded location for other components to handle, such as timelineViewModel
            NotificationCenter.default.post(name: .didDecodePostLocation, object: nil, userInfo: ["location": location])
            // Log or store the location as needed
            logger.debug("Processed location for post id: \(post.id)")
        }
    }
    
    /// Fetches weather for a given location by notifying the TimelineViewModel
    func fetchWeather(for location: CLLocation) {
        // Post a notification to request weather fetch from TimelineViewModel
        NotificationCenter.default.post(name: .didRequestWeatherFetch, object: nil, userInfo: ["location": location])
        logger.debug("Requested weather fetch for location: \(location.coordinate.latitude), \(location.coordinate.longitude)")
    }
    
    // Additional functionalities for GIS map integration can be added here
}


// MARK: - LocationManager

// In ServicesAndErrorManagement.swift
final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    // Published property to expose the current location
    @Published var userLocation: CLLocation?
    
    // Private location manager instance
    private let manager = CLLocationManager()
    
    // Logger for debugging
    private let logger = Logger(subsystem: "com.yourcompany.Mustard", category: "LocationManager")
    
    // Publisher to emit location updates
    var locationPublisher: AnyPublisher<CLLocation, Never> {
        $userLocation
            .compactMap { $0 }
            .eraseToAnyPublisher()
    }
    
    // Initialization
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }
    
    // Function to request location permission
    func requestLocationPermission() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        default:
            logger.warning("Location access denied or restricted.")
        }
    }

    // CLLocationManagerDelegate method to handle location updates
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        
        // Update the userLocation and post a notification
        DispatchQueue.main.async {
            self.userLocation = location
            NotificationCenter.default.post(name: .didUpdateLocation, object: nil, userInfo: ["location": location])
        }
        
        // Log the updated location for debugging
        logger.debug("Location updated: \(location.coordinate.latitude), \(location.coordinate.longitude)")
    }
    
    // CLLocationManagerDelegate method to handle errors
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        logger.error("Failed to update location: \(error.localizedDescription, privacy: .public)")
    }
}

