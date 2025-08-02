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

            // Settings Tab
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
        .accentColor(.blue)
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
