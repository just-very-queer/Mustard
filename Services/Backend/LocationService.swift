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

//REMOVED: Removed the struct entirely, no weather references
/*struct PostLocationManager {
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
        // REMOVED: No weather functionality.
        // Post a notification to request weather fetch from TimelineViewModel
        //NotificationCenter.default.post(name: .didRequestWeatherFetch, object: nil, userInfo: ["location": location])
        //logger.debug("Requested weather fetch for location: \(location.coordinate.latitude), \(location.coordinate.longitude)")
    }

    // Additional functionalities for GIS map integration can be added here
}*/


// MARK: - LocationManager

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

   //REMOVED: No need of lastUpdateTime if only one location is needed
    //private let updateInterval: TimeInterval = 60 * 60 // 1 hour in seconds  //REMOVED
    //private let significantDistanceThreshold: CLLocationDistance = 500 // 500 meters //REMOVED
   // private var lastLocation: CLLocation? //REMOVED
   // private var lastUpdateTime: Date? //REMOVED
    private var isUpdatingLocation: Bool = false // Track if location updates are currently active


    // Initialization
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        // Removed distanceFilter and activityType
        manager.requestWhenInUseAuthorization()
        startUpdatingLocation() // Start updates immediately
    }

    // Function to request location permission (can be called explicitly if needed)
    func requestLocationPermission() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            startUpdatingLocation() // Start updates after permission
        default:
            logger.warning("Location access denied or restricted.")
        }
    }
    private func startUpdatingLocation() {
           guard !isUpdatingLocation else {
                logger.debug("Location updates already active.")
                return
            }
        logger.debug("Starting Location Updates.")
        isUpdatingLocation = true
        manager.startUpdatingLocation()
    }


    // CLLocationManagerDelegate method to handle location updates
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        DispatchQueue.main.async {
             self.userLocation = location
             //KEEP: this notification is important for other parts of the app.
             NotificationCenter.default.post(name: .didUpdateLocation, object: nil, userInfo: ["location": location])
             self.logger.debug("Location updated: \(location.coordinate.latitude), \(location.coordinate.longitude)")
             self.stopUpdatingLocation() // Stop after one update
         }
        
    }

     private func stopUpdatingLocation() {
          guard isUpdatingLocation else {
                logger.debug("Location updates not active.")
              return
          }

        logger.debug("Stopping location updates.")
        manager.stopUpdatingLocation() // Stop after one update
        isUpdatingLocation = false
    }

    // CLLocationManagerDelegate method to handle errors
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        logger.error("Failed to update location: \(error.localizedDescription, privacy: .public)")
        stopUpdatingLocation() // Stop on error
    }

    // Handle changes in authorization status
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            startUpdatingLocation() // Start updates on authorization
        case .denied, .restricted:
            stopUpdatingLocation()  // Stop on denial
            logger.warning("Location access denied or restricted.")
        default:
            logger.warning("Authorization status changed to: \(manager.authorizationStatus.rawValue)")
        }
    }

    // Method to manually trigger location update check (e.g., when app becomes active)
    func refreshLocation() { //Changed Name for Simplification
         startUpdatingLocation() // Just restart updates
    }
}
