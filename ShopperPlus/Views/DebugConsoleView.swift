//
//  DebugConsoleView.swift
//  ShopperPlus
//
//  Created by Shaker Gilbert on 8/3/25.
//

import SwiftUI

struct DebugConsoleView: View {
    @Binding var isPresented: Bool
    @StateObject private var apiTestService = APITestService.shared
    @StateObject private var debugHelpers = DebugHelpers.shared
    @StateObject private var networkingService = NetworkingService.shared

    @State private var showingDetailSheet = false
    @State private var selectedResult: APITestService.APITestResult?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                headerSection

                // Content - single scrollable view
                ScrollView {
                    VStack(spacing: 20) {
                        // API Tests Section
                        apiTestsSection

                        // System Info Section  
                        systemInfoSection
                    }
                    .padding()
                }
            }
            // .navigationTitle("Debug Console")
            // .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                    .font(.bodyRoboto)
                    .foregroundColor(.blue)
                }
            }
            .sheet(item: $selectedResult) { result in
                APITestDetailView(result: result)
            }
        }
        .background(Color(.systemBackground))
    }

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "ladybug.slash.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(.red)

            Text("Developer Debug Console")
                .font(.title3Roboto)
                .fontWeight(.semibold)

            Text("Test API endpoints and view system information")
                .font(.caption1Roboto)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color.clear)
    }

    private var apiTestsSection: some View {
        VStack(spacing: 16) {
            // Overall API Status
            HStack {
                Image(systemName: overallStatusIcon)
                    .font(.title2)
                    .foregroundColor(overallStatusColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text("API Status")
                        .font(.headlineRoboto)
                        .fontWeight(.semibold)

                    Text(overallStatusText)
                        .font(.bodyRoboto)
                        .foregroundColor(overallStatusColor)
                }

                Spacer()
            }
            .padding()
            .background(Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Full Width API Test Button
            Button(action: {
                Task {
                    await apiTestService.runAllTests()
                }
            }) {
                HStack {
                    if apiTestService.isRunningTests {
                        ProgressView()
                            .scaleEffect(0.8)
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: "network.badge.shield.half.filled")
                            .font(.title3)
                    }

                    Text(apiTestService.isRunningTests ? "Running API Tests..." : "Run API Tests")
                        .font(.bodyRoboto)
                        .fontWeight(.semibold)

                    Spacer()

                    if !apiTestService.testResults.isEmpty && !apiTestService.isRunningTests {
                        Text("\(apiTestService.testResults.count) tests")
                            .font(.caption1Roboto)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .padding(.horizontal, 20)
                .background(apiTestService.isRunningTests ? Color.gray : Color.blue)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(apiTestService.isRunningTests)

            // Test Results (if any)
            if !apiTestService.testResults.isEmpty {
                VStack(spacing: 8) {
                    HStack {
                        Text("Recent Test Results")
                            .font(.headlineRoboto)
                            .fontWeight(.semibold)
                        Spacer()
                        Text(DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .short))
                            .font(.caption1Roboto)
                            .foregroundColor(.secondary)
                    }

                    LazyVStack(spacing: 6) {
                        ForEach(apiTestService.testResults, id: \.testName) { result in
                            APITestRowView(result: result) {
                                selectedResult = result
                            }
                        }
                    }
                }
            }
        }
    }

    private var systemInfoSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                Text("System Information")
                    .font(.headlineRoboto)
                    .fontWeight(.semibold)
                Spacer()
            }

            VStack(spacing: 12) {
                // Network Status
                systemInfoCard(
                    title: "Network Status",
                    icon: networkingService.isOnline ? "wifi" : "wifi.slash",
                    iconColor: networkingService.isOnline ? .green : .red,
                    items: [
                        ("Connection", networkingService.isOnline ? "Online" : "Offline"),
                        ("Status", networkingService.isOnline ? "Connected" : "Disconnected"),
                        ("Environment", "Production")
                    ]
                )

                // Device Info
                systemInfoCard(
                    title: "Device Information",
                    icon: "iphone",
                    iconColor: .blue,
                    items: [
                        ("Device", UIDevice.current.model),
                        ("iOS Version", UIDevice.current.systemVersion),
                        ("App Version", Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"),
                        ("Build", Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown")
                    ]
                )

                // Debug Settings
                systemInfoCard(
                    title: "Debug Settings",
                    icon: "gearshape.2",
                    iconColor: .orange,
                    items: [
                        ("Debug Mode", "Enabled"),
                        ("Logging", "Verbose"),
                        ("Test Mode", "Active")
                    ]
                )

                // CloudKit Status
                CloudKitStatusCard()
            }
        }
    }

    private func systemInfoCard(title: String, icon: String, iconColor: Color, items: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                Text(title)
                    .font(.headlineRoboto)
                    .fontWeight(.semibold)
            }

            VStack(spacing: 8) {
                ForEach(items, id: \.0) { item in
                    HStack {
                        Text(item.0)
                            .font(.bodyRoboto)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(item.1)
                            .font(.bodyRoboto)
                            .fontWeight(.medium)
                    }
                }
            }
        }
        .padding()
        .background(Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - API Status Helpers

    private var overallStatusIcon: String {
        switch apiTestService.overallStatus {
        case .passed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .running: return "arrow.clockwise"
        case .unknown: return "questionmark.circle"
        }
    }

    private var overallStatusColor: Color {
        switch apiTestService.overallStatus {
        case .passed: return .green
        case .failed: return .red
        case .warning: return .orange
        case .running: return .blue
        case .unknown: return .gray
        }
    }

    private var overallStatusText: String {
        switch apiTestService.overallStatus {
        case .passed: return "All tests passed"
        case .failed: return "Some tests failed"
        case .warning: return "Tests passed with warnings"
        case .running: return "Running tests..."
        case .unknown: return "No tests run"
        }
    }
}

