//
//  TrackedItem.swift
//  ShopperPlus
//
//  Created by Shaker Gilbert on 7/31/25.
//

import Foundation
import CoreData

// MARK: - TrackedItem Core Data Extensions
extension TrackedItem {

    public override func awakeFromInsert() {
        super.awakeFromInsert()

        // Set default values for required attributes
        if self.id == nil {
            self.id = UUID()
        }
        let now = Date()
        if self.dateAdded == nil {
            self.dateAdded = now
        }
        if self.lastUpdated == nil {
            self.lastUpdated = now
        }
        if self.currency?.isEmpty != false {
            self.currency = "USD"
        }
        if self.title?.isEmpty != false {
            self.title = ""
        }
        if self.url?.isEmpty != false {
            self.url = ""
        }
    }

    var priceHistory: [PriceEntry] {
        get {
            guard let data = priceHistoryData else { return [] }
            return (try? JSONDecoder().decode([PriceEntry].self, from: data)) ?? []
        }
        set {
            priceHistoryData = try? JSONEncoder().encode(newValue)
        }
    }

    var notificationSettings: NotificationSettings {
        get {
            guard let data = notificationSettingsData else { return NotificationSettings() }
            return (try? JSONDecoder().decode(NotificationSettings.self, from: data)) ?? NotificationSettings()
        }
        set {
            notificationSettingsData = try? JSONEncoder().encode(newValue)
        }
    }

    convenience init(context: NSManagedObjectContext,
                    title: String,
                    url: String,
                    imageUrl: String? = nil,
                    currentPrice: Double? = nil,
                    currency: String = "USD",
                    targetPrice: Double? = nil,
                    isActive: Bool = true) {
        self.init(context: context)
        self.title = title
        self.url = url
        self.imageUrl = imageUrl
        self.currentPrice = currentPrice ?? 0.0
        self.currency = currency
        self.targetPrice = targetPrice ?? 0.0
        self.isActive = isActive
        self.priceHistory = []
        self.notificationSettings = NotificationSettings()
    }

    func addPriceEntry(_ entry: PriceEntry) {
        var history = priceHistory
        history.append(entry)
        priceHistory = history
        lastUpdated = Date()
        currentPrice = entry.price
    }

    func updatePrice(_ newPrice: Double) {
        let entry = PriceEntry(price: newPrice, timestamp: Date(), source: .backend)
        addPriceEntry(entry)
    }

}
