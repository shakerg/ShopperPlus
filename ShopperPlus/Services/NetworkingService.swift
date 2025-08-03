//
//  NetworkingService.swift
//  ShopperPlus
//
//  Created by Shaker Gilbert on 7/31/25.
//
//  This service handles all network operations with proper connection state management
//  to prevent "nw_connection_copy_connected_local_endpoint on unconnected nw_connection" errors.
//  The URLSession is configured with appropriate timeouts and error handling.
//

import Foundation
import Combine
import UIKit

@MainActor
class NetworkingService: ObservableObject {
    static let shared = NetworkingService()

    private let baseURL = SecretsManager.shared.apiBaseURL
    private let healthURL = SecretsManager.shared.apiHealthURL
    private let session: URLSession

    @Published var isOnline = true
    private var cancellables = Set<AnyCancellable>()
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid

    private init() {
        // Configure URLSession with proper settings to prevent connection issues
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15.0
        config.timeoutIntervalForResource = 30.0
        config.waitsForConnectivity = false
        config.requestCachePolicy = .reloadIgnoringLocalCacheData

        // Additional settings to prevent nw_connection issues
        config.allowsCellularAccess = true
        config.allowsConstrainedNetworkAccess = true
        config.allowsExpensiveNetworkAccess = true
        config.httpMaximumConnectionsPerHost = 1
        // Note: httpShouldUsePipelining is deprecated in iOS 18.4+, HTTP/2 and HTTP/3 are preferred
        config.urlCredentialStorage = nil
        config.urlCache = nil

        self.session = URLSession(configuration: config)
        checkNetworkStatus()
        observeAppStateChanges()
    }

    deinit {
        // Clean up URLSession to prevent connection leaks
        session.invalidateAndCancel()
        cancellables.removeAll()

        // End background task if active - properly handled on main actor
        let taskID = backgroundTaskID
        if taskID != .invalid {
            backgroundTaskID = .invalid
            Task { @MainActor in
                UIApplication.shared.endBackgroundTask(taskID)
            }
        }
    }

