//
//  APITestService.swift
//  ShopperPlus
//
//  Created by Shaker Gilbert on 8/2/25.
//

import Foundation
import Combine

@MainActor
class APITestService: ObservableObject {
    static let shared = APITestService()

    @Published var testResults: [APITestResult] = []
    @Published var isRunningTests = false
    @Published var overallStatus: TestStatus = .unknown

    private let networkingService = NetworkingService.shared
    private var cancellables = Set<AnyCancellable>()

    private init() {}

    // MARK: - Test Models

    struct APITestResult: Identifiable {
        let id = UUID()
        let testName: String
        let endpoint: String
        let status: TestStatus
        let responseTime: TimeInterval?
        let statusCode: Int?
        let errorMessage: String?
        let responseData: String?
        let timestamp: Date

        var statusIcon: String {
            switch status {
            case .passed: return "✅"
            case .failed: return "❌"
            case .warning: return "⚠️"
            case .running: return "🔄"
            case .unknown: return "❓"
            }
        }

        var statusColor: String {
            switch status {
            case .passed: return "green"
            case .failed: return "red"
            case .warning: return "orange"
            case .running: return "blue"
            case .unknown: return "gray"
            }
        }
    }

    enum TestStatus {
        case passed, failed, warning, running, unknown
    }

    // MARK: - Quick Tests

    func quickConnectivityTest() async -> (success: Bool, message: String) {
        let result = await networkingService.testAPIConnection()
        if result.success {
            return (true, "API is reachable")
        } else {
            return (false, result.error ?? "Unknown error")
        }
    }

    func quickEndpointTest() async -> (success: Bool, message: String) {
        do {
            _ = try await networkingService.fetchProductInfo(from: "https://www.amazon.com/test")
            return (true, "Products endpoint working")
        } catch {
            if let networkingError = error as? NetworkingError,
               case .serverError(let code) = networkingError,
               code != 404 {
                return (true, "Endpoint reachable (non-404 response)")
            }
            return (false, maskSensitiveData(error.localizedDescription))
        }
    }

    // MARK: - Test Battery

    func runAllTests() async {
        isRunningTests = true
        testResults.removeAll()
        overallStatus = .running

        let tests: [(String, String, () async -> APITestResult)] = [
            ("Health Check", "/health", testHealthEndpoint),
            ("Products Info", "/api/v1/products/info", testProductsInfoEndpoint),
            ("Prices Check", "/api/v1/prices/check", testPricesCheckEndpoint),
            ("Prices Sync", "/api/v1/prices/sync", testPricesSyncEndpoint),
            ("Notifications Register", "/api/v1/notifications/register", testNotificationsEndpoint),
            ("Network Connectivity", "General", testNetworkConnectivity),
            ("DNS Resolution", "DNS", testDNSResolution),
            ("SSL Certificate", "SSL", testSSLCertificate)
        ]

        for (_, _, test) in tests {
            let result = await test()
            testResults.append(result)
        }

        // Calculate overall status
        let failedTests = testResults.filter { $0.status == .failed }
        let warningTests = testResults.filter { $0.status == .warning }

        if failedTests.isEmpty && warningTests.isEmpty {
            overallStatus = .passed
        } else if !failedTests.isEmpty {
            overallStatus = .failed
        } else {
            overallStatus = .warning
        }

        isRunningTests = false
    }

    // MARK: - Individual Tests

    private func testHealthEndpoint() async -> APITestResult {
        let startTime = Date()

        let result = await networkingService.testAPIConnection()
        let responseTime = Date().timeIntervalSince(startTime)

        if result.success {
            return APITestResult(
                testName: "Health Check",
                endpoint: "/health",
                status: .passed,
                responseTime: responseTime,
                statusCode: result.statusCode,
                errorMessage: nil,
                responseData: "Server is healthy",
                timestamp: Date()
            )
        } else {
            return APITestResult(
                testName: "Health Check",
                endpoint: "/health",
                status: .failed,
                responseTime: responseTime,
                statusCode: result.statusCode,
                errorMessage: result.error,
                responseData: nil,
                timestamp: Date()
            )
        }
    }

    private func testProductsInfoEndpoint() async -> APITestResult {
        let startTime = Date()
        let testURL = "https://www.amazon.com/test-product"

        do {
            let productInfo = try await networkingService.fetchProductInfo(from: testURL)
            let responseTime = Date().timeIntervalSince(startTime)

            return APITestResult(
                testName: "Products Info",
                endpoint: "/api/v1/products/info",
                status: .passed,
                responseTime: responseTime,
                statusCode: 200,
                errorMessage: nil,
                responseData: "Title: \(productInfo.title), Price: \(productInfo.price?.description ?? "nil")",
                timestamp: Date()
            )
        } catch {
            let responseTime = Date().timeIntervalSince(startTime)
            let statusCode = (error as? NetworkingError)?.extractStatusCode()

            return APITestResult(
                testName: "Products Info",
                endpoint: "/api/v1/products/info",
                status: .failed,
                responseTime: responseTime,
                statusCode: statusCode,
                errorMessage: maskSensitiveData(error.localizedDescription),
                responseData: nil,
                timestamp: Date()
            )
        }
    }

