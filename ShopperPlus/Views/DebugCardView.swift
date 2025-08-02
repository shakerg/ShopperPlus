//
//  DebugCardView.swift
//  ShopperPlus
//
//  Created by Shaker Gilbert on 8/1/25.
//

import SwiftUI

struct DebugCardView: View {
    @StateObject private var debugHelpers = DebugHelpers.shared
    @StateObject private var networkingService = NetworkingService.shared
    @Environment(\.dismiss) private var dismiss
    @Binding var showDebugSection: Bool

    @State private var cloudKitTestResult: (success: Bool, status: String, details: String)?
    @State private var apiTestResult: (success: Bool, statusCode: Int?, error: String?)?
    @State private var notificationTestResult: (success: Bool, status: String, details: String)?
    @State private var isTestingCloudKit = false
    @State private var isTestingAPI = false
    @State private var isTestingNotifications = false

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 20) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "ladybug.slash.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.red)

                        Text("Debug Console")
                            .font(.title2Roboto)
                            .fontWeight(.bold)

                        Text("Test connections and view system information")
                            .font(.bodyRoboto)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top)

                    // Connection Tests Card
                    VStack(spacing: 16) {
                        HStack {
                            Image(systemName: "network.badge.shield.half.filled")
                                .foregroundColor(.blue)
                            Text("Connection Tests")
                                .font(.headlineRoboto)
                                .fontWeight(.semibold)
                            Spacer()
                        }

                        // CloudKit Test
                        DebugTestCardView(
                            icon: "icloud",
                            iconColor: .blue,
                            title: "CloudKit",
                            subtitle: "iCloud database connectivity",
                            isLoading: isTestingCloudKit,
                            result: cloudKitTestResult.map { (success: $0.success, message: $0.status, details: $0.details) },
                            testAction: testCloudKit
                        )

                        // API Test
                        DebugTestCardView(
                            icon: "network",
                            iconColor: .orange,
                            title: "API Service",
                            subtitle: "Backend connectivity",
                            isLoading: isTestingAPI,
                            result: apiTestResult.map { (success: $0.success, message: $0.success ? "Connected" : "Failed", details: $0.error ?? ($0.statusCode != nil ? "HTTP \($0.statusCode!)" : "Unknown")) },
                            testAction: testAPI
                        )

                        // Notification Permissions Test
                        DebugTestCardView(
                            icon: "bell",
                            iconColor: .purple,
                            title: "Notifications",
                            subtitle: "Permission status",
                            isLoading: isTestingNotifications,
                            result: notificationTestResult.map { (success: $0.success, message: $0.status, details: $0.details) },
                            testAction: testNotifications
                        )
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                    // Configuration Status Card
                    VStack(spacing: 16) {
                        HStack {
                            Image(systemName: "shield.checkered")
                                .foregroundColor(.green)
                            Text("Configuration Status")
                                .font(.headlineRoboto)
                                .fontWeight(.semibold)
                            Spacer()
                        }

                        VStack(spacing: 12) {
                            ConfigStatusRow(title: "Base URL", status: .configured)
                            ConfigStatusRow(title: "Health Endpoint", status: .configured)
                            ConfigStatusRow(title: "CloudKit Container", status: .configured)
                            ConfigStatusRow(title: "Secrets", status: .secured)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                    // Quick System Info
                    VStack(spacing: 16) {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.purple)
                            Text("System Info")
                                .font(.headlineRoboto)
                                .fontWeight(.semibold)
                            Spacer()
                        }

                        let systemInfo = debugHelpers.getSystemInfo()
                        VStack(spacing: 8) {
                            InfoRow(title: "App Version", value: systemInfo["App Version"] ?? "Unknown")
                            InfoRow(title: "iOS Version", value: systemInfo["iOS Version"] ?? "Unknown")
                            InfoRow(title: "Device", value: systemInfo["Device Model"] ?? "Unknown")
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showDebugSection = false
                        dismiss()
                    }
                    .font(.bodyRoboto)
                }
            }
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

struct DebugTestCardView: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let isLoading: Bool
    let result: (success: Bool, message: String, details: String)?
    let testAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                    .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.bodyRoboto)
                        .fontWeight(.medium)
                    Text(subtitle)
                        .font(.caption1Roboto)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button("Test") {
                    testAction()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(isLoading)
            }

            if isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Testing...")
                        .font(.caption1Roboto)
                        .foregroundColor(.secondary)
                }
            }

            if let result = result {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(result.success ? .green : .red)
                        Text(result.message)
                            .font(.caption1Roboto)
                            .fontWeight(.medium)
                    }

                    if !result.details.isEmpty {
                        Text(result.details)
                            .font(.caption2Roboto)
                            .foregroundColor(.secondary)
                            .padding(.leading, 20)
                    }
                }
            }
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}

struct ConfigStatusRow: View {
    let title: String
    let status: ConfigStatus

    enum ConfigStatus {
        case configured
        case secured
        case error

        var icon: String {
            switch self {
            case .configured: return "checkmark.circle.fill"
            case .secured: return "lock.fill"
            case .error: return "xmark.circle.fill"
            }
        }

        var color: Color {
            switch self {
            case .configured: return .green
            case .secured: return .blue
            case .error: return .red
            }
        }

        var text: String {
            switch self {
            case .configured: return "✓ CONFIGURED"
            case .secured: return "🔒 SECURED"
            case .error: return "✗ ERROR"
            }
        }
    }

    var body: some View {
        HStack {
            Image(systemName: status.icon)
                .foregroundColor(status.color)
                .frame(width: 20)

            Text(title)
                .font(.bodyRoboto)

            Spacer()

            Text(status.text)
                .font(.caption1Roboto)
                .foregroundColor(status.color)
                .fontWeight(.medium)
        }
    }
}

struct InfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(.bodyRoboto)
            Spacer()
            Text(value)
                .font(.caption1Roboto)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    DebugCardView(showDebugSection: .constant(true))
}
