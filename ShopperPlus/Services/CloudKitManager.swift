//
//  CloudKitManager.swift
//  ShopperPlus
//
//  Created by Shaker Gilbert on 7/31/25.
//

import Foundation
import CloudKit
import Combine

@MainActor
class CloudKitManager: ObservableObject {
    static let shared = CloudKitManager()

    private let container: CKContainer
    private let privateDatabase: CKDatabase

    @Published var isSignedIn = false
    @Published var error: Error?
    @Published var syncStatus: SyncStatus = .idle

    private var cancellables = Set<AnyCancellable>()

    enum SyncStatus {
        case idle
        case syncing
        case success
        case failed(Error)
    }

    private init() {
        container = CKContainer(identifier: "iCloud.VuWing-Corp.ShopperPlus")
        privateDatabase = container.privateCloudDatabase

        checkAccountStatus()
    }

    // MARK: - Account Management

    private func checkAccountStatus() {
        container.accountStatus { [weak self] status, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.error = error
                    self?.isSignedIn = false
                } else {
                    self?.isSignedIn = status == .available
                }
            }
        }
    }

    // MARK: - TrackedItem Operations

    func saveTrackedItem(_ item: TrackedItem) async throws {
        guard isSignedIn else {
            throw CloudKitError.notSignedIn
        }

        syncStatus = .syncing

        // TODO: Implement CloudKit save once TrackedItem CloudKit methods are restored
        // let record = item.toCKRecord()
        // _ = try await privateDatabase.save(record)
        syncStatus = .success
    }

    func fetchTrackedItems() async throws -> [TrackedItem] {
        guard isSignedIn else {
            throw CloudKitError.notSignedIn
        }

        syncStatus = .syncing

        // TODO: Implement CloudKit fetch once TrackedItem CloudKit methods are restored
        /*
        let query = CKQuery(recordType: "TrackedItem", predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "dateAdded", ascending: false)]
        
        let (matchResults, _) = try await privateDatabase.records(matching: query)
        
        var items: [TrackedItem] = []
        for (_, result) in matchResults {
            switch result {
            case .success(let record):
                if let item = TrackedItem.fromCKRecord(record) {
                    items.append(item)
                }
            case .failure(let error):
                print("Failed to fetch record: \(error)")
            }
        }
        */

        syncStatus = .success
        return [] // Return empty array for now
    }

    func updateTrackedItem(_ item: TrackedItem) async throws {
        try await saveTrackedItem(item) // CloudKit upserts on save
    }

    func deleteTrackedItem(id: UUID) async throws {
        guard isSignedIn else {
            throw CloudKitError.notSignedIn
        }

        syncStatus = .syncing

        do {
            let recordID = CKRecord.ID(recordName: id.uuidString)
            _ = try await privateDatabase.deleteRecord(withID: recordID)
            syncStatus = .success
        } catch {
            syncStatus = .failed(error)
            throw error
        }
    }

    // MARK: - Batch Operations

    func syncAllItems(_ items: [TrackedItem]) async throws {
        guard isSignedIn else {
            throw CloudKitError.notSignedIn
        }

        syncStatus = .syncing
         // TODO: Implement CloudKit batch sync once TrackedItem CloudKit methods are restored
        /*
        let records = items.map { $0.toCKRecord() }
        
        // Batch save records
        let operation = CKModifyRecordsOperation(recordsToSave: records)
        operation.savePolicy = .changedKeys
        operation.qualityOfService = .userInitiated
        
        return try await withCheckedThrowingContinuation { continuation in
            operation.modifyRecordsResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            
            privateDatabase.add(operation)
        }
        */
        syncStatus = .success
    }
    
    // MARK: - Share Extension Support
    
    func checkForSharedItems() {
        // This method can be called when the main app becomes active
        // to check if any new items were added via the Share Extension
        // and potentially trigger a refresh of the UI
        NotificationCenter.default.post(name: .sharedItemsAdded, object: nil)
    }
}

extension Notification.Name {
    static let sharedItemsAdded = Notification.Name("sharedItemsAdded")
}

// MARK: - CloudKit Errors
enum CloudKitError: LocalizedError {
    case notSignedIn
    case networkUnavailable
    case quotaExceeded
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .notSignedIn:
            return "Please sign in to iCloud to sync your tracked items."
        case .networkUnavailable:
            return "Network connection is unavailable. Please check your internet connection."
        case .quotaExceeded:
            return "iCloud storage quota exceeded. Please free up space or upgrade your plan."
        case .unknown(let error):
            return "An unexpected error occurred: \(error.localizedDescription)"
        }
    }
}