    private func testPricesCheckEndpoint() async -> APITestResult {
        let startTime = Date()

        // Test with a simple URL check
        guard let url = URL(string: "\(SecretsManager.shared.apiBaseURL)/prices/check") else {
            return APITestResult(
                testName: "Prices Check",
                endpoint: "/api/v1/prices/check",
                status: .failed,
                responseTime: nil,
                statusCode: nil,
                errorMessage: "Invalid URL",
                responseData: nil,
                timestamp: Date()
            )
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let requestBody = ["url": "https://www.amazon.com/test-product"]

        do {
            request.httpBody = try JSONEncoder().encode(requestBody)

            let (data, response) = try await URLSession.shared.data(for: request)
            let responseTime = Date().timeIntervalSince(startTime)

            guard let httpResponse = response as? HTTPURLResponse else {
                return APITestResult(
                    testName: "Prices Check",
                    endpoint: "/api/v1/prices/check",
                    status: .failed,
                    responseTime: responseTime,
                    statusCode: nil,
                    errorMessage: "Invalid response type",
                    responseData: nil,
                    timestamp: Date()
                )
            }

            let responseString = String(data: data, encoding: .utf8) ?? "Unable to decode response"

            if httpResponse.statusCode == 200 {
                return APITestResult(
                    testName: "Prices Check",
                    endpoint: "/api/v1/prices/check",
                    status: .passed,
                    responseTime: responseTime,
                    statusCode: httpResponse.statusCode,
                    errorMessage: nil,
                    responseData: maskSensitiveData(responseString),
                    timestamp: Date()
                )
            } else {
                return APITestResult(
                    testName: "Prices Check",
                    endpoint: "/api/v1/prices/check",
                    status: .failed,
                    responseTime: responseTime,
                    statusCode: httpResponse.statusCode,
                    errorMessage: "HTTP \(httpResponse.statusCode)",
                    responseData: maskSensitiveData(responseString),
                    timestamp: Date()
                )
            }
        } catch {
            let responseTime = Date().timeIntervalSince(startTime)
            return APITestResult(
                testName: "Prices Check",
                endpoint: "/api/v1/prices/check",
                status: .failed,
                responseTime: responseTime,
                statusCode: nil,
                errorMessage: maskSensitiveData(error.localizedDescription),
                responseData: nil,
                timestamp: Date()
            )
        }
    }

    private func testPricesSyncEndpoint() async -> APITestResult {
        let startTime = Date()

        guard let url = URL(string: "\(SecretsManager.shared.apiBaseURL)/prices/sync") else {
            return APITestResult(
                testName: "Prices Sync",
                endpoint: "/api/v1/prices/sync",
                status: .failed,
                responseTime: nil,
                statusCode: nil,
                errorMessage: "Invalid URL",
                responseData: nil,
                timestamp: Date()
            )
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let requestBody = [
            "items": [
                [
                    "id": "test-123",
                    "url": "https://www.amazon.com/test-product",
                    "lastUpdated": ISO8601DateFormatter().string(from: Date())
                ]
            ]
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

            let (data, response) = try await URLSession.shared.data(for: request)
            let responseTime = Date().timeIntervalSince(startTime)

            guard let httpResponse = response as? HTTPURLResponse else {
                return APITestResult(
                    testName: "Prices Sync",
                    endpoint: "/api/v1/prices/sync",
                    status: .failed,
                    responseTime: responseTime,
                    statusCode: nil,
                    errorMessage: "Invalid response type",
                    responseData: nil,
                    timestamp: Date()
                )
            }

            let responseString = String(data: data, encoding: .utf8) ?? "Unable to decode response"

            if httpResponse.statusCode == 200 {
                return APITestResult(
                    testName: "Prices Sync",
                    endpoint: "/api/v1/prices/sync",
                    status: .passed,
                    responseTime: responseTime,
                    statusCode: httpResponse.statusCode,
                    errorMessage: nil,
                    responseData: maskSensitiveData(responseString),
                    timestamp: Date()
                )
            } else {
                return APITestResult(
                    testName: "Prices Sync",
                    endpoint: "/api/v1/prices/sync",
                    status: .failed,
                    responseTime: responseTime,
                    statusCode: httpResponse.statusCode,
                    errorMessage: "HTTP \(httpResponse.statusCode)",
                    responseData: maskSensitiveData(responseString),
                    timestamp: Date()
                )
            }
        } catch {
            let responseTime = Date().timeIntervalSince(startTime)
            return APITestResult(
                testName: "Prices Sync",
                endpoint: "/api/v1/prices/sync",
                status: .failed,
                responseTime: responseTime,
                statusCode: nil,
                errorMessage: maskSensitiveData(error.localizedDescription),
                responseData: nil,
                timestamp: Date()
            )
        }
    }

    private func testNotificationsEndpoint() async -> APITestResult {
        let startTime = Date()

        guard let url = URL(string: "\(SecretsManager.shared.apiBaseURL)/notifications/register") else {
            return APITestResult(
                testName: "Notifications Register",
                endpoint: "/api/v1/notifications/register",
                status: .failed,
                responseTime: nil,
                statusCode: nil,
                errorMessage: "Invalid URL",
                responseData: nil,
                timestamp: Date()
            )
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let requestBody = [
            "deviceToken": "test-device-token-123",
            "userId": "test-user-123",
            "platform": "ios"
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

            let (data, response) = try await URLSession.shared.data(for: request)
            let responseTime = Date().timeIntervalSince(startTime)

            guard let httpResponse = response as? HTTPURLResponse else {
                return APITestResult(
                    testName: "Notifications Register",
                    endpoint: "/api/v1/notifications/register",
                    status: .failed,
                    responseTime: responseTime,
                    statusCode: nil,
                    errorMessage: "Invalid response type",
                    responseData: nil,
                    timestamp: Date()
                )
            }

            let responseString = String(data: data, encoding: .utf8) ?? "Unable to decode response"

            if httpResponse.statusCode == 200 {
                return APITestResult(
                    testName: "Notifications Register",
                    endpoint: "/api/v1/notifications/register",
                    status: .passed,
                    responseTime: responseTime,
                    statusCode: httpResponse.statusCode,
                    errorMessage: nil,
                    responseData: maskSensitiveData(responseString),
                    timestamp: Date()
                )
            } else {
                return APITestResult(
                    testName: "Notifications Register",
                    endpoint: "/api/v1/notifications/register",
                    status: .failed,
                    responseTime: responseTime,
                    statusCode: httpResponse.statusCode,
                    errorMessage: "HTTP \(httpResponse.statusCode)",
                    responseData: maskSensitiveData(responseString),
                    timestamp: Date()
                )
            }
        } catch {
            let responseTime = Date().timeIntervalSince(startTime)
            return APITestResult(
                testName: "Notifications Register",
                endpoint: "/api/v1/notifications/register",
                status: .failed,
                responseTime: responseTime,
                statusCode: nil,
                errorMessage: maskSensitiveData(error.localizedDescription),
                responseData: nil,
                timestamp: Date()
            )
        }
    }

    private func testNetworkConnectivity() async -> APITestResult {
        let startTime = Date()

        // Test basic internet connectivity
        guard let url = URL(string: "https://www.apple.com") else {
            return APITestResult(
                testName: "Network Connectivity",
                endpoint: "General",
                status: .failed,
                responseTime: nil,
                statusCode: nil,
                errorMessage: "Invalid test URL",
                responseData: nil,
                timestamp: Date()
            )
        }

        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            let responseTime = Date().timeIntervalSince(startTime)

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                return APITestResult(
                    testName: "Network Connectivity",
                    endpoint: "General",
                    status: .passed,
                    responseTime: responseTime,
                    statusCode: httpResponse.statusCode,
                    errorMessage: nil,
                    responseData: "Internet connectivity is working",
                    timestamp: Date()
                )
            } else {
                return APITestResult(
                    testName: "Network Connectivity",
                    endpoint: "General",
                    status: .warning,
                    responseTime: responseTime,
                    statusCode: (response as? HTTPURLResponse)?.statusCode,
                    errorMessage: "Unexpected response",
                    responseData: nil,
                    timestamp: Date()
                )
            }
        } catch {
            let responseTime = Date().timeIntervalSince(startTime)
            return APITestResult(
                testName: "Network Connectivity",
                endpoint: "General",
                status: .failed,
                responseTime: responseTime,
                statusCode: nil,
                errorMessage: maskSensitiveData(error.localizedDescription),
                responseData: nil,
                timestamp: Date()
            )
        }
    }

    private func testDNSResolution() async -> APITestResult {
        let startTime = Date()

        // Extract hostname from SecretsManager for security
        guard let baseURL = URL(string: SecretsManager.shared.apiBaseURL),
              let hostname = baseURL.host else {
            return APITestResult(
                testName: "DNS Resolution",
                endpoint: "DNS",
                status: .failed,
                responseTime: nil,
                statusCode: nil,
                errorMessage: "Invalid hostname configuration",
                responseData: nil,
                timestamp: Date()
            )
        }

        // Simplified DNS test using URLSession
        guard let url = URL(string: "https://\(hostname)") else {
            return APITestResult(
                testName: "DNS Resolution",
                endpoint: "DNS",
                status: .failed,
                responseTime: nil,
                statusCode: nil,
                errorMessage: "Invalid hostname",
                responseData: nil,
                timestamp: Date()
            )
        }

        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            let responseTime = Date().timeIntervalSince(startTime)

            if let httpResponse = response as? HTTPURLResponse {
                return APITestResult(
                    testName: "DNS Resolution",
                    endpoint: "DNS",
                    status: .passed,
                    responseTime: responseTime,
                    statusCode: httpResponse.statusCode,
                    errorMessage: nil,
                    responseData: "DNS resolution successful",
                    timestamp: Date()
                )
            } else {
                return APITestResult(
                    testName: "DNS Resolution",
                    endpoint: "DNS",
                    status: .warning,
                    responseTime: responseTime,
                    statusCode: nil,
                    errorMessage: "Non-HTTP response",
                    responseData: nil,
                    timestamp: Date()
                )
            }
        } catch {
            let responseTime = Date().timeIntervalSince(startTime)
            return APITestResult(
                testName: "DNS Resolution",
                endpoint: "DNS",
                status: .failed,
                responseTime: responseTime,
                statusCode: nil,
                errorMessage: maskSensitiveData(error.localizedDescription),
                responseData: nil,
                timestamp: Date()
            )
        }
    }

