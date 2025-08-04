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
                    StoreIconView(name: "Amazon", color: .orange, customImage: "amazon-a-smile", isEnabled: true, affiliateURL: "https://www.amazon.com?tag=vuwing-20")
                    StoreIconView(name: "Walmart", color: .blue, isEnabled: false)
                    StoreIconView(name: "Target", color: .red, isEnabled: false)
                    StoreIconView(name: "Best Buy", color: .blue, isEnabled: false)
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
    let customImage: String?
    let isEnabled: Bool
    let affiliateURL: String?

    init(name: String, color: Color, customImage: String? = nil, isEnabled: Bool = true, affiliateURL: String? = nil) {
        self.name = name
        self.color = color
        self.customImage = customImage
        self.isEnabled = isEnabled
        self.affiliateURL = affiliateURL
    }

    var body: some View {
        Button(action: {
            if let affiliateURL = affiliateURL, let url = URL(string: affiliateURL) {
                UIApplication.shared.open(url)
            }
        }) {
            VStack(spacing: 4) {
                Circle()
                    .fill((isEnabled ? color : .gray).opacity(0.2))
                    .frame(width: 40, height: 40)
                    .overlay {
                        if let customImage = customImage, isEnabled {
                            Image(customImage)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20)
                        } else {
                            Text(String(name.prefix(1)))
                                .font(.robotoBold(size: 16))
                                .foregroundColor(isEnabled ? color : .gray)
                        }
                    }

                Text(name)
                    .font(.caption2Roboto)
                    .foregroundColor(isEnabled ? .secondary : .gray)
            }
            .opacity(isEnabled ? 1.0 : 0.6)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!isEnabled && affiliateURL == nil)
    }
}

#Preview {
    EmptyStateView()
}
