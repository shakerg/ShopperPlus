//
//  TrackedItemsListView.swift
//  ShopperPlus
//
//  Created by Shaker Gilbert on 7/31/25.
//

import SwiftUI

struct TrackedItemsListView: View {
    @EnvironmentObject var viewModel: ShopperPlusViewModel

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
    }

    private func deleteItems(offsets: IndexSet) {
        for index in offsets {
            let item = viewModel.filteredItems[index]
            viewModel.deleteItem(item)
        }
    }
}

#Preview {
    NavigationStack {
        TrackedItemsListView()
            .environmentObject(ShopperPlusViewModel())
    }
}
