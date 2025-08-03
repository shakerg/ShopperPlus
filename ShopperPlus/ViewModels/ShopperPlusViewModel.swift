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

        Task {
            do {
                isLoading = true

                // Fetch product info from backend
                let productInfo = try await networkingService.fetchProductInfo(from: url)

                // Create new tracked item
                let newItem = TrackedItem(
                    context: viewContext,
                    title: productInfo.title,
                    url: url,
                    imageUrl: productInfo.imageUrl,
                    currentPrice: productInfo.price,
                    currency: productInfo.currency
                )

                // Add initial price entry if available
                if let price = productInfo.price {
                    let priceEntry = PriceEntry(
                        price: price,
                        currency: productInfo.currency,
                        timestamp: productInfo.lastUpdated,
                        source: .backend
                    )
                    newItem.priceHistory = [priceEntry]
                }

                // Save to CloudKit
                try await cloudKitManager.saveTrackedItem(newItem)

                // Update local array
                trackedItems.append(newItem)
                showingAddItemSheet = false
                error = nil

            } catch {
                print("❌ Failed to add item from URL: \(url), Error: \(error)")
                
                if let networkingError = error as? NetworkingError {
                    switch networkingError {
                    case .timeout:
                        self.error = .networkError("Amazon URLs can take 1-2 minutes to process. Please keep the app open and try again.")
                    case .connectionLost:
                        self.error = .networkError("Connection lost. Please check your internet and try again.")
                    case .noInternet:
                        self.error = .networkError("No internet connection. Please check your network settings.")
                    case .serverError(let code) where code >= 500:
                        self.error = .networkError("Server is temporarily unavailable. Please try again in a few minutes.")
                    default:
                        self.error = .networkError(networkingError.localizedDescription)
                    }
                } else {
                    self.error = .general(error.localizedDescription)
                }
            }
            isLoading = false
        }
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

                // Get price updates from backend
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