    private func testSSLCertificate() async -> APITestResult {
        let startTime = Date()
        let urlString = SecretsManager.shared.apiHealthURL

        guard let url = URL(string: urlString) else {
            return APITestResult(
                testName: "SSL Certificate",
                endpoint: "SSL",
                status: .failed,
                responseTime: nil,
                statusCode: nil,
                errorMessage: "Invalid URL",
                responseData: nil,
                timestamp: Date()
            )
        }

        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            let responseTime = Date().timeIntervalSince(startTime)

            if let httpResponse = response as? HTTPURLResponse {
                return APITestResult(
                    testName: "SSL Certificate",
                    endpoint: "SSL",
                    status: .passed,
                    responseTime: responseTime,
                    statusCode: httpResponse.statusCode,
                    errorMessage: nil,
                    responseData: "SSL certificate is valid",
                    timestamp: Date()
                )
            } else {
                return APITestResult(
                    testName: "SSL Certificate",
                    endpoint: "SSL",
                    status: .warning,
                    responseTime: responseTime,
                    statusCode: nil,
                    errorMessage: "Non-HTTP response",
                    responseData: nil,
                    timestamp: Date()
                )
            }
        } catch {
            let responseTime = Date().timeIntervalSince(startTime)
            return APITestResult(
                testName: "SSL Certificate",
                endpoint: "SSL",
                status: .failed,
                responseTime: responseTime,
                statusCode: nil,
                errorMessage: maskSensitiveData(error.localizedDescription),
                responseData: nil,
                timestamp: Date()
            )
        }
    }
}

