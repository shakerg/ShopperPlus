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
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                                .font(.caption)
                            Text("Processing Time")
                                .font(.caption1Roboto)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                        }
                        
                        Text("Amazon URLs may take 1-2 minutes to process. Please keep the app open during this time.")
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
                        SupportedStoreRow(name: "Amazon", domain: "amazon.com", icon: "a.circle.fill")
                        SupportedStoreRow(name: "eBay", domain: "ebay.com", icon: "e.circle.fill")
                        SupportedStoreRow(name: "Target", domain: "target.com", icon: "t.circle.fill")
                        SupportedStoreRow(name: "Best Buy", domain: "bestbuy.com", icon: "b.circle.fill")
                        SupportedStoreRow(name: "Walmart", domain: "walmart.com", icon: "w.circle.fill")
                        SupportedStoreRow(name: "More coming soon!", domain: "", icon: "plus.circle.fill")
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

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .font(.bodyRoboto)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.bodyRoboto)
                    .foregroundColor(.primary)

                if !domain.isEmpty {
                    Text(domain)
                        .font(.caption1Roboto)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    AddItemSheet()
        .environmentObject(ShopperPlusViewModel())
}
