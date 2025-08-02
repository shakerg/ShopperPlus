//
//  CloudKitSchemaSetup.swift
//  ShopperPlus
//
//  Created by Shaker Gilbert on 8/1/25.
//

import Foundation
import CloudKit

class CloudKitSchemaSetup {
    static let shared = CloudKitSchemaSetup()
    private let container = CKContainer(identifier: SecretsManager.shared.cloudKitContainerID)

    private init() {}

    /// Call this when you're ready to set up the CloudKit schema in development
    /// This should be run once during development to create the record types
    func setupDevelopmentSchema() async throws {
        let database = container.privateCloudDatabase

        // Create a sample TrackedItem record to establish the schema
        let sampleRecord = createSampleTrackedItemRecord()

        do {
            // Save the sample record - this will create the schema
            let savedRecord = try await database.save(sampleRecord)
            print("✅ CloudKit schema created successfully with record ID: \(savedRecord.recordID)")

            // Optionally delete the sample record after schema is created
            try await database.deleteRecord(withID: savedRecord.recordID)
            print("✅ Sample record cleaned up")

        } catch let error as CKError {
            print("❌ CloudKit schema setup failed: \(error.localizedDescription)")
            throw error
        }
    }

    /// Create a sample TrackedItem record with all the fields your app will need
    private func createSampleTrackedItemRecord() -> CKRecord {
        let record = CKRecord(recordType: "TrackedItem")

        // Add all the fields that TrackedItem will need
        record["title"] = "Sample Product" as CKRecordValue
        record["url"] = "https://example.com/product" as CKRecordValue
        record["currentPrice"] = 99.99 as CKRecordValue
        record["targetPrice"] = 79.99 as CKRecordValue
        record["currency"] = "USD" as CKRecordValue
        record["isActive"] = true as CKRecordValue
        record["lastUpdated"] = Date() as CKRecordValue
        record["createdAt"] = Date() as CKRecordValue
        record["imageURL"] = "https://example.com/image.jpg" as CKRecordValue
        record["category"] = "Electronics" as CKRecordValue
        record["priceHistory"] = ["99.99", "89.99", "99.99"] as CKRecordValue
        record["notificationsEnabled"] = true as CKRecordValue

        return record
    }

    /// Get information about existing record types in the database
    func getSchemaInfo() async -> (hasTrackedItem: Bool, recordTypes: [String]) {
        let database = container.privateCloudDatabase

        do {
            // Try to query for TrackedItem records
            let query = CKQuery(recordType: "TrackedItem", predicate: NSPredicate(value: true))
            let (_, _) = try await database.records(matching: query, resultsLimit: 1)

            // If we get here, TrackedItem exists
            return (hasTrackedItem: true, recordTypes: ["TrackedItem"])

        } catch let error as CKError {
            if error.code == .unknownItem {
                // Record type doesn't exist yet
                return (hasTrackedItem: false, recordTypes: [])
            }

            // Other error
            return (hasTrackedItem: false, recordTypes: [])
        } catch {
            return (hasTrackedItem: false, recordTypes: [])
        }
    }
}

// MARK: - Debug Extension
extension CloudKitSchemaSetup {
    /// For debug console - get schema status
    func getSchemaStatus() async -> String {
        let info = await getSchemaInfo()

        if info.hasTrackedItem {
            return "✅ Production schema ready\n📋 Record types: \(info.recordTypes.joined(separator: ", "))"
        } else {
            return "⚠️ Development mode\n📋 No production record types found\n💡 Run setupDevelopmentSchema() when ready"
        }
    }
}
