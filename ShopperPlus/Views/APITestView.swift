//
//  APITestView.swift
//  ShopperPlus
//
//  Created by Shaker Gilbert on 8/2/25.
//

import SwiftUI

struct APITestView: View {
    @StateObject private var apiTestService = APITestService.shared
    @State private var showingDetailSheet = false
    @State private var selectedResult: APITestService.APITestResult?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header with status overview
                headerSection

                // Test results list
                if apiTestService.testResults.isEmpty && !apiTestService.isRunningTests {
                    emptyStateView
                } else {
                    testResultsList
                }

                Spacer()

                // Run tests button
                runTestsButton
            }
            .shopperPlusNavigationHeader()
            .navigationTitle("API Tests")
            .font(.bodyRoboto)
            .sheet(item: Binding<APITestService.APITestResult?>(
                get: { selectedResult },
                set: { selectedResult = $0 }
            )) { result in
                APITestDetailView(result: result)
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 12) {
            // Overall status
            HStack {
                Image(systemName: statusIcon)
                    .font(.title2)
                    .foregroundColor(statusColor)

                VStack(alignment: .leading, spacing: 4) {
                    Text("API Status")
                        .font(.headlineRoboto)
                        .foregroundColor(.primary)

                    Text(statusMessage)
                        .font(.bodyRoboto)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if apiTestService.isRunningTests {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)

            // Configuration info
            VStack(alignment: .leading, spacing: 8) {
                configRow(title: "Base URL", value: apiTestService.apiBaseURL)
                configRow(title: "Health URL", value: apiTestService.apiHealthURL)
                configRow(title: "Network Status", value: NetworkingService.shared.isOnline ? "Online" : "Offline")
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .padding(.horizontal)
        .padding(.top)
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "network.slash")
                .font(.system(size: 48))
                .foregroundColor(.gray)

            Text("No API Tests Run Yet")
                .font(.title2Roboto)
                .foregroundColor(.primary)

            Text("Tap 'Run All Tests' to check API connectivity and endpoint functionality.")
                .font(.bodyRoboto)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }

    private var testResultsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(Array(apiTestService.testResults.enumerated()), id: \.offset) { _, result in
                    APITestResultRow(result: result) {
                        selectedResult = result
                        showingDetailSheet = true
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top)
        }
    }

    private var runTestsButton: some View {
        Button(action: runTests) {
            HStack {
                if apiTestService.isRunningTests {
                    ProgressView()
                        .scaleEffect(0.8)
                        .foregroundColor(.white)
                } else {
                    Image(systemName: "play.fill")
                }

                Text(apiTestService.isRunningTests ? "Running Tests..." : "Run All Tests")
                    .font(.headlineRoboto)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(apiTestService.isRunningTests ? Color.gray : Color.blue)
            .cornerRadius(10)
        }
        .disabled(apiTestService.isRunningTests)
        .padding(.horizontal)
        .padding(.bottom, 20)
    }

    private func configRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.bodyRoboto)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .font(.bodyRoboto)
                .foregroundColor(.primary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    private var statusIcon: String {
        switch apiTestService.overallStatus {
        case .passed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .running: return "arrow.clockwise.circle.fill"
        case .unknown: return "questionmark.circle.fill"
        }
    }

    private var statusColor: Color {
        switch apiTestService.overallStatus {
        case .passed: return .green
        case .failed: return .red
        case .warning: return .orange
        case .running: return .blue
        case .unknown: return .gray
        }
    }

    private var statusMessage: String {
        if apiTestService.isRunningTests {
            return "Running API tests..."
        }

        switch apiTestService.overallStatus {
        case .passed: return "All tests passed"
        case .failed: return "Some tests failed"
        case .warning: return "Tests completed with warnings"
        case .running: return "Tests in progress"
        case .unknown: return "No tests run yet"
        }
    }

    private func runTests() {
        Task {
            await apiTestService.runAllTests()
        }
    }
}

struct APITestResultRow: View {
    let result: APITestService.APITestResult
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Status icon
                Text(result.statusIcon)
                    .font(.title2)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(result.testName)
                            .font(.bodyRoboto)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)

                        Spacer()

                        if let responseTime = result.responseTime {
                            Text("\(Int(responseTime * 1000))ms")
                                .font(.caption1Roboto)
                                .foregroundColor(.secondary)
                        }
                    }

                    Text(result.endpoint)
                        .font(.caption1Roboto)
                        .foregroundColor(.secondary)

                    if let errorMessage = result.errorMessage {
                        Text(errorMessage)
                            .font(.caption1Roboto)
                            .foregroundColor(.red)
                            .lineLimit(2)
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

extension APITestService.TestStatus {
    var description: String {
        switch self {
        case .passed: return "Passed"
        case .failed: return "Failed"
        case .warning: return "Warning"
        case .running: return "Running"
        case .unknown: return "Unknown"
        }
    }
}

#Preview {
    APITestView()
}
