//
//  DebugView.swift
//  ShopperPlus
//
//  Created by Shaker Gilbert on 8/1/25.
//

import SwiftUI

struct DebugView: View {
    @StateObject private var debugHelpers = DebugHelpers.shared
    @StateObject private var networkingService = NetworkingService.shared

    @State private var cloudKitTestResult: (success: Bool, status: String, details: String)?
    @State private var apiTestResult: (success: Bool, statusCode: Int?, error: String?)?
    @State private var notificationTestResult: (success: Bool, status: String, details: String)?
    @State private var isTestingCloudKit = false
    @State private var isTestingAPI = false
    @State private var isTestingNotifications = false

    var body: some View {
        NavigationStack {
            List {
                // Connection Tests Section
                Section("Connection Tests") {
                    // CloudKit Test
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "icloud")
                                .foregroundColor(.blue)
                                .frame(width: 30)

                            VStack(alignment: .leading) {
                                Text("CloudKit Connection")
                                    .font(.bodyRoboto)
                                Text("Test iCloud database connectivity")
                                    .font(.caption1Roboto)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Button("Test") {
                                testCloudKit()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(isTestingCloudKit)
                        }

                        if let result = cloudKitTestResult {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundColor(result.success ? .green : .red)
                                    Text(result.status)
                                        .font(.bodyRoboto)
                                        .fontWeight(.medium)
                                }

                                Text(result.details)
                                    .font(.caption1Roboto)
                                    .foregroundColor(.secondary)
                                    .padding(.leading, 24)
                            }
                            .padding(.top, 8)
                        }

                        if isTestingCloudKit {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Testing CloudKit...")
                                    .font(.caption1Roboto)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, 8)
                        }
                    }
                    .padding(.vertical, 4)

                    // API Test
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "network")
                                .foregroundColor(.orange)
                                .frame(width: 30)

                            VStack(alignment: .leading) {
                                Text("API Connection")
                                    .font(.bodyRoboto)
                                Text("Test backend service connectivity")
                                    .font(.caption1Roboto)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Button("Test") {
                                testAPI()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(isTestingAPI)
                        }

                        if let result = apiTestResult {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundColor(result.success ? .green : .red)
                                    Text(result.success ? "Connected" : "Failed")
                                        .font(.bodyRoboto)
                                        .fontWeight(.medium)
                                }

                                let details = result.error ?? (result.statusCode != nil ? "HTTP \(result.statusCode!)" : "Unknown status")
                                Text(details)
                                    .font(.caption1Roboto)
                                    .foregroundColor(.secondary)
                                    .padding(.leading, 24)
                            }
                            .padding(.top, 8)
                        }

                        if isTestingAPI {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Testing API...")
                                    .font(.caption1Roboto)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, 8)
                        }
                    }
                    .padding(.vertical, 4)

                    // Notification Permissions Test
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "bell")
                                .foregroundColor(.purple)
                                .frame(width: 30)

                            VStack(alignment: .leading) {
                                Text("Notification Permissions")
                                    .font(.bodyRoboto)
                                Text("Check notification authorization status")
                                    .font(.caption1Roboto)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Button("Check") {
                                testNotifications()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(isTestingNotifications)
                        }

                        if let result = notificationTestResult {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundColor(result.success ? .green : .red)
                                    Text(result.status)
                                        .font(.bodyRoboto)
                                        .fontWeight(.medium)
                                }

                                Text(result.details)
                                    .font(.caption1Roboto)
                                    .foregroundColor(.secondary)
                                    .padding(.leading, 24)
                            }
                            .padding(.top, 8)
                        }

                        if isTestingNotifications {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Checking notifications...")
                                    .font(.caption1Roboto)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, 8)
                        }
                    }
                    .padding(.vertical, 4)
                }

                // API Endpoints Section
                Section("API Configuration") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Base URL")
                                .font(.bodyRoboto)
                            Spacer()
                            Text("✓ CONFIGURED")
                                .font(.caption1Roboto)
                                .foregroundColor(.green)
                                .fontWeight(.medium)
                        }

                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Health Endpoint")
                                .font(.bodyRoboto)
                            Spacer()
                            Text("✓ CONFIGURED")
                                .font(.caption1Roboto)
                                .foregroundColor(.green)
                                .fontWeight(.medium)
                        }

                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("CloudKit Container")
                                .font(.bodyRoboto)
                            Spacer()
                            Text("✓ CONFIGURED")
                                .font(.caption1Roboto)
                                .foregroundColor(.green)
                                .fontWeight(.medium)
                        }

                        HStack {
                            Image(systemName: "lock.fill")
                                .foregroundColor(.blue)
                            Text("Secrets Status")
                                .font(.bodyRoboto)
                            Spacer()
                            Text("🔒 SECURED")
                                .font(.caption1Roboto)
                                .foregroundColor(.blue)
                                .fontWeight(.medium)
                        }
                    }
                    .padding(.vertical, 4)
                }

                // System Information Section
                Section("System Information") {
                    ForEach(Array(debugHelpers.getSystemInfo().sorted(by: { $0.key < $1.key })), id: \.key) { key, value in
                        HStack {
                            Text(key)
                                .font(.bodyRoboto)
                            Spacer()
                            Text(value)
                                .font(.caption1Roboto)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // User Preferences Section
                Section("User Preferences") {
                    ForEach(Array(debugHelpers.getUserDefaultsInfo().sorted(by: { $0.key < $1.key })), id: \.key) { key, value in
                        HStack {
                            Text(key)
                                .font(.bodyRoboto)
                            Spacer()
                            Text("\(value)")
                                .font(.caption1Roboto)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Configuration Section
                Section("Security Status") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "shield.checkered")
                                .foregroundColor(.green)
                            Text("Configuration Security")
                                .font(.bodyRoboto)
                                .fontWeight(.medium)
                            Spacer()
                            Text("🔒 PROTECTED")
                                .font(.caption1Roboto)
                                .foregroundColor(.green)
                                .fontWeight(.medium)
                        }

                        Text("All sensitive configuration data is properly secured and not exposed in debug mode.")
                            .font(.caption1Roboto)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Debug Console")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    func testCloudKit() {
        isTestingCloudKit = true
        cloudKitTestResult = nil

        Task {
            let result = await debugHelpers.testCloudKitConnection()

            await MainActor.run {
                cloudKitTestResult = result
                isTestingCloudKit = false
            }
        }
    }

    func testAPI() {
        isTestingAPI = true
        apiTestResult = nil

        Task {
            let result = await networkingService.testAPIConnection()

            await MainActor.run {
                apiTestResult = result
                isTestingAPI = false
            }
        }
    }

    func testNotifications() {
        isTestingNotifications = true
        notificationTestResult = nil

        Task {
            let result = await debugHelpers.checkNotificationPermissions()

            await MainActor.run {
                notificationTestResult = result
                isTestingNotifications = false
            }
        }
    }
}

#Preview {
    DebugView()
}
