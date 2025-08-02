//
//  PriceEntry.swift
//  ShopperPlus
//
//  Created by Shaker Gilbert on 7/31/25.
//

import Foundation

struct PriceEntry: Identifiable, Codable {
    let id: UUID
    let price: Double
    let currency: String
    let timestamp: Date
    let source: PriceSource

    init(
        id: UUID = UUID(),
        price: Double,
        currency: String = "USD",
        timestamp: Date = Date(),
        source: PriceSource = .unknown
    ) {
        self.id = id
        self.price = price
        self.currency = currency
        self.timestamp = timestamp
        self.source = source
    }
}

enum PriceSource: String, Codable, CaseIterable {
    case local = "local"
    case backend = "backend"
    case manual = "manual"
    case unknown = "unknown"

    var displayName: String {
        switch self {
        case .local:
            return "Local Check"
        case .backend:
            return "Backend"
        case .manual:
            return "Manual Entry"
        case .unknown:
            return "Unknown"
        }
    }
}

// MARK: - PriceEntry Extensions
extension PriceEntry {
    /// Formatted price string
    var formattedPrice: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: NSNumber(value: price)) ?? "\(currency) \(price)"
    }

    /// Relative timestamp string
    var relativeTimestamp: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
}

// MARK: - Array Extensions for Price History
extension Array where Element == PriceEntry {
    /// Get the most recent price entry
    var mostRecent: PriceEntry? {
        return self.sorted { $0.timestamp > $1.timestamp }.first
    }

    /// Get the lowest price entry
    var lowest: PriceEntry? {
        return self.min { $0.price < $1.price }
    }

    /// Get the highest price entry
    var highest: PriceEntry? {
        return self.max { $0.price < $1.price }
    }

    /// Calculate price change percentage from first to last entry
    var priceChangePercentage: Double? {
        guard let first = self.sorted(by: { $0.timestamp < $1.timestamp }).first,
              let last = self.sorted(by: { $0.timestamp < $1.timestamp }).last,
              first.price > 0 else {
            return nil
        }

        return ((last.price - first.price) / first.price) * 100
    }

    /// Get entries from the last N days
    func entries(fromLastDays days: Int) -> [PriceEntry] {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return self.filter { $0.timestamp >= cutoffDate }
    }
}
