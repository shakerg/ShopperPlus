//
//  InsightsView.swift
//  ShopperPlus
//
//  Created by Shaker Gilbert on 8/1/25.
//

import SwiftUI
import Charts

struct InsightsView: View {
    @EnvironmentObject var viewModel: ShopperPlusViewModel

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                if viewModel.trackedItems.isEmpty {
                    // Empty State
                    VStack(spacing: 24) {
                        Image(systemName: "chart.line.uptrend.xyaxis.circle")
                            .font(.system(size: 80))
                            .foregroundColor(.green.opacity(0.6))

                        VStack(spacing: 8) {
                            Text("No Insights Yet")
                                .font(.title2Roboto)
                                .fontWeight(.semibold)

                            Text("Start tracking items to see price trends, savings insights, and shopping analytics")
                                .font(.bodyRoboto)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 400)
                    .padding()
                } else {
                    // Insights Content
                    VStack(spacing: 20) {
                        // Total Savings Card
                        InsightCardView(
                            title: "Total Savings",
                            value: "$127.50",
                            subtitle: "This month",
                            icon: "dollarsign.circle.fill",
                            color: .green
                        )

                        // Items Tracked Card
                        InsightCardView(
                            title: "Items Tracked",
                            value: "\(viewModel.trackedItems.count)",
                            subtitle: "Active tracking",
                            icon: "list.bullet.circle.fill",
                            color: .blue
                        )

                        // Price Alerts Card
                        InsightCardView(
                            title: "Price Alerts",
                            value: "3",
                            subtitle: "This week",
                            icon: "bell.circle.fill",
                            color: .orange
                        )

                        // Best Deal Card
                        InsightCardView(
                            title: "Best Deal",
                            value: "25% off",
                            subtitle: "Wireless Headphones",
                            icon: "star.circle.fill",
                            color: .purple
                        )

                        // Recent Activity Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Recent Activity")
                                .font(.title3Roboto)
                                .fontWeight(.semibold)
                                .padding(.horizontal)

                            LazyVStack(spacing: 8) {
                                ActivityRowView(
                                    icon: "arrow.down.circle.fill",
                                    iconColor: .green,
                                    title: "Price Drop Alert",
                                    subtitle: "Wireless Headphones dropped to $149.99",
                                    time: "2 hours ago"
                                )

                                ActivityRowView(
                                    icon: "plus.circle.fill",
                                    iconColor: .blue,
                                    title: "Item Added",
                                    subtitle: "Started tracking Coffee Maker",
                                    time: "1 day ago"
                                )

                                ActivityRowView(
                                    icon: "chart.line.uptrend.xyaxis.circle.fill",
                                    iconColor: .orange,
                                    title: "Price Increase",
                                    subtitle: "Laptop price increased by $50",
                                    time: "3 days ago"
                                )
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.top)
                }
            }
        }
        .navigationTitle("Insights")
        .navigationBarTitleDisplayMode(.large)
        .refreshable {
            viewModel.syncNow()
        }
    }
}

struct InsightCardView: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.bodyRoboto)
                    .foregroundColor(.secondary)

                Text(value)
                    .font(.title2Roboto)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                Text(subtitle)
                    .font(.caption1Roboto)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(color)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

struct ActivityRowView: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let time: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.bodyRoboto)
                    .fontWeight(.medium)

                Text(subtitle)
                    .font(.caption1Roboto)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(time)
                .font(.caption1Roboto)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}

#Preview {
    NavigationStack {
        InsightsView()
            .environmentObject(ShopperPlusViewModel())
    }
}
