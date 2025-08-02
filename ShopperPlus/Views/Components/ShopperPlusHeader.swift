//
//  ShopperPlusHeader.swift
//  ShopperPlus
//
//  Created by Shaker Gilbert on 8/1/25.
//
//  USAGE: Apply to any view with .shopperPlusNavigationHeader()
//  This provides a consistent navigation header with AppLogo + "Shopper+" branding
//

import SwiftUI

struct ShopperPlusHeader: View {
    var body: some View {
        HStack(spacing: 8) {
            Image("AppLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 32, height: 32)
            Text("Shopper+")
                .font(.title2Roboto)
                .fontWeight(.bold)
                .foregroundColor(.primary)
        }
    }
}

// MARK: - View Extension for Easy Usage
extension View {
    func shopperPlusNavigationHeader() -> some View {
        self
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    ShopperPlusHeader()
                }
            }
    }
}

#Preview {
    NavigationStack {
        VStack {
            Text("Sample Content")
                .padding()
            Spacer()
        }
        .shopperPlusNavigationHeader()
        .navigationTitle("Page Title")
    }
}
