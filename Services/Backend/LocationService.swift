//
//  LocationService.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 24/01/25.
//

import Foundation
import CoreLocation
import Observation
import OSLog

// MARK: - LocationManager

@Observable
final class LocationManager: NSObject, CLLocationManagerDelegate {
    // Current user location
    var userLocation: CLLocation?

    private let manager = CLLocationManager()
    private let logger = Logger(subsystem: "titan.mustard.app.ao", category: "LocationManager")
    private var isUpdatingLocation: Bool = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyReduced // Privacy-preserving default
    }

    /// Explicitly request location authorization only when user triggers a location-dependent action
    func requestLocationPermission() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            startUpdatingLocation()
        default:
            logger.warning("Location access denied or restricted.")
        }
    }

    private func startUpdatingLocation() {
        guard !isUpdatingLocation else { return }
        logger.debug("Starting Location Updates.")
        isUpdatingLocation = true
        manager.startUpdatingLocation()
    }

    private func stopUpdatingLocation() {
        guard isUpdatingLocation else { return }
        logger.debug("Stopping location updates.")
        manager.stopUpdatingLocation()
        isUpdatingLocation = false
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        self.userLocation = location
        self.logger.debug("Location updated: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        self.stopUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        logger.error("Failed to update location: \(error.localizedDescription, privacy: .public)")
        stopUpdatingLocation()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            startUpdatingLocation()
        case .denied, .restricted:
            stopUpdatingLocation()
            logger.warning("Location access denied or restricted.")
        default:
            break
        }
    }
}
