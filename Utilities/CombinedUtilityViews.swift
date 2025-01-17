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

// MARK: - WeatherData

// WeatherData: Holds the parsed weather data.
struct WeatherData: Decodable {
    let temperature: Double
    let description: String
    let cityName: String
}

struct OpenWeatherResponse: Decodable {
    struct Main: Decodable {
        let temp: Double
    }
    
    struct Weather: Decodable {
        let description: String
    }
    
    let main: Main
    let weather: [Weather]
    let name: String
}

// MARK: - Cached

/// Cached timeline with posts and timestamp.
struct CachedTimeline {
    let posts: [Post]
    let timestamp: Date
}

// MARK: - User Model

struct User: Decodable, Identifiable {
    let id: String
    let username: String
    let displayName: String
    let avatar: URL?
    let url: URL  // Represents the account's URL, e.g., "https://mastodon.social/@username"
    
    // Computed property to derive instanceURL from the account URL
    var instanceURL: URL? {
        guard let host = url.host else { return nil }
        return URL(string: "https://\(host)")
    }
    
    enum CodingKeys: String, CodingKey {
        case id, username, displayName, avatar, url
    }
    
    /// Converts User to Account.
    func toAccount(url: URL) -> Account {
        return Account(
            id: id,
            username: username,
            displayName: displayName,
            avatar: avatar ?? URL(string: "https://example.com/default_avatar.png")!,
            acct: "@\(username)",
            url: url,
            accessToken: nil
        )
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

