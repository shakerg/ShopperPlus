//
//  SupportUsView.swift
//  ShopperPlus
//
//  Created by Shaker Gilbert on 8/4/25.
//

import SwiftUI

struct SupportUsView: View {
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header Section
                    VStack(spacing: 16) {
                        Text("🛒 Support Shopper+")
                            .font(.title2Roboto)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)

                        VStack(spacing: 12) {
                            Text("We're building Shopper+ to help you track prices and save money — all in one place.")
                                .font(.bodyRoboto)
                                .multilineTextAlignment(.center)

                            Text("To unlock deeper features like price tracking for Amazon products, we need to make a few qualifying sales through our affiliate program.")
                                .font(.bodyRoboto)
                                .multilineTextAlignment(.center)

                            Text("If you plan to shop on Amazon anyway, simply using the button below helps support the app's early development — at no extra cost to you.")
                                .font(.bodyRoboto)
                                .multilineTextAlignment(.center)

                            Text("Every purchase made through our link helps us unlock the tools we need to grow. 💛")
                                .font(.bodyRoboto)
                                .multilineTextAlignment(.center)
                                .fontWeight(.medium)

                            Text("Thank you for being part of our launch!")
                                .font(.bodyRoboto)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal)

                    // Amazon Support Button
                    VStack(spacing: 16) {
                        Link(destination: URL(string: "https://www.amazon.com?tag=vuwing-20")!) {
                            HStack(spacing: 12) {
                                Text("Support us on Amazon")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                Image(systemName: "cart.fill")
                                    .foregroundColor(.white)
                                    .font(.system(size: 16, weight: .medium))
                            }
                            .padding(.vertical, 14)
                            .padding(.horizontal, 20)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.orange)
                            )
                            .shadow(color: .orange.opacity(0.3), radius: 3, x: 0, y: 2)
                        }
                        .simultaneousGesture(
                            TapGesture().onEnded {
                                if hapticsEnabled {
                                    let impact = UIImpactFeedbackGenerator(style: .medium)
                                    impact.impactOccurred()
                                }
                            }
                        )

                        Text("Opens Amazon in your browser")
                            .font(.caption1Roboto)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)

                    // Coming Soon Section
                    VStack(spacing: 16) {
                        Divider()
                            .padding(.horizontal)

                        VStack(spacing: 8) {
                            Text("More Ways to Support Coming Soon")
                                .font(.title3Roboto)
                                .fontWeight(.semibold)

                            Text("We're working on additional ways for you to support Shopper+ development, including other retailer partnerships and premium features.")
                                .font(.bodyRoboto)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal)

                        // Coming Soon Features
                        VStack(spacing: 12) {
                            ComingSoonRowView(
                                icon: "target",
                                iconColor: .red,
                                title: "Target Partnership",
                                subtitle: "Support through Target purchases"
                            )

                            ComingSoonRowView(
                                icon: "bag.fill",
                                iconColor: .blue,
                                title: "Walmart Partnership",
                                subtitle: "Support through Walmart purchases"
                            )

                            ComingSoonRowView(
                                icon: "crown.fill",
                                iconColor: .purple,
                                title: "Premium Features",
                                subtitle: "Advanced tracking and analytics"
                            )
                        }
                        .padding(.horizontal)
                    }

                    Spacer(minLength: 32)
                }
                .padding(.vertical)
            }
            .navigationTitle("Support Us")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

struct ComingSoonRowView: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.bodyRoboto)
                    .foregroundColor(.primary)
                Text(subtitle)
                    .font(.caption1Roboto)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text("Coming Soon")
                .font(.caption2Roboto)
                .fontWeight(.medium)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.1))
                .foregroundColor(.secondary)
                .cornerRadius(6)
        }
        .padding(.vertical, 4)
        .opacity(0.7)
    }
}

#Preview {
    SupportUsView()
}