struct APITestRowView: View {
    let result: APITestService.APITestResult
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                // Status Icon
                Image(systemName: statusIcon)
                    .font(.title3)
                    .foregroundColor(statusColor)
                    .frame(width: 30)

                // Test Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.testName)
                        .font(.bodyRoboto)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    Text(result.endpoint)
                        .font(.caption1Roboto)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Response Time
                if let responseTime = result.responseTime {
                    Text("\(Int(responseTime * 1000))ms")
                        .font(.caption1Roboto)
                        .foregroundColor(.secondary)
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var statusIcon: String {
        switch result.status {
        case .passed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .running: return "arrow.clockwise"
        case .unknown: return "questionmark.circle"
        }
    }

    private var statusColor: Color {
        switch result.status {
        case .passed: return .green
        case .failed: return .red
        case .warning: return .orange
        case .running: return .blue
        case .unknown: return .gray
        }
    }
}

// MARK: - CloudKit Status Card

struct CloudKitStatusCard: View {
    @StateObject private var cloudKitManager = CloudKitManager.shared
    @StateObject private var debugHelpers = DebugHelpers.shared
    
    @State private var containerStatus: String = "Unknown"
    @State private var accountStatus: String = "Unknown"
    @State private var syncStatus: String = "Unknown"
    @State private var isLoading = false
    @State private var lastUpdated: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "icloud.fill")
                    .foregroundColor(.blue)
                Text("CloudKit Status")
                    .font(.headlineRoboto)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Button("Refresh") {
                        refreshStatus()
                    }
                    .font(.caption1Roboto)
                    .foregroundColor(.blue)
                }
            }

            VStack(spacing: 8) {
                cloudKitRow("Container", containerStatus)
                cloudKitRow("iCloud Account", accountStatus)
                cloudKitRow("Sync Status", syncStatus)
                cloudKitRow("Container ID", SecretsManager.shared.cloudKitContainerID)
                
                if let lastUpdated = lastUpdated {
                    cloudKitRow("Last Checked", DateFormatter.localizedString(from: lastUpdated, dateStyle: .none, timeStyle: .medium))
                }
            }
        }
        .padding()
        .background(Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onAppear {
            refreshStatus()
        }
    }
    
    private func cloudKitRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(.bodyRoboto)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.bodyRoboto)
                .fontWeight(.medium)
                .foregroundColor(getStatusColor(for: value))
        }
    }
    
    private func getStatusColor(for status: String) -> Color {
        if status.contains("✅") || status.contains("Connected") || status.contains("Available") || status.contains("Success") {
            return .green
        } else if status.contains("❌") || status.contains("Failed") || status.contains("No Account") || status.contains("Restricted") {
            return .red
        } else if status.contains("⚠️") || status.contains("Warning") || status.contains("Syncing") {
            return .orange
        } else {
            return .primary
        }
    }
    
    private func refreshStatus() {
        isLoading = true
        
        Task {
            let result = await debugHelpers.testCloudKitConnection()
            
            await MainActor.run {
                // Parse the results
                if result.success {
                    containerStatus = "✅ Available"
                    accountStatus = "✅ Signed In"
                } else {
                    containerStatus = "❌ \(result.status)"
                    accountStatus = result.details.contains("No Account") ? "❌ Not Signed In" : "❓ \(result.status)"
                }
                
                // Sync status from CloudKitManager
                switch cloudKitManager.syncStatus {
                case .idle:
                    syncStatus = "⏸ Idle"
                case .syncing:
                    syncStatus = "🔄 Syncing"
                case .success:
                    syncStatus = "✅ Success"
                case .failed(let error):
                    syncStatus = "❌ Failed: \(error.localizedDescription)"
                }
                
                lastUpdated = Date()
                isLoading = false
            }
        }
    }
}

#Preview {
    DebugConsoleView(isPresented: .constant(true))
}
