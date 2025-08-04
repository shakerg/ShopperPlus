//
//  TrackedItemRowView.swift
//  ShopperPlus
//
//  Created by Shaker Gilbert on 7/31/25.
//

import SwiftUI

struct TrackedItemRowView: View {
    let item: TrackedItem

    // Computed property to detect if item is in loading state
    private var isLoadingItem: Bool {
        guard let title = item.title else { return false }
        return title.hasPrefix("Loading") ||
               title.hasPrefix("Retrying") ||
               title.hasPrefix("Failed to load")
    }

    var body: some View {
        HStack(spacing: 12) {
            // Product Image
            AsyncImage(url: URL(string: item.imageUrl ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundColor(.gray)
                            .font(.title2)
                    }
            }
            .frame(width: 60, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                // Product Title with loading indicator
                HStack {
                    Text(item.title ?? "Untitled Item")
                        .font(.headlineRoboto)
                        .lineLimit(2)
                        .foregroundColor(.primary)

                    // Show loading indicator for placeholder items
                    if isLoadingItem {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 16, height: 16)
                    }
                }

                // Current Price
                if isLoadingItem {
                    Text("Analyzing product... This may take up to 2 minutes for Amazon")
                        .font(.bodyRoboto)
                        .foregroundColor(.secondary)
                } else if item.currentPrice > 0 {
                    Text(formatPrice(item.currentPrice, currency: item.currency ?? "USD"))
                        .font(.title3Roboto)
                        .foregroundColor(.green)
                } else {
                    Text("Price unavailable")
                        .font(.bodyRoboto)
                        .foregroundColor(.secondary)
                }

                // Price Change Indicator or Loading Status
                if isLoadingItem {
                    Text("Scraping product info from retailer...")
                        .font(.caption1Roboto)
                        .foregroundColor(.orange)
                } else if let priceChange = calculatePriceChange() {
                    HStack(spacing: 4) {
                        Image(systemName: priceChange.isPositive ? "arrow.up" : "arrow.down")
                            .font(.caption1Roboto)
                        Text(priceChange.formattedPercentage)
                            .font(.caption1Roboto)
                    }
                    .foregroundColor(priceChange.isPositive ? .red : .green)
                }

                // Last Updated
                Text("Updated \((item.lastUpdated ?? Date()).timeAgoDisplay)")
                    .font(.caption2Roboto)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Target Price Indicator
            if item.targetPrice > 0 {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Target")
                        .font(.caption2Roboto)
                        .foregroundColor(.secondary)

                    Text(formatPrice(item.targetPrice, currency: item.currency ?? "USD"))
                        .font(.caption1Roboto)
                        .foregroundColor(.blue)

                    if item.currentPrice > 0 {
                        let isAtTarget = item.currentPrice <= item.targetPrice
                        Image(systemName: isAtTarget ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(isAtTarget ? .green : .gray)
                            .font(.caption1Roboto)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func formatPrice(_ price: Double, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: NSNumber(value: price)) ?? "\(currency) \(price)"
    }

    private func calculatePriceChange() -> PriceChange? {
        guard item.priceHistory.count >= 2 else { return nil }

        let sortedHistory = item.priceHistory.sorted { $0.timestamp < $1.timestamp }
        guard let first = sortedHistory.first,
              let last = sortedHistory.last,
              first.price > 0 else { return nil }

        let change = ((last.price - first.price) / first.price) * 100
        return PriceChange(percentage: change, isPositive: change > 0)
    }
}

struct PriceChange {
    let percentage: Double
    let isPositive: Bool

    var formattedPercentage: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 1

        let absPercentage = abs(percentage) / 100
        return formatter.string(from: NSNumber(value: absPercentage)) ?? "\(String(format: "%.1f", abs(percentage)))%"
    }
}

// MARK: - Date Extensions
extension Date {
    var timeAgoDisplay: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext

    let item1 = TrackedItem(context: context,
                           title: "Apple iPhone 15 Pro",
                           url: "https://example.com/iphone-15-pro",
                           imageUrl: "https://via.placeholder.com/150",
                           currentPrice: 999.99,
                           currency: "USD",
                           targetPrice: 899.99)

    let item2 = TrackedItem(context: context,
                           title: "Sony WH-1000XM5 Wireless Noise Canceling Headphones",
                           url: "https://example.com/sony-headphones",
                           currentPrice: 349.99,
                           currency: "USD")

    return List {
        TrackedItemRowView(item: item1)
        TrackedItemRowView(item: item2)
    }
}
