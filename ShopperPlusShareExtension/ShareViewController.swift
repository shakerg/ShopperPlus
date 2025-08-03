//
//  ShareViewController.swift
//  ShopperPlusShareExtension
//
//  Created by Shaker Gilbert on 8/1/25.
//

import UIKit
import Social
import CoreData
import CloudKit

class ShareViewController: SLComposeServiceViewController {

    private var persistentContainer: NSPersistentContainer!
    private var sharedURL: URL?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCoreData()
        setupUI()
        extractSharedURL()
    }

    private func setupCoreData() {
        // Create persistent container
        persistentContainer = NSPersistentContainer(name: "ShopperPlus")

        // Use App Group container for shared data access
        if let appGroupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.VuWing-Corp.ShopperPlus") {
            let storeURL = appGroupURL.appendingPathComponent("ShopperPlus.sqlite")
            let storeDescription = NSPersistentStoreDescription(url: storeURL)
            persistentContainer.persistentStoreDescriptions = [storeDescription]
        }

        persistentContainer.loadPersistentStores { [weak self] _, error in
            if let error = error {
                print("Core Data error: \(error)")
                DispatchQueue.main.async {
                    self?.showError("Unable to access app data")
                }
            }
        }
    }

    private func setupUI() {
        title = "Add to Shopper+"
        placeholder = "Add notes about this item (optional)"
    }

    private func extractSharedURL() {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let itemProviders = extensionItem.attachments else {
            showError("No content found to share")
            return
        }

        for provider in itemProviders {
            if provider.hasItemConformingToTypeIdentifier("public.url") {
                provider.loadItem(forTypeIdentifier: "public.url", options: nil) { [weak self] (data, _) in
                    DispatchQueue.main.async {
                        if let url = data as? URL {
                            self?.processURL(url)
                        } else {
                            self?.showError("Unable to process the shared URL")
                        }
                    }
                }
                return
            }
        }

        showError("No valid URL found")
    }

    private func processURL(_ url: URL) {
        // Check if it's a supported retailer
        if SharedAffiliateManager.shared.isSupportedRetailer(url) {
            self.sharedURL = url
            if let retailerName = SharedAffiliateManager.shared.getRetailerName(url) {
                title = "Add \(retailerName) Product"
            }
        } else {
            showError("This retailer is not currently supported")
        }
    }

    override func didSelectPost() {
        guard let url = sharedURL else {
            showError("No URL to save")
            return
        }

        // Show loading state
        textView.text = "Adding to Shopper+..."
        textView.isEditable = false

        // Process the URL with affiliate tagging
        let affiliateURL = SharedAffiliateManager.shared.normalizeAndTag(url: url)

        // Save to Core Data
        saveTrackedItem(url: affiliateURL, notes: contentText) { [weak self] success in
            DispatchQueue.main.async {
                if success {
                    self?.showSuccess()
                } else {
                    self?.showError("Failed to save item")
                }
            }
        }
    }

    private func saveTrackedItem(url: URL, notes: String, completion: @escaping (Bool) -> Void) {
        guard let context = persistentContainer?.viewContext else {
            completion(false)
            return
        }

        // Create a new TrackedItem entity
        let entity = NSEntityDescription.entity(forEntityName: "TrackedItem", in: context)!
        let trackedItem = NSManagedObject(entity: entity, insertInto: context)

        // Set properties
        trackedItem.setValue(UUID(), forKey: "id")
        trackedItem.setValue(url.absoluteString, forKey: "url")
        trackedItem.setValue(notes.isEmpty ? "Shared from \(SharedAffiliateManager.shared.getRetailerName(url) ?? "app")" : notes, forKey: "title")
        trackedItem.setValue(Date(), forKey: "dateAdded")
        trackedItem.setValue(Date(), forKey: "lastUpdated")
        trackedItem.setValue(true, forKey: "isActive")
        trackedItem.setValue("USD", forKey: "currency")
        trackedItem.setValue(0.0, forKey: "currentPrice")
        trackedItem.setValue(0.0, forKey: "targetPrice")

        do {
            try context.save()

            // Attempt CloudKit sync (optional, best effort)
            syncToCloudKit(trackedItem: trackedItem)

            completion(true)
        } catch {
            print("Failed to save tracked item: \(error)")
            completion(false)
        }
    }

    private func syncToCloudKit(trackedItem: NSManagedObject) {
        // This is a simplified sync - in a real app you'd want more robust error handling
        let container = CKContainer(identifier: "iCloud.VuWing-Corp.ShopperPlus")
        let privateDatabase = container.privateCloudDatabase

        let record = CKRecord(recordType: "TrackedItem")
        record["id"] = trackedItem.value(forKey: "id") as? String ?? UUID().uuidString
        record["url"] = trackedItem.value(forKey: "url") as? String
        record["title"] = trackedItem.value(forKey: "title") as? String
        record["dateAdded"] = trackedItem.value(forKey: "dateAdded") as? Date
        record["lastUpdated"] = trackedItem.value(forKey: "lastUpdated") as? Date
        record["isActive"] = (trackedItem.value(forKey: "isActive") as? Bool) ?? true
        record["currency"] = trackedItem.value(forKey: "currency") as? String ?? "USD"
        record["currentPrice"] = trackedItem.value(forKey: "currentPrice") as? Double ?? 0.0
        record["targetPrice"] = trackedItem.value(forKey: "targetPrice") as? Double ?? 0.0

        privateDatabase.save(record) { _, error in
            if let error = error {
                print("CloudKit sync error: \(error)")
            } else {
                print("Successfully synced to CloudKit")
            }
        }
    }

    private func showSuccess() {
        textView.text = "✅ Added to Shopper+"
        textView.isEditable = false

        // Auto-dismiss after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        }
    }

    private func showError(_ message: String) {
        textView.text = "❌ \(message)"
        textView.isEditable = false

        // Auto-dismiss after 3 seconds to give user time to read error
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.extensionContext?.cancelRequest(withError: NSError(domain: "ShareExtension", code: 1, userInfo: [NSLocalizedDescriptionKey: message]))
        }
    }

    override func isContentValid() -> Bool {
        return sharedURL != nil
    }

    override func configurationItems() -> [Any]! {
        return []
    }
}
