//
//  ShopperPlusViewModel.swift
//  ShopperPlus
//
//  Created by Shaker Gilbert on 7/31/25.
//

import Foundation
import Combine
import SwiftUI
import CoreData

@MainActor
class ShopperPlusViewModel: ObservableObject {
    @Published var trackedItems: [TrackedItem] = []
    @Published var isLoading = false
    @Published var error: AppError?
    @Published var showingAddItemSheet = false
    @Published var searchText = ""

    private let cloudKitManager = CloudKitManager.shared
    private let networkingService = NetworkingService.shared
    private let viewContext = PersistenceController.shared.container.viewContext
    private var cancellables = Set<AnyCancellable>()

    init() {
        setupBindings()
        loadTrackedItems()
    }

    private func setupBindings() {
        // Observe CloudKit sync status
        cloudKitManager.$syncStatus
            .sink { [weak self] status in
                switch status {
                case .syncing:
                    self?.isLoading = true
                case .success:
                    self?.isLoading = false
                    self?.error = nil
                case .failed(let error):
                    self?.isLoading = false
                    self?.error = .cloudKitError(error.localizedDescription)
                case .idle:
                    self?.isLoading = false
                }
            }
            .store(in: &cancellables)

        // Observe network status
        networkingService.$isOnline
            .sink { [weak self] isOnline in
                if !isOnline {
                    self?.error = .networkError("No internet connection")
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Data Loading

    func loadTrackedItems() {
        Task {
            do {
                isLoading = true
                trackedItems = try await cloudKitManager.fetchTrackedItems()
                error = nil
            } catch {
                self.error = .cloudKitError(error.localizedDescription)
            }
            isLoading = false
        }
    }

    // MARK: - Item Management

    func addItem(from url: String) {
        guard isValidURL(url) else {
            error = .invalidURL
            return
        }

        // Extract domain for initial title
        let domain = extractDomain(from: url)

        // Step 1: Create and store item immediately with placeholder data
        let newItem = TrackedItem(
            context: viewContext,
            title: "Loading \(domain)...",
            url: url,
            imageUrl: nil,
            currentPrice: nil,
            currency: "USD",
            targetPrice: nil,
            isActive: true
        )

        // Step 2: Save immediately to CloudKit and update UI
        Task {
            do {
                // Save to CloudKit immediately
                try await cloudKitManager.saveTrackedItem(newItem)

                // Update local array and close sheet immediately
                trackedItems.append(newItem)
                showingAddItemSheet = false
                error = nil

                print("✅ Item stored immediately, starting background fetch...")

                // Step 3: Start background fetch without blocking UI
                fetchProductInfoInBackground(for: newItem, url: url)

            } catch {
                print("❌ Failed to save item immediately: \(error)")
                // Remove the item from local array if CloudKit save failed
                if let index = trackedItems.firstIndex(where: { $0.id == newItem.id }) {
                    trackedItems.remove(at: index)
                }
                self.error = .cloudKitError(error.localizedDescription)
            }
        }
    }

    private func fetchProductInfoInBackground(for item: TrackedItem, url: String) {
        Task {
            do {
                print("🔄 Background fetch starting for: \(url)")

                // Fetch product info from backend in background
                let productInfo = try await networkingService.fetchProductInfo(from: url)

                // Update the existing item with real data
                item.title = productInfo.title
                item.imageUrl = productInfo.imageUrl
                item.currentPrice = productInfo.price ?? 0.0
                item.currency = productInfo.currency
                item.lastUpdated = productInfo.lastUpdated

                // Add initial price entry if available
                if let price = productInfo.price {
                    let priceEntry = PriceEntry(
                        price: price,
                        currency: productInfo.currency,
                        timestamp: productInfo.lastUpdated,
                        source: .backend
                    )
                    item.priceHistory = [priceEntry]
                }

                // Save updated item to CloudKit
                try await cloudKitManager.saveTrackedItem(item)

                print("✅ Background fetch completed for: \(productInfo.title)")

            } catch {
                print("⚠️ Background fetch failed for: \(url), Error: \(error)")

                // Update item to show fetch failed
                item.title = "Failed to load \(extractDomain(from: url))"

                // Try to save the error state
                try? await cloudKitManager.saveTrackedItem(item)

                // Don't show error to user since item is already added
                // User can manually refresh later if needed
            }
        }
    }

    private func extractDomain(from url: String) -> String {
        guard let urlComponents = URLComponents(string: url),
              let host = urlComponents.host else {
            return "product"
        }

        // Remove www. and common subdomains
        let domain = host.replacingOccurrences(of: "^www\\.", with: "", options: .regularExpression)

        // Extract main domain name (e.g., "amazon.com" -> "Amazon")
        let parts = domain.components(separatedBy: ".")
        if let mainDomain = parts.first {
            return mainDomain.capitalized
        }

        return domain
    }

    func deleteItem(_ item: TrackedItem) {
        Task {
            do {
                try await cloudKitManager.deleteTrackedItem(id: item.id ?? UUID())
                trackedItems.removeAll { $0.id == item.id }
                error = nil
            } catch {
                self.error = .cloudKitError(error.localizedDescription)
            }
        }
    }

    func updateItem(_ item: TrackedItem) {
        Task {
            do {
                try await cloudKitManager.updateTrackedItem(item)

                // Update local array
                if let index = trackedItems.firstIndex(where: { $0.id == item.id }) {
                    trackedItems[index] = item
                }
                error = nil
            } catch {
                self.error = .cloudKitError(error.localizedDescription)
            }
        }
    }

    // MARK: - Sync Operations

    func syncNow() {
        Task {
            do {
                isLoading = true

                // First, retry any failed items (items with "Loading..." or "Failed to load" titles)
                await retryFailedItems()

                // Then get price updates from backend
                let updates = try await networkingService.syncPrices(for: trackedItems)

                // Apply updates to tracked items
                for update in updates where update.success {
                    if let index = trackedItems.firstIndex(where: { $0.id?.uuidString == update.id }),
                       let price = update.price {

                        // Update the tracked item directly in the array
                        trackedItems[index].currentPrice = price
                        trackedItems[index].lastUpdated = update.lastUpdated

                        // Add new price entry
                        let priceEntry = PriceEntry(
                            price: price,
                            currency: update.currency,
                            timestamp: update.lastUpdated,
                            source: .backend
                        )
                        trackedItems[index].priceHistory.append(priceEntry)
                    }
                }

                // Sync updated items back to CloudKit
                try await cloudKitManager.syncAllItems(trackedItems)

                error = nil
            } catch {
                if error is NetworkingError {
                    self.error = .networkError(error.localizedDescription)
                } else {
                    self.error = .general(error.localizedDescription)
                }
            }
            isLoading = false
        }
    }

    private func retryFailedItems() async {
        let failedItems = trackedItems.filter { item in
            item.title?.hasPrefix("Loading") == true ||
            item.title?.hasPrefix("Failed to load") == true
        }

        guard !failedItems.isEmpty else { return }

        print("🔄 Retrying \(failedItems.count) failed items...")

        for item in failedItems {
            guard let url = item.url else { continue }

            // Update title to show retrying
            item.title = "Retrying \(extractDomain(from: url))..."

            // Retry the background fetch
            fetchProductInfoInBackground(for: item, url: url)
        }
    }

    // MARK: - Filtering and Search

    var filteredItems: [TrackedItem] {
        if searchText.isEmpty {
            return trackedItems.filter { $0.isActive }
        } else {
            return trackedItems.filter { item in
                item.isActive && (
                    item.title?.localizedCaseInsensitiveContains(searchText) == true ||
                    item.url?.localizedCaseInsensitiveContains(searchText) == true
                )
            }
        }
    }

    // MARK: - Utility Functions

    private func isValidURL(_ string: String) -> Bool {
        guard let url = URL(string: string) else { return false }
        return url.scheme?.hasPrefix("http") == true
    }

    func dismissError() {
        error = nil
    }
}

// MARK: - App Errors

enum AppError: LocalizedError, Identifiable {
    case invalidURL
    case networkError(String)
    case cloudKitError(String)
    case general(String)

    var id: String {
        switch self {
        case .invalidURL:
            return "invalidURL"
        case .networkError(let message):
            return "networkError-\(message)"
        case .cloudKitError(let message):
            return "cloudKitError-\(message)"
        case .general(let message):
            return "general-\(message)"
        }
    }

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Please enter a valid product URL"
        case .networkError(let message):
            return "Network Error: \(message)"
        case .cloudKitError(let message):
            return "Sync Error: \(message)"
        case .general(let message):
            return message
        }
    }

    var title: String {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .networkError:
            return "Network Error"
        case .cloudKitError:
            return "Sync Error"
        case .general:
            return "Error"
        }
    }
}
