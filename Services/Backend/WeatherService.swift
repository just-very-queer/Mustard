//
//  WeatherService.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 06/02/25.
//

import Foundation
import CoreLocation
import OSLog

class WeatherService: ObservableObject {
    @Published private(set) var weather: WeatherData?
    @Published private(set) var error: AppError?

    private let logger = Logger(subsystem: "titan.mustard.app.ao", category: "WeatherService")
    private let apiKey: String

    init() {
        // Retrieve API key from environment variable or use default if not set
        if let apiKey = ProcessInfo.processInfo.environment["OPENWEATHER_API_KEY"] {
            self.apiKey = apiKey
        } else {
            // Default API key if environment variable is not set
            self.apiKey = "99657c93a7a93bea2de7bf9e32191042"
            print("Warning: OPENWEATHER_API_KEY environment variable not set, using default API key.")
        }
    }

    func fetchWeather(for location: CLLocation) async {
        let urlString = "https://api.openweathermap.org/data/2.5/weather?lat=\(location.coordinate.latitude)&lon=\(location.coordinate.longitude)&units=metric&appid=\(apiKey)"
        guard let url = URL(string: urlString) else {
            await handleWeatherError(.weather(.invalidURL))
            return
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                let errorDescription = HTTPURLResponse.localizedString(forStatusCode: statusCode)
                throw AppError(type: .weather(.badResponse),
                               underlyingError: NSError(domain: "HTTPError", code: statusCode,
                                                       userInfo: [NSLocalizedDescriptionKey: errorDescription]))
            }

            let weatherResponse = try JSONDecoder().decode(OpenWeatherResponse.self, from: data)
            let weatherData = WeatherData(
                temperature: weatherResponse.main.temp,
                description: weatherResponse.weather.first?.description ?? "Clear",
                cityName: weatherResponse.name
            )
            
            await MainActor.run { self.weather = weatherData }

        } catch {
            logger.error("Weather fetch failed: \(error.localizedDescription)")
            await handleWeatherError(.weather(.badResponse), error: error)
        }
    }

    private func handleWeatherError(_ type: AppError.ErrorType, error: Error? = nil) async {
        await MainActor.run {
            self.error = AppError(type: type, underlyingError: error)
        }
    }
}
