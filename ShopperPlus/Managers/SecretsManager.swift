//
//  SecretsManager.swift
//  ShopperPlus
//
//  Created by Shaker Gilbert on 8/1/25.
//

import Foundation

class SecretsManager {
    static let shared = SecretsManager()

    private var secrets: [String: Any] = [:]

    private init() {
        loadSecrets()
    }

    private func loadSecrets() {
        guard let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path) as? [String: Any] else {
            print("Warning: Secrets.plist not found or invalid")
            return
        }

        secrets = plist
    }

    func getString(for key: String) -> String? {
        return secrets[key] as? String
    }

    func getInt(for key: String) -> Int? {
        return secrets[key] as? Int
    }

    func getBool(for key: String) -> Bool? {
        return secrets[key] as? Bool
    }

    // MARK: - API Configuration

    var apiBaseURL: String {
        return getString(for: "API_BASE_URL") ?? "https://api.shopper.vuwing-digital.com/api/v1"
    }

    var apiHealthURL: String {
        return getString(for: "API_HEALTH_URL") ?? "https://api.shopper.vuwing-digital.com/health"
    }

    var cloudKitContainerID: String {
        return getString(for: "CLOUDKIT_CONTAINER_ID") ?? "iCloud.VuWing-Corp.ShopperPlus"
    }
}

// MARK: - Debug Extensions
extension SecretsManager {
    func getAllSecrets() -> [String: Any] {
        return secrets
    }

    func debugDescription() -> String {
        var description = "=== Secrets Configuration ===\n"
        for (key, value) in secrets {
            if key.lowercased().contains("url") {
                description += "\(key): \(value)\n"
            } else {
                description += "\(key): [HIDDEN]\n"
            }
        }
        return description
    }
}
