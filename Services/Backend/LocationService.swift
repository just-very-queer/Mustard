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
    
    // Properties for location update frequency control
    private let updateInterval: TimeInterval = 60 * 60 // 1 hour in seconds
    private let significantDistanceThreshold: CLLocationDistance = 500 // 500 meters
    private var lastLocation: CLLocation?
    private var lastUpdateTime: Date?
    private var isUpdatingLocation: Bool = false // Track if location updates are currently active
    
    
    // Initialization
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = kCLDistanceFilterNone // Report all movements, then filter in delegate
        manager.activityType = .fitness //  Optimize for activities like walking, running
        
        manager.requestWhenInUseAuthorization()
        startHourlyLocationUpdatesIfAuthorized() // Initial start with hourly updates
    }
    
    // Function to request location permission (can be called explicitly if needed)
    func requestLocationPermission() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            startHourlyLocationUpdatesIfAuthorized() // Start hourly updates after permission is confirmed
        default:
            logger.warning("Location access denied or restricted.")
        }
    }
    
    // Start hourly location updates if authorization is granted
    private func startHourlyLocationUpdatesIfAuthorized() {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            startLocationUpdatesIfNeeded() // Call the method that checks for time and distance
        default:
            logger.warning("Location updates not started. Authorization status: \(self.manager.authorizationStatus.rawValue)")
        }
    }
    
    private func startLocationUpdatesIfNeeded() {
        guard !isUpdatingLocation else {
            logger.debug("Location updates already active, skipping start request.")
            return
        }
        
        if let lastUpdateTime = lastUpdateTime, Date().timeIntervalSince(lastUpdateTime) < updateInterval {
            logger.debug("Hourly update interval not yet reached, skipping location update.")
            return // Not yet time for an hourly update
        }
        
        logger.debug("Starting location updates.")
        isUpdatingLocation = true
        manager.startUpdatingLocation()
    }
    
    private func stopLocationUpdatesIfNeeded() {
        guard isUpdatingLocation else {
            logger.debug("Location updates already inactive, skipping stop request.")
            return
        }
        logger.debug("Stopping location updates.")
        isUpdatingLocation = false
        manager.stopUpdatingLocation()
    }
    
    
    // CLLocationManagerDelegate method to handle location updates
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        let isSignificantDistanceMoved = lastLocation == nil || location.distance(from: lastLocation!) > significantDistanceThreshold;
        let isTimeElapsed = lastUpdateTime == nil || Date().timeIntervalSince(lastUpdateTime!) >= updateInterval;
        
        if isSignificantDistanceMoved || isTimeElapsed || lastLocation == nil { // Always update on first location
            DispatchQueue.main.async {
                self.userLocation = location
                NotificationCenter.default.post(name: .didUpdateLocation, object: nil, userInfo: ["location": location])
            }
            lastLocation = location
            lastUpdateTime = Date()
            
            logger.debug("Location updated: \(location.coordinate.latitude), \(location.coordinate.longitude). Significant move: \(isSignificantDistanceMoved), Time elapsed: \(isTimeElapsed)")
        } else {
            logger.debug("Location update received but ignored due to time and distance constraints.")
        }
        stopLocationUpdatesIfNeeded() // Stop after each update to respect hourly/distance condition, will be restarted when needed.
    }
    
    
    // CLLocationManagerDelegate method to handle errors
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        logger.error("Failed to update location: \(error.localizedDescription, privacy: .public)")
        stopLocationUpdatesIfNeeded() // Stop updates on error as well
    }
    
    // Handle changes in authorization status
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            startHourlyLocationUpdatesIfAuthorized() // Re-start hourly updates on authorization
        case .denied, .restricted:
            stopLocationUpdatesIfNeeded() // Stop updates if authorization is denied or restricted
        default:
            logger.warning("Authorization status changed to: \(manager.authorizationStatus.rawValue)")
        }
    }
    
    // Method to manually trigger location update check (e.g., when app becomes active)
    func refreshLocationIfNeeded() {
        startLocationUpdatesIfNeeded()
    }
}
