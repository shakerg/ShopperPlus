//
//  APITestDetailView.swift
//  ShopperPlus
//
//  Created by Shaker Gilbert on 8/3/25.
//

import SwiftUI

struct APITestDetailView: View {
    let result: APITestService.APITestResult
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Status Header
                    statusHeader
                    
                    // Request Details
                    detailSection(
                        title: "Request",
                        icon: "arrow.up.circle",
                        iconColor: .blue,
                        content: requestContent
                    )
                    
                    // Response Details
                    detailSection(
                        title: "Response",
                        icon: "arrow.down.circle",
                        iconColor: statusColor,
                        content: responseContent
                    )
                    
                    // Performance
                    if let responseTime = result.responseTime {
                        detailSection(
                            title: "Performance",
                            icon: "speedometer",
                            iconColor: .orange,
                            content: performanceContent(responseTime: responseTime)
                        )
                    }
                }
                .padding()
            }
            .navigationTitle(result.testName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var statusHeader: some View {
        HStack {
            Image(systemName: statusIcon)
                .font(.title)
                .foregroundColor(statusColor)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(statusText)
                    .font(.headlineRoboto)
                    .fontWeight(.semibold)
                    .foregroundColor(statusColor)
                
                Text(result.endpoint)
                    .font(.caption1Roboto)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(statusColor.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func detailSection(title: String, icon: String, iconColor: Color, content: AnyView) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                Text(title)
                    .font(.headlineRoboto)
                    .fontWeight(.semibold)
            }
            
            content
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var requestContent: AnyView {
        AnyView(
            VStack(alignment: .leading, spacing: 8) {
                infoRow("Method", "GET")
                infoRow("Endpoint", APITestService.shared.maskSensitiveInfo(result.endpoint))
                infoRow("Headers", "Content-Type: application/json")
            }
        )
    }
    
    private var responseContent: AnyView {
        AnyView(
            VStack(alignment: .leading, spacing: 8) {
                if let statusCode = result.statusCode {
                    infoRow("Status Code", "\(statusCode)")
                }
                
                if let error = result.errorMessage {
                    infoRow("Error", APITestService.shared.maskSensitiveInfo(error))
                } else if let response = result.responseData {
                    infoRow("Response", APITestService.shared.maskSensitiveInfo(response))
                }
            }
        )
    }
    
    private func performanceContent(responseTime: TimeInterval) -> AnyView {
        AnyView(
            VStack(alignment: .leading, spacing: 8) {
                infoRow("Response Time", "\(Int(responseTime * 1000))ms")
                infoRow("Performance", performanceRating(responseTime))
            }
        )
    }
    
    private func infoRow(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption1Roboto)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.bodyRoboto)
                .foregroundColor(.primary)
                .textSelection(.enabled)
        }
    }
    
    private func performanceRating(_ responseTime: TimeInterval) -> String {
        let ms = responseTime * 1000
        if ms < 100 { return "Excellent" }
        else if ms < 300 { return "Good" }
        else if ms < 1000 { return "Fair" }
        else { return "Slow" }
    }
    
    // MARK: - Status Helpers
    
    private var statusIcon: String {
        switch result.status {
        case .passed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .running: return "arrow.clockwise"
        case .unknown: return "questionmark.circle"
        }
    }
    
    private var statusColor: Color {
        switch result.status {
        case .passed: return .green
        case .failed: return .red
        case .warning: return .orange
        case .running: return .blue
        case .unknown: return .gray
        }
    }
    
    private var statusText: String {
        switch result.status {
        case .passed: return "Test Passed"
        case .failed: return "Test Failed"
        case .warning: return "Test Warning"
        case .running: return "Running..."
        case .unknown: return "Unknown Status"
        }
    }
}

#Preview {
    APITestDetailView(result: APITestService.APITestResult(
        testName: "Health Check",
        endpoint: "/api/v1/health",
        status: .passed,
        responseTime: 0.234,
        statusCode: 200,
        errorMessage: nil,
        responseData: "OK",
        timestamp: Date()
    ))
}
