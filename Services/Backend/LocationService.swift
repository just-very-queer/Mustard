//
//  LocationService.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 24/01/25.
//

import Foundation
import CoreLocation
import Combine
import SwiftData
import OSLog

// MARK: - PostLocationManager Struct

struct PostLocationManager {
    // MARK: - Properties
    private let logger = Logger(subsystem: "titan.mustard.app.ao", category: "PostLocationManager")
    
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
    private let logger = Logger(subsystem: "titan.mustard.app.ao", category: "LocationManager")

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
        startUpdatingLocationIfAuthorized()
    }

    // Function to request location permission
    func requestLocationPermission() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
            manager.startUpdatingLocation()
        default:
            logger.warning("Location access denied or restricted.")
        }
    }

    // Start updating location if authorization is granted
    private func startUpdatingLocationIfAuthorized() {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
        default:
            logger.warning("Location updates not started. Authorization status: \(self.manager.authorizationStatus.rawValue)")
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

    // Handle changes in authorization status
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
        default:
            logger.warning("Authorization status changed to restricted or denied.")
        }
    }
}
