//
//  NotificationSettings.swift
//  ShopperPlus
//
//  Created by Shaker Gilbert on 7/31/25.
//

import Foundation

struct NotificationSettings: Codable {
    var priceDropEnabled: Bool
    var targetPriceEnabled: Bool
    var percentageThreshold: Double
    var checkFrequency: CheckFrequency

    init(
        priceDropEnabled: Bool = true,
        targetPriceEnabled: Bool = true,
        percentageThreshold: Double = 10.0,
        checkFrequency: CheckFrequency = .daily
    ) {
        self.priceDropEnabled = priceDropEnabled
        self.targetPriceEnabled = targetPriceEnabled
        self.percentageThreshold = percentageThreshold
        self.checkFrequency = checkFrequency
    }
}

enum CheckFrequency: String, Codable, CaseIterable {
    case realtime = "realtime"
    case hourly = "hourly"
    case daily = "daily"
    case weekly = "weekly"

    var displayName: String {
        switch self {
        case .realtime:
            return "Real-time"
        case .hourly:
            return "Every Hour"
        case .daily:
            return "Daily"
        case .weekly:
            return "Weekly"
        }
    }

    var timeInterval: TimeInterval {
        switch self {
        case .realtime:
            return 300 // 5 minutes for "real-time"
        case .hourly:
            return 3600 // 1 hour
        case .daily:
            return 86400 // 24 hours
        case .weekly:
            return 604800 // 7 days
        }
    }
}

// MARK: - UserSettings
struct UserSettings: Codable {
    var defaultCurrency: String
    var defaultNotificationSettings: NotificationSettings
    var syncEnabled: Bool
    var backgroundRefreshEnabled: Bool

    init(
        defaultCurrency: String = "USD",
        defaultNotificationSettings: NotificationSettings = NotificationSettings(),
        syncEnabled: Bool = true,
        backgroundRefreshEnabled: Bool = true
    ) {
        self.defaultCurrency = defaultCurrency
        self.defaultNotificationSettings = defaultNotificationSettings
        self.syncEnabled = syncEnabled
        self.backgroundRefreshEnabled = backgroundRefreshEnabled
    }
}

// MARK: - BarcodeEntry (for future barcode support)
struct BarcodeEntry: Identifiable, Codable {
    let id: UUID
    let barcode: String
    let format: BarcodeFormat
    let associatedItemId: UUID?
    let dateScanned: Date

    init(
        id: UUID = UUID(),
        barcode: String,
        format: BarcodeFormat,
        associatedItemId: UUID? = nil,
        dateScanned: Date = Date()
    ) {
        self.id = id
        self.barcode = barcode
        self.format = format
        self.associatedItemId = associatedItemId
        self.dateScanned = dateScanned
    }
}

enum BarcodeFormat: String, Codable, CaseIterable {
    case upcA = "UPC-A"
    case upcE = "UPC-E"
    case ean8 = "EAN-8"
    case ean13 = "EAN-13"
    case code39 = "Code 39"
    case code128 = "Code 128"
    case qr = "QR Code"
    case dataMatrix = "Data Matrix"
    case unknown = "Unknown"
}
