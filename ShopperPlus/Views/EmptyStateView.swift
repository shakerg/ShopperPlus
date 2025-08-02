//
//  EmptyStateView.swift
//  ShopperPlus
//
//  Created by Shaker Gilbert on 7/31/25.
//

import SwiftUI

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            // Icon
            Image(systemName: "bag.badge.plus")
                .font(.system(size: 80))
                .foregroundColor(.gray.opacity(0.6))

            // Title
            Text("No Items Tracked")
                .font(.title1Roboto)
                .foregroundColor(.primary)

            // Description
            Text("Start tracking product prices by adding a product URL")
                .font(.bodyRoboto)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            // Instructions
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "1.circle.fill")
                        .foregroundColor(.blue)
                        .font(.bodyRoboto)
                    Text("Copy a product URL from any supported store")
                        .font(.bodyRoboto)
                        .foregroundColor(.secondary)
                }

                HStack {
                    Image(systemName: "2.circle.fill")
                        .foregroundColor(.blue)
                        .font(.bodyRoboto)
                    Text("Tap the + button to add it to your tracking list")
                        .font(.bodyRoboto)
                        .foregroundColor(.secondary)
                }

                HStack {
                    Image(systemName: "3.circle.fill")
                        .foregroundColor(.blue)
                        .font(.bodyRoboto)
                    Text("Get notified when prices drop!")
                        .font(.bodyRoboto)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.top, 20)

            Spacer()

            // Supported stores info
            VStack(spacing: 8) {
                Text("Supported Stores")
                    .font(.footnoteRoboto)
                    .foregroundColor(.secondary)

                HStack(spacing: 16) {
                    StoreIconView(name: "Amazon", color: .orange)
                    StoreIconView(name: "eBay", color: .blue)
                    StoreIconView(name: "Target", color: .red)
                    StoreIconView(name: "Best Buy", color: .blue)
                }
            }
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

struct StoreIconView: View {
    let name: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Circle()
                .fill(color.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay {
                    Text(String(name.prefix(1)))
                        .font(.robotoBold(size: 16))
                        .foregroundColor(color)
                }

            Text(name)
                .font(.caption2Roboto)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    EmptyStateView()
}
