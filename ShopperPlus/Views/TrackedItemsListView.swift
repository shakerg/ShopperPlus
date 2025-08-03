//
//  TrackedItemsListView.swift
//  ShopperPlus
//
//  Created by Shaker Gilbert on 7/31/25.
//

import SwiftUI

struct TrackedItemsListView: View {
    @EnvironmentObject var viewModel: ShopperPlusViewModel
    @ObservedObject private var networkingService = NetworkingService.shared
    @State private var showingAPITest = false

    var body: some View {
        Group {
            if viewModel.trackedItems.isEmpty && !viewModel.isLoading {
                EmptyStateView()
            } else {
                List {
                    ForEach(viewModel.filteredItems) { item in
                        NavigationLink(destination: TrackedItemDetailView(item: item)) {
                            TrackedItemRowView(item: item)
                        }
                    }
                    .onDelete(perform: deleteItems)
                }
                .refreshable {
                    viewModel.syncNow()
                }
            }
        }
        .shopperPlusNavigationHeader()
        .navigationTitle("Tracked Items")
        .searchable(text: $viewModel.searchText, prompt: "Search tracked items")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    viewModel.showingAddItemSheet = true
                }) {
                    Image(systemName: "plus")
                        .font(.headlineRoboto)
                }
            }

            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    viewModel.syncNow()
                }) {
                    HStack {
                        if viewModel.isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.bodyRoboto)
                        }
                        Text("Sync")
                            .font(.bodyRoboto)
                    }
                }
                .disabled(viewModel.isLoading)
            }
        }
        .sheet(isPresented: $viewModel.showingAddItemSheet) {
            AddItemSheet()
                .environmentObject(viewModel)
        }
        .overlay {
            if viewModel.isLoading && viewModel.trackedItems.isEmpty {
                ProgressView("Loading...")
                    .font(.bodyRoboto)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
            }
        }
        .overlay(alignment: .bottom) {
            // Network status banner
            if !networkingService.isOnline {
                NetworkStatusBanner {
                    showingAPITest = true
                }
            }
        }
        .sheet(isPresented: $showingAPITest) {
            APITestView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private func deleteItems(offsets: IndexSet) {
        for index in offsets {
            let item = viewModel.filteredItems[index]
            viewModel.deleteItem(item)
        }
    }
}

struct NetworkStatusBanner: View {
    let onTestTap: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "wifi.slash")
                .foregroundColor(.white)

            VStack(alignment: .leading, spacing: 2) {
                Text("Network Issue")
                    .font(.bodyRoboto)
                    .fontWeight(.medium)
                    .foregroundColor(.white)

                Text("Check your connection or test API")
                    .font(.caption1Roboto)
                    .foregroundColor(.white.opacity(0.9))
            }

            Spacer()

            Button("Test API") {
                onTestTap()
            }
            .font(.caption1Roboto)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.2))
            .cornerRadius(6)
        }
        .padding()
        .background(Color.red)
        .cornerRadius(12)
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
}

#Preview {
    NavigationStack {
        TrackedItemsListView()
            .environmentObject(ShopperPlusViewModel())
    }
}
