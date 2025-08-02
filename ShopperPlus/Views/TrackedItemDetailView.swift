//
//  TrackedItemDetailView.swift
//  ShopperPlus
//
//  Created by Shaker Gilbert on 7/31/25.
//

import SwiftUI
import Charts

struct TrackedItemDetailView: View {
    @EnvironmentObject var viewModel: ShopperPlusViewModel
    let item: TrackedItem

    @State private var showingNotificationSettings = false
    @State private var showingDeleteConfirmation = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Product Header
                ProductHeaderView(item: item)

                // Current Price Section
                CurrentPriceView(item: item)

                // Price History Chart
                if !item.priceHistory.isEmpty {
                    PriceHistoryChartView(priceHistory: item.priceHistory)
                }

                // Quick Stats
                QuickStatsView(item: item)

                // Action Buttons
                ActionButtonsView(
                    item: item,
                    onNotificationSettings: { showingNotificationSettings = true },
                    onDelete: { showingDeleteConfirmation = true }
                )
            }
            .padding()
        }
        .shopperPlusNavigationHeader()
        .navigationTitle(item.title ?? "Item Details")
        .font(.bodyRoboto)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { showingNotificationSettings = true }) {
                        Label("Notification Settings", systemImage: "bell")
                    }

                    Button(action: shareItem) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }

                    Button(action: openInBrowser) {
                        Label("Open in Browser", systemImage: "safari")
                    }

                    Button(action: { showingDeleteConfirmation = true }) {
                        Label("Delete", systemImage: "trash")
                    }
                    .foregroundColor(.red)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingNotificationSettings) {
            NotificationSettingsSheet(item: item)
                .environmentObject(viewModel)
        }
        .alert("Delete Item", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                viewModel.deleteItem(item)
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to stop tracking \"\(item.title ?? "this item")\"?")
        }
    }

    private func shareItem() {
        let activityController = UIActivityViewController(
            activityItems: [item.url ?? ""],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityController, animated: true)
        }
    }

    private func openInBrowser() {
        if let url = URL(string: item.url ?? "") {
            UIApplication.shared.open(url)
        }
    }
}

struct ProductHeaderView: View {
    let item: TrackedItem

    var body: some View {
        VStack(spacing: 16) {
            // Product Image
            AsyncImage(url: URL(string: item.imageUrl ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.3))
                    .overlay {
                        Image(systemName: "photo")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                    }
            }
            .frame(height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Product Title
            Text(item.title ?? "Untitled Item")
                .font(.title2Roboto)
                .multilineTextAlignment(.center)
                .foregroundColor(.primary)
        }
    }
}

struct CurrentPriceView: View {
    let item: TrackedItem

    var body: some View {
        VStack(spacing: 12) {
            if item.currentPrice > 0 {
                Text(formatPrice(item.currentPrice, currency: item.currency ?? "USD"))
                    .font(.largeTitleRoboto)
                    .foregroundColor(.green)

                if item.targetPrice > 0 {
                    HStack {
                        Text("Target:")
                        Text(formatPrice(item.targetPrice, currency: item.currency ?? "USD"))
                            .font(.title3Roboto)
                            .foregroundColor(.blue)

                        if item.currentPrice <= item.targetPrice {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                    .font(.bodyRoboto)
                }
            } else {
                Text("Price Unavailable")
                    .font(.title2Roboto)
                    .foregroundColor(.secondary)
            }

            Text("Last updated: \((item.lastUpdated ?? Date()).formatted(date: .abbreviated, time: .shortened))")
                .font(.caption1Roboto)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private func formatPrice(_ price: Double, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: NSNumber(value: price)) ?? "\(currency) \(price)"
    }
}

struct PriceHistoryChartView: View {
    let priceHistory: [PriceEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Price History")
                .font(.headlineRoboto)
                .foregroundColor(.primary)

            if #available(iOS 16.0, *) {
                Chart(priceHistory.sorted { $0.timestamp < $1.timestamp }) { entry in
                    LineMark(
                        x: .value("Date", entry.timestamp),
                        y: .value("Price", entry.price)
                    )
                    .foregroundStyle(.blue)

                    PointMark(
                        x: .value("Date", entry.timestamp),
                        y: .value("Price", entry.price)
                    )
                    .foregroundStyle(.blue)
                }
                .frame(height: 200)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            } else {
                // Fallback for iOS 15
                Text("Price chart requires iOS 16+")
                    .font(.bodyRoboto)
                    .foregroundColor(.secondary)
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
            }
        }
    }
}

struct QuickStatsView: View {
    let item: TrackedItem

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Statistics")
                .font(.headlineRoboto)
                .foregroundColor(.primary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                StatCard(
                    title: "Lowest Price",
                    value: item.priceHistory.lowest?.formattedPrice ?? "N/A",
                    color: .green
                )

                StatCard(
                    title: "Highest Price",
                    value: item.priceHistory.highest?.formattedPrice ?? "N/A",
                    color: .red
                )

                StatCard(
                    title: "Price Checks",
                    value: "\(item.priceHistory.count)",
                    color: .blue
                )

                StatCard(
                    title: "Days Tracked",
                    value: "\(daysSinceAdded)",
                    color: .purple
                )
            }
        }
    }

    private var daysSinceAdded: Int {
        Calendar.current.dateComponents([.day], from: item.dateAdded ?? Date(), to: Date()).day ?? 0
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption1Roboto)
                .foregroundColor(.secondary)

            Text(value)
                .font(.title3Roboto)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct ActionButtonsView: View {
    let item: TrackedItem
    let onNotificationSettings: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Button(action: onNotificationSettings) {
                HStack {
                    Image(systemName: "bell")
                    Text("Notification Settings")
                        .font(.bodyRoboto)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(10)
            }

            Button(action: onDelete) {
                HStack {
                    Image(systemName: "trash")
                    Text("Stop Tracking")
                        .font(.bodyRoboto)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red)
                .cornerRadius(10)
            }
        }
    }
}

// Placeholder for NotificationSettingsSheet
struct NotificationSettingsSheet: View {
    @EnvironmentObject var viewModel: ShopperPlusViewModel
    @Environment(\.dismiss) private var dismiss
    let item: TrackedItem

    var body: some View {
        NavigationStack {
            VStack {
                Text("Notification Settings")
                    .font(.title2Roboto)
                Text("Coming soon...")
                    .font(.bodyRoboto)
                    .foregroundColor(.secondary)
            }
            .shopperPlusNavigationHeader()
            .navigationTitle("Notifications")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext

    let item = TrackedItem(context: context,
                          title: "Apple iPhone 15 Pro",
                          url: "https://example.com/iphone",
                          imageUrl: "https://via.placeholder.com/300",
                          currentPrice: 999.99,
                          currency: "USD",
                          targetPrice: 899.99)

    // Add some price history
    item.addPriceEntry(PriceEntry(price: 1099.99, timestamp: Date().addingTimeInterval(-86400)))
    item.addPriceEntry(PriceEntry(price: 1049.99, timestamp: Date().addingTimeInterval(-43200)))
    item.addPriceEntry(PriceEntry(price: 999.99, timestamp: Date()))

    return NavigationStack {
        TrackedItemDetailView(item: item)
            .environmentObject(ShopperPlusViewModel())
    }
}