// MARK: - Helper Extensions

extension NetworkingError {
    func extractStatusCode() -> Int? {
        switch self {
        case .serverError(let code):
            return code
        default:
            return nil
        }
    }
}

extension APITestService {
    var apiBaseURL: String {
        return "*****.*****.com/api/v1"  // Masked for security
    }

    var apiHealthURL: String {
        return "*****.*****.com/health"  // Masked for security
    }

    // Helper function to mask URLs in error messages and responses
    private func maskSensitiveData(_ text: String) -> String {
        let baseURL = SecretsManager.shared.apiBaseURL
        let healthURL = SecretsManager.shared.apiHealthURL

        // Extract domain from URLs for masking
        var maskedText = text

        // Mask the base URL
        if let baseUrlObj = URL(string: baseURL),
           let host = baseUrlObj.host {
            maskedText = maskedText.replacingOccurrences(of: baseURL, with: "*****.\(host.suffix(from: host.lastIndex(of: ".") ?? host.startIndex))/api/v1")
            maskedText = maskedText.replacingOccurrences(of: host, with: "*****.\(host.suffix(from: host.lastIndex(of: ".") ?? host.startIndex))")
        }

        // Mask the health URL  
        if let healthUrlObj = URL(string: healthURL),
           let host = healthUrlObj.host {
            maskedText = maskedText.replacingOccurrences(of: healthURL, with: "*****.\(host.suffix(from: host.lastIndex(of: ".") ?? host.startIndex))/health")
        }

        return maskedText
    }
    
    // Public method for masking sensitive information in UI
    func maskSensitiveInfo(_ text: String) -> String {
        return maskSensitiveData(text)
    }
}
