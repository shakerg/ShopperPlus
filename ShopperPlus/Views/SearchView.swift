//
//  SearchView.swift
//  ShopperPlus
//
//  Created by Shaker Gilbert on 8/1/25.
//

import SwiftUI

struct SearchView: View {
    @EnvironmentObject var viewModel: ShopperPlusViewModel
    @State private var searchText = ""
    @State private var showingAddItemSheet = false

    var body: some View {
        VStack(spacing: 20) {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search for products to track...", text: $searchText)
                    .font(.bodyRoboto)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            .padding(.horizontal)

            if searchText.isEmpty {
                // Empty State
                VStack(spacing: 24) {
                    Image(systemName: "magnifyingglass.circle")
                        .font(.system(size: 80))
                        .foregroundColor(.blue.opacity(0.6))

                    VStack(spacing: 8) {
                        Text("Search for Products")
                            .font(.title2Roboto)
                            .fontWeight(.semibold)

                        Text("Find products online to track their prices and get notified when they go on sale")
                            .font(.bodyRoboto)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }

                    Button("Add Item Manually") {
                        showingAddItemSheet = true
                    }
                    .buttonStyle(.borderedProminent)
                    .font(.bodyRoboto)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                // Search Results
                List {
                    // TODO: Implement search results
                    Text("Search results will appear here")
                        .font(.bodyRoboto)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .navigationTitle("Search")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showingAddItemSheet) {
            AddItemSheet()
                .environmentObject(viewModel)
        }
    }
}

#Preview {
    NavigationStack {
        SearchView()
            .environmentObject(ShopperPlusViewModel())
    }
}
