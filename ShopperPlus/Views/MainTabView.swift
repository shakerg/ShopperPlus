//
//  MainTabView.swift
//  ShopperPlus
//
//  Created by Shaker Gilbert on 8/1/25.
//

import SwiftUI

struct MainTabView: View {
    @StateObject private var viewModel = ShopperPlusViewModel()
    @AppStorage("darkModeEnabled") private var darkModeEnabled = false

    var body: some View {
        TabView {
            // Tracked Items Tab
            NavigationStack {
                TrackedItemsListView()
                    .environmentObject(viewModel)
            }
            .tabItem {
                Label("Items", systemImage: "list.bullet.clipboard")
            }

            // Search/Add Tab
            NavigationStack {
                SearchView()
                    .environmentObject(viewModel)
            }
            .tabItem {
                Label("Search", systemImage: "magnifyingglass")
            }

            // Insights Tab
            NavigationStack {
                InsightsView()
                    .environmentObject(viewModel)
            }
            .tabItem {
                Label("Insights", systemImage: "chart.line.uptrend.xyaxis")
            }

            // Support Us Tab
            SupportUsView()
                .tabItem {
                    Label("Support Us", systemImage: "heart.fill")
                }

            // Settings Tab
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
        .tint(.blue)
        .onAppear {
            // Set custom color for Support Us tab (heart icon)
            if let items = UITabBar.appearance().items {
                for (index, item) in items.enumerated() {
                    if index == 3 { // Support Us tab (0: Items, 1: Search, 2: Insights, 3: Support Us, 4: Settings)
                        item.selectedImage = UIImage(systemName: "heart.fill")?.withTintColor(.systemRed, renderingMode: .alwaysOriginal)
                    }
                }
            }
        }
        .preferredColorScheme(darkModeEnabled ? .dark : .light)
        .font(.bodyRoboto)
        .alert(
            "Error",
            isPresented: Binding<Bool>(
                get: { viewModel.error != nil },
                set: { _ in viewModel.dismissError() }
            )
        ) {
            Button("OK") {
                viewModel.dismissError()
            }
        } message: {
            if let error = viewModel.error {
                Text(error.errorDescription ?? "An unknown error occurred")
                    .font(.bodyRoboto)
            }
        }
    }
}

#Preview {
    MainTabView()
}
