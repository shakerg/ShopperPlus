//
//  AddItemSheet.swift
//  ShopperPlus
//
//  Created by Shaker Gilbert on 7/31/25.
//

import SwiftUI

struct AddItemSheet: View {
    @EnvironmentObject var viewModel: ShopperPlusViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var urlText = ""
    @State private var isValidating = false
    @State private var pastedURL = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "link.badge.plus")
                        .font(.system(size: 48))
                        .foregroundColor(.blue)

                    Text("Add Product to Track")
                        .font(.title2Roboto)
                        .foregroundColor(.primary)

                    Text("Paste a product URL from any supported store")
                        .font(.bodyRoboto)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)

                // URL Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Product URL")
                        .font(.headlineRoboto)
                        .foregroundColor(.primary)

                    TextField("https://example.com/product", text: $urlText)
                        .font(.bodyRoboto)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .onAppear {
                            checkClipboard()
                        }

                    if !pastedURL.isEmpty && pastedURL != urlText {
                        Button(action: {
                            urlText = pastedURL
                        }) {
                            HStack {
                                Image(systemName: "doc.on.clipboard")
                                Text("Paste from clipboard")
                                    .font(.bodyRoboto)
                            }
                            .foregroundColor(.blue)
                        }
                        .padding(.top, 4)
                    }

                    // Information about processing times
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                            Text("Instant Add")
                                .font(.caption1Roboto)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                        }

                        Text("Items are added instantly to your list. Product details will load in the background.")
                            .font(.caption1Roboto)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 6)
                }

                // Supported Stores
                VStack(alignment: .leading, spacing: 12) {
                    Text("Supported Stores")
                        .font(.headlineRoboto)
                        .foregroundColor(.primary)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                        SupportedStoreRow(
                            name: "Amazon", 
                            domain: "amazon.com", 
                            icon: "a.circle.fill", 
                            customImage: "amazon-a-smile", 
                            isEnabled: true, 
                            affiliateURL: "https://www.amazon.com?tag=vuwing-20"
                        )
                        SupportedStoreRow(name: "eBay", domain: "ebay.com", icon: "e.circle.fill", isEnabled: false)
                        SupportedStoreRow(name: "Target", domain: "target.com", icon: "t.circle.fill", isEnabled: false)
                        SupportedStoreRow(name: "Best Buy", domain: "bestbuy.com", icon: "b.circle.fill", isEnabled: false)
                        SupportedStoreRow(name: "Walmart", domain: "walmart.com", icon: "w.circle.fill", isEnabled: false)
                        SupportedStoreRow(name: "More coming soon!", domain: "", icon: "plus.circle.fill", isEnabled: false)
                    }
                }
                .padding(.horizontal)

                Spacer()

                // Add Button
                Button(action: addItem) {
                    HStack {
                        if isValidating {
                            ProgressView()
                                .scaleEffect(0.8)
                                .foregroundColor(.white)
                        } else {
                            Image(systemName: "plus")
                        }

                        Text(isValidating ? "Adding..." : "Add Item")
                            .font(.headlineRoboto)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isValidURL ? Color.blue : Color.gray)
                    .cornerRadius(10)
                }
                .disabled(!isValidURL || isValidating)
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .shopperPlusNavigationHeader()
            .navigationTitle("Add Item")
            .font(.bodyRoboto)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.bodyRoboto)
                }
            }
        }
    }

    private var isValidURL: Bool {
        guard let url = URL(string: urlText.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return false
        }
        return url.scheme?.hasPrefix("http") == true
    }

    private func checkClipboard() {
        if let clipboardString = UIPasteboard.general.string,
           let url = URL(string: clipboardString),
           url.scheme?.hasPrefix("http") == true {
            pastedURL = clipboardString
        }
    }

    private func addItem() {
        let cleanedURL = urlText.trimmingCharacters(in: .whitespacesAndNewlines)

        isValidating = true
        viewModel.addItem(from: cleanedURL)

        // The sheet will be dismissed automatically when viewModel.showingAddItemSheet becomes false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isValidating = false
        }
    }
}

struct SupportedStoreRow: View {
    let name: String
    let domain: String
    let icon: String
    let customImage: String?
    let isEnabled: Bool
    let affiliateURL: String?

    init(name: String, domain: String, icon: String, customImage: String? = nil, isEnabled: Bool = true, affiliateURL: String? = nil) {
        self.name = name
        self.domain = domain
        self.icon = icon
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
            HStack(spacing: 8) {
                if let customImage = customImage, isEnabled {
                    Image(customImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                } else {
                    Image(systemName: icon)
                        .foregroundColor(isEnabled ? .blue : .gray)
                        .font(.bodyRoboto)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.bodyRoboto)
                        .foregroundColor(isEnabled ? .primary : .gray)

                    if !domain.isEmpty {
                        Text(domain)
                            .font(.caption1Roboto)
                            .foregroundColor(isEnabled ? .secondary : .gray)
                    }
                }

                Spacer()
                
                if affiliateURL != nil {
                    Image(systemName: "link")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            .padding(.vertical, 4)
            .opacity(isEnabled ? 1.0 : 0.6)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!isEnabled && affiliateURL == nil)
    }
}

#Preview {
    AddItemSheet()
        .environmentObject(ShopperPlusViewModel())
}
