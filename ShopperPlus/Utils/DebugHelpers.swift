//
//  DebugHelpers.swift
//  ShopperPlus
//
//  Created by Shaker Gilbert on 8/1/25.
//

import Foundation
import CloudKit
import SwiftUI
import UserNotifications

class DebugHelpers: ObservableObject {
    static let shared = DebugHelpers()

    private init() {}

    // MARK: - CloudKit Testing

    func testCloudKitConnection() async -> (success: Bool, status: String, details: String) {
        let container = CKContainer(identifier: SecretsManager.shared.cloudKitContainerID)

        do {
            // Test account status
            let accountStatus = try await container.accountStatus()

            switch accountStatus {
            case .available:
                // Test database access with a simple operation that doesn't require existing record types
                do {
                    let database = container.privateCloudDatabase

                    // Try to perform a simple database operation - fetch database schema info
                    // This tests connectivity without requiring specific record types to exist
                    let testRecord = CKRecord(recordType: "TestConnection")
                    testRecord["testField"] = "connectivity_test" as CKRecordValue

                    // We'll try to save and immediately delete a test record
                    // This tests full database write/read/delete permissions
                    let savedRecord = try await database.save(testRecord)

                    // Clean up the test record
                    _ = try await database.deleteRecord(withID: savedRecord.recordID)

                    // Get schema information
                    let schemaStatus = await CloudKitSchemaSetup.shared.getSchemaStatus()

                    let details = """
                    ✅ CloudKit Status: Available
                    ✅ Account: Signed in
                    ✅ Database: Accessible
                    ✅ Permissions: Read/Write/Delete confirmed

                    📋 Schema Status:
                    \(schemaStatus)

                    🔧 Container: \(SecretsManager.shared.cloudKitContainerID)
                    """

                    return (true, "Connected", details)
                } catch let error as CKError {
                    let details = """
                    ✅ CloudKit Status: Available
                    ✅ Account: Signed in
                    ❌ Database Error: \(error.localizedDescription)
                    🔧 Error Code: \(error.code.rawValue)
                    🔧 Container: \(SecretsManager.shared.cloudKitContainerID)
                    """

                    return (false, "Database Error", details)
                } catch {
                    let details = """
                    ✅ CloudKit Status: Available
                    ✅ Account: Signed in
                    ❌ Database Error: \(error.localizedDescription)
                    🔧 Container: \(SecretsManager.shared.cloudKitContainerID)
                    """

                    return (false, "Database Error", details)
                }

            case .noAccount:
                let details = """
                ❌ CloudKit Status: No iCloud Account
                📱 User needs to sign in to iCloud
                🔧 Container: \(SecretsManager.shared.cloudKitContainerID)
                """
                return (false, "No Account", details)

            case .restricted:
                let details = """
                ❌ CloudKit Status: Restricted
                🔒 iCloud access is restricted on this device
                🔧 Container: \(SecretsManager.shared.cloudKitContainerID)
                """
                return (false, "Restricted", details)

            case .couldNotDetermine:
                let details = """
                ❓ CloudKit Status: Could not determine
                🔄 Try again later
                🔧 Container: \(SecretsManager.shared.cloudKitContainerID)
                """
                return (false, "Unknown", details)

            case .temporarilyUnavailable:
                let details = """
                ⏰ CloudKit Status: Temporarily unavailable
                🔄 Service is temporarily down
                🔧 Container: \(SecretsManager.shared.cloudKitContainerID)
                """
                return (false, "Unavailable", details)

            @unknown default:
                let details = """
                ❓ CloudKit Status: Unknown state
                🔧 Container: \(SecretsManager.shared.cloudKitContainerID)
                """
                return (false, "Unknown", details)
            }
        } catch {
            let details = """
            ❌ CloudKit Connection Failed
            🔴 Error: \(error.localizedDescription)
            🔧 Container: \(SecretsManager.shared.cloudKitContainerID)
            """
            return (false, "Connection Failed", details)
        }
    }

    // MARK: - Notification Permissions

    func checkNotificationPermissions() async -> (success: Bool, status: String, details: String) {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        let authorizationStatus: String
        let isEnabled: Bool

        switch settings.authorizationStatus {
        case .authorized:
            authorizationStatus = "Authorized"
            isEnabled = true
        case .denied:
            authorizationStatus = "Denied"
            isEnabled = false
        case .notDetermined:
            authorizationStatus = "Not Determined"
            isEnabled = false
        case .provisional:
            authorizationStatus = "Provisional"
            isEnabled = true
        case .ephemeral:
            authorizationStatus = "Ephemeral"
            isEnabled = true
        @unknown default:
            authorizationStatus = "Unknown"
            isEnabled = false
        }

        let alertSetting = settings.alertSetting == .enabled ? "✅ Enabled" : "❌ Disabled"
        let badgeSetting = settings.badgeSetting == .enabled ? "✅ Enabled" : "❌ Disabled"
        let soundSetting = settings.soundSetting == .enabled ? "✅ Enabled" : "❌ Disabled"
        let lockScreenSetting = settings.lockScreenSetting == .enabled ? "✅ Enabled" : "❌ Disabled"
        let notificationCenterSetting = settings.notificationCenterSetting == .enabled ? "✅ Enabled" : "❌ Disabled"

        let details = """
        📱 Authorization Status: \(authorizationStatus)

        🔔 Notification Settings:
        • Alerts: \(alertSetting)
        • Badges: \(badgeSetting)
        • Sounds: \(soundSetting)
        • Lock Screen: \(lockScreenSetting)
        • Notification Center: \(notificationCenterSetting)

        💡 Critical Alerts: \(settings.criticalAlertSetting == .enabled ? "✅ Enabled" : "❌ Disabled")
        🕐 Time Sensitive: \(settings.timeSensitiveSetting == .enabled ? "✅ Enabled" : "❌ Disabled")
        📢 Announcement: \(settings.announcementSetting == .enabled ? "✅ Enabled" : "❌ Disabled")
        """

        return (isEnabled, authorizationStatus, details)
    }

    // MARK: - System Information

    func getSystemInfo() -> [String: String] {
        return [
            "App Version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown",
            "Build Number": Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown",
            "Bundle ID": Bundle.main.bundleIdentifier ?? "Unknown",
            "iOS Version": UIDevice.current.systemVersion,
            "Device Model": UIDevice.current.model,
            "Device Name": UIDevice.current.name,
            "System Name": UIDevice.current.systemName
        ]
    }

    // MARK: - User Defaults Debug

    func getUserDefaultsInfo() -> [String: Any] {
        let userDefaults = UserDefaults.standard
        return [
            "Sound Enabled": userDefaults.object(forKey: "soundEnabled") ?? "Not set",
            "Haptics Enabled": userDefaults.object(forKey: "hapticsEnabled") ?? "Not set",
            "Dark Mode Enabled": userDefaults.object(forKey: "darkModeEnabled") ?? "Not set"
        ]
    }
}