    private func observeAppStateChanges() {
        // Observe app becoming active/inactive to manage network checks
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                // Resume normal ping frequency when app becomes active
                self?.checkNetworkStatus()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                // Reduce network activity when app goes to background
                self?.handleAppBackgrounding()
            }
            .store(in: &cancellables)
    }

    private func handleAppBackgrounding() {
        // Start a background task to safely complete any ongoing network operations
        Task { @MainActor in
            backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "NetworkCleanup") { [weak self] in
                // This block is called when the background time is about to expire
                if let taskID = self?.backgroundTaskID, taskID != .invalid {
                    Task { @MainActor in
                        UIApplication.shared.endBackgroundTask(taskID)
                    }
                    self?.backgroundTaskID = .invalid
                }
            }
        }
    }

    private func checkNetworkStatus() {
        // Periodic connectivity check with proper connection state handling
        Timer.publish(every: 30, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.pingServer()
            }
            .store(in: &cancellables)
    }

    private func pingServer() {
        // Use async/await to avoid nw_connection warnings with completion handlers
        // Add small delay to prevent rapid successive connections
        Task {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second delay
            await performPingCheck()
        }
    }

    private func performPingCheck() async {
        // Use the health endpoint from secrets
        guard let url = URL(string: healthURL) else {
            await MainActor.run {
                self.isOnline = false
            }
            return
        }

        // Create URLRequest with timeout to prevent hanging connections
        var request = URLRequest(url: url)
        request.timeoutInterval = 10.0
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.httpMethod = "GET"

        do {
            let (_, response) = try await session.data(for: request)

            await MainActor.run {
                if let httpResponse = response as? HTTPURLResponse {
                    // Accept 200 (OK) or 503 (Service Unavailable) as "online"
                    // 503 means the route is working but backend is down - still shows connectivity
                    self.isOnline = httpResponse.statusCode == 200 || httpResponse.statusCode == 503
                } else {
                    self.isOnline = false
                }
            }
        } catch {
            await MainActor.run {
                // Handle specific network errors that indicate connection issues
                if let urlError = error as? URLError {
                    switch urlError.code {
                    case .timedOut,
                         .cannotConnectToHost,
                         .networkConnectionLost,
                         .notConnectedToInternet:
                        self.isOnline = false
                    default:
                        // For other URL errors, still consider as offline
                        self.isOnline = false
                    }
                } else {
                    self.isOnline = false
                }
            }
        }
    }

    // MARK: - Product Information

    func fetchProductInfo(from url: String) async throws -> ProductInfo {
        guard let requestURL = URL(string: "\(baseURL)/products/info") else {
            throw NetworkingError.invalidURL
        }

        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let requestBody = ["url": url]
        request.httpBody = try JSONEncoder().encode(requestBody)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkingError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw NetworkingError.serverError(httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        
        // Create a flexible date decoding strategy to handle various ISO 8601 formats
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            
            // Try different ISO 8601 formats
            let formats = [
                "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'",  // With microseconds
                "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'",     // With milliseconds
                "yyyy-MM-dd'T'HH:mm:ss'Z'",         // Without fractional seconds
                "yyyy-MM-dd'T'HH:mm:ssZ",           // Alternative format
                "yyyy-MM-dd'T'HH:mm:ss.SSSZ"       // With milliseconds no Z
            ]
            
            for format in formats {
                formatter.dateFormat = format
                if let date = formatter.date(from: dateString) {
                    return date
                }
            }
            
            // If all formats fail, throw an error
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date string \(dateString)")
        }
        
        return try decoder.decode(ProductInfo.self, from: data)
    }

    // MARK: - Price Checking

    func checkPrice(for url: String) async throws -> PriceCheckResponse {
        guard let requestURL = URL(string: "\(baseURL)/prices/check") else {
            throw NetworkingError.invalidURL
        }

        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let requestBody = ["url": url]
        request.httpBody = try JSONEncoder().encode(requestBody)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkingError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw NetworkingError.serverError(httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        
        // Create a flexible date decoding strategy to handle various ISO 8601 formats
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            
            // Try different ISO 8601 formats
            let formats = [
                "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'",  // With microseconds
                "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'",     // With milliseconds
                "yyyy-MM-dd'T'HH:mm:ss'Z'",         // Without fractional seconds
                "yyyy-MM-dd'T'HH:mm:ssZ",           // Alternative format
                "yyyy-MM-dd'T'HH:mm:ss.SSSZ"       // With milliseconds no Z
            ]
            
            for format in formats {
                formatter.dateFormat = format
                if let date = formatter.date(from: dateString) {
                    return date
                }
            }
            
            // If all formats fail, throw an error
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date string \(dateString)")
        }
        
        return try decoder.decode(PriceCheckResponse.self, from: data)
    }

    // MARK: - Bulk Price Updates

    func syncPrices(for items: [TrackedItem]) async throws -> [PriceUpdateResponse] {
        guard let requestURL = URL(string: "\(baseURL)/prices/sync") else {
            throw NetworkingError.invalidURL
        }

        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let requestBody = SyncRequest(items: items.map { item in
            SyncRequestItem(
                id: item.id?.uuidString ?? UUID().uuidString,
                url: item.url ?? "",
                lastUpdated: item.lastUpdated ?? Date()
            )
        })

        request.httpBody = try JSONEncoder().encode(requestBody)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkingError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw NetworkingError.serverError(httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        
        // Create a flexible date decoding strategy to handle various ISO 8601 formats
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            
            // Try different ISO 8601 formats
            let formats = [
                "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'",  // With microseconds
                "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'",     // With milliseconds
                "yyyy-MM-dd'T'HH:mm:ss'Z'",         // Without fractional seconds
                "yyyy-MM-dd'T'HH:mm:ssZ",           // Alternative format
                "yyyy-MM-dd'T'HH:mm:ss.SSSZ"       // With milliseconds no Z
            ]
            
            for format in formats {
                formatter.dateFormat = format
                if let date = formatter.date(from: dateString) {
                    return date
                }
            }
            
            // If all formats fail, throw an error
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date string \(dateString)")
        }
        
        let syncResponse = try decoder.decode(SyncResponse.self, from: data)
        return syncResponse.updates
    }

    // MARK: - Notification Registration

    func registerForNotifications(deviceToken: String, userId: String) async throws {
        guard let requestURL = URL(string: "\(baseURL)/notifications/register") else {
            throw NetworkingError.invalidURL
        }

        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let requestBody = [
            "deviceToken": deviceToken,
            "userId": userId,
            "platform": "ios"
        ]

        request.httpBody = try JSONEncoder().encode(requestBody)

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkingError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw NetworkingError.serverError(httpResponse.statusCode)
        }
    }

    // MARK: - Debug Methods

    func testAPIConnection() async -> (success: Bool, statusCode: Int?, error: String?) {
        guard let url = URL(string: healthURL) else {
            return (false, nil, "Invalid health URL")
        }

        // Create URLRequest with proper configuration
        var request = URLRequest(url: url)
        request.timeoutInterval = 15.0
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.httpMethod = "GET"

        do {
            let (_, response) = try await session.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                let success = httpResponse.statusCode == 200 || httpResponse.statusCode == 503
                return (success, httpResponse.statusCode, nil)
            } else {
                return (false, nil, "Invalid response type")
            }
        } catch {
            // Handle specific network errors
            if let urlError = error as? URLError {
                switch urlError.code {
                case .timedOut:
                    return (false, nil, "Connection timed out")
                case .cannotConnectToHost:
                    return (false, nil, "Cannot connect to host")
                case .networkConnectionLost:
                    return (false, nil, "Network connection lost")
                case .notConnectedToInternet:
                    return (false, nil, "No internet connection")
                default:
                    return (false, nil, "Network error: \(urlError.localizedDescription)")
                }
            }
            return (false, nil, error.localizedDescription)
        }
    }
}

// MARK: - Data Models

struct ProductInfo: Codable {
    let title: String
    let price: Double?
    let currency: String
    let imageUrl: String?
    let availability: String?
    let lastUpdated: Date
}

struct PriceCheckResponse: Codable {
    let price: Double?
    let currency: String
    let availability: String?
    let lastUpdated: Date
    let success: Bool
    let error: String?
}

struct SyncRequest: Codable {
    let items: [SyncRequestItem]
}

struct SyncRequestItem: Codable {
    let id: String
    let url: String
    let lastUpdated: Date
}

struct SyncResponse: Codable {
    let updates: [PriceUpdateResponse]
    let success: Bool
    let timestamp: Date
}

struct PriceUpdateResponse: Codable {
    let id: String
    let price: Double?
    let currency: String
    let availability: String?
    let lastUpdated: Date
    let success: Bool
    let error: String?
}

// MARK: - Networking Errors

enum NetworkingError: LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(Int)
    case serviceUnavailable
    case noData
    case decodingError(Error)
    case networkUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL provided."
        case .invalidResponse:
            return "Invalid response from server."
        case .serverError(let statusCode):
            return "Server error: HTTP \(statusCode)"
        case .serviceUnavailable:
            return "Service temporarily unavailable. Please try again later."
        case .noData:
            return "No data received from server."
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .networkUnavailable:
            return "Network connection is unavailable."
        }
    }
}
