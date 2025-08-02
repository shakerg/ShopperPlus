//
//  AffiliateManager.swift
//  ShopperPlus
//
//  Created by Shaker Gilbert on 8/1/25.
//

import Foundation

class AffiliateManager {
    static let shared = AffiliateManager()
    
    private init() {}
    
    // MARK: - Affiliate Configuration
    
    private struct AffiliateConfig {
        let tagParamName: String
        let tagValue: String
        let paramsToRemove: [String]
    }
    
    private let affiliateConfigs: [String: AffiliateConfig] = [
        "amazon": AffiliateConfig(
            tagParamName: "tag",
            tagValue: "shopperplus-20",
            paramsToRemove: ["tag", "ref", "ref_", "linkCode", "camp", "creative"]
        ),
        "walmart": AffiliateConfig(
            tagParamName: "affiliateInfo",
            tagValue: "shopperplus",
            paramsToRemove: ["affiliateInfo", "athbdg", "athcpid", "athpgid", "ath1id"]
        ),
        "target": AffiliateConfig(
            tagParamName: "lnk",
            tagValue: "shopperplus",
            paramsToRemove: ["lnk", "Dref", "sid"]
        ),
        "bestbuy": AffiliateConfig(
            tagParamName: "irclickid",
            tagValue: "shopperplus",
            paramsToRemove: ["irclickid", "ref", "loc"]
        )
    ]
    
    // MARK: - URL Processing
    
    func normalizeAndTag(url: URL) -> URL {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        guard let host = components?.host?.lowercased() else { return url }
        
        // Determine retailer from host
        let retailer = determineRetailer(from: host)
        guard let config = affiliateConfigs[retailer] else { return url }
        
        // Clean up existing affiliate parameters
        let existingQueryItems = components?.queryItems ?? []
        components?.queryItems = existingQueryItems.filter { queryItem in
            !config.paramsToRemove.contains { param in
                queryItem.name.lowercased().contains(param.lowercased())
            }
        }
        
        // Add our affiliate tag
        var queryItems = components?.queryItems ?? []
        queryItems.append(URLQueryItem(name: config.tagParamName, value: config.tagValue))
        components?.queryItems = queryItems
        
        return components?.url ?? url
    }
    
    private func determineRetailer(from host: String) -> String {
        if host.contains("amazon") {
            return "amazon"
        } else if host.contains("walmart") {
            return "walmart"
        } else if host.contains("target") {
            return "target"
        } else if host.contains("bestbuy") {
            return "bestbuy"
        }
        return "unknown"
    }
    
    // MARK: - URL Expansion
    
    func expandShortenedURL(_ url: URL, completion: @escaping (URL) -> Void) {
        // Check if URL appears to be shortened
        let shortenedDomains = ["bit.ly", "tinyurl.com", "t.co", "amzn.to", "shorturl.at"]
        let host = url.host?.lowercased() ?? ""
        
        if shortenedDomains.contains(where: { host.contains($0) }) {
            // Perform HEAD request to get the redirect URL
            var request = URLRequest(url: url)
            request.httpMethod = "HEAD"
            request.setValue("ShopperPlus/1.0", forHTTPHeaderField: "User-Agent")
            
            URLSession.shared.dataTask(with: request) { _, response, _ in
                if let httpResponse = response as? HTTPURLResponse,
                   let redirectURL = httpResponse.url {
                    DispatchQueue.main.async {
                        completion(redirectURL)
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(url)
                    }
                }
            }.resume()
        } else {
            completion(url)
        }
    }
    
    // MARK: - Validation
    
    func isSupportedRetailer(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        let retailer = determineRetailer(from: host)
        return affiliateConfigs.keys.contains(retailer)
    }
    
    func getRetailerName(_ url: URL) -> String? {
        guard let host = url.host?.lowercased() else { return nil }
        let retailer = determineRetailer(from: host)
        
        switch retailer {
        case "amazon": return "Amazon"
        case "walmart": return "Walmart"
        case "target": return "Target"
        case "bestbuy": return "Best Buy"
        default: return nil
        }
    }
}
