//
//  SettingsView.swift
//  ShopperPlus
//
//  Created by Shaker Gilbert on 8/1/25.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("soundEnabled") private var soundEnabled = true
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @AppStorage("darkModeEnabled") private var darkModeEnabled = false
    
    @State private var logoTapCount = 0
    @State private var showDebugSection = false
    @State private var showingDebugView = false
    
    var body: some View {
        NavigationStack {
            List {
                // General Settings Section
                Section("General") {
                    HStack {
                        Image(systemName: "speaker.wave.2")
                            .foregroundColor(.blue)
                            .frame(width: 30)
                        VStack(alignment: .leading) {
                            Text("Sound Effects")
                                .font(.bodyRoboto)
                            Text("Play sounds for actions")
                                .font(.caption1Roboto)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: $soundEnabled)
                    }
                    
                    HStack {
                        Image(systemName: "iphone.radiowaves.left.and.right")
                            .foregroundColor(.orange)
                            .frame(width: 30)
                        VStack(alignment: .leading) {
                            Text("Haptic Feedback")
                                .font(.bodyRoboto)
                            Text("Vibration for interactions")
                                .font(.caption1Roboto)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: $hapticsEnabled)
                    }
                    
                    HStack {
                        Image(systemName: darkModeEnabled ? "moon.fill" : "sun.max")
                            .foregroundColor(darkModeEnabled ? .purple : .yellow)
                            .frame(width: 30)
                        VStack(alignment: .leading) {
                            Text("Dark Mode")
                                .font(.bodyRoboto)
                            Text("Use dark appearance")
                                .font(.caption1Roboto)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: $darkModeEnabled)
                    }
                }
                
                // Support Section
                Section("Support & Information") {
                    SettingsRowView(
                        icon: "doc.text",
                        iconColor: .green,
                        title: "User Guide",
                        subtitle: "Learn how to use ShopperPlus"
                    ) {
                        // TODO: Open user guide
                    }
                    
                    SettingsRowView(
                        icon: "doc.plaintext",
                        iconColor: .blue,
                        title: "Terms of Service",
                        subtitle: "View our terms"
                    ) {
                        // TODO: Open terms of service
                    }
                    
                    SettingsRowView(
                        icon: "hand.raised",
                        iconColor: .purple,
                        title: "Privacy Policy",
                        subtitle: "Your privacy matters"
                    ) {
                        // TODO: Open privacy policy
                    }
                    
                    SettingsRowView(
                        icon: "questionmark.circle",
                        iconColor: .orange,
                        title: "Support",
                        subtitle: "Get help and contact us"
                    ) {
                        // TODO: Open support
                    }
                }
                
                // About Section
                Section("About") {
                    VStack(spacing: 16) {
                        // Vuwing Digital Logo (tappable for debug)
                        Button(action: {
                            logoTapped()
                        }) {
                            Image("vuwing-digital")
                                .resizable()
                                .scaledToFit()
                                .frame(height: 60)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        VStack(spacing: 4) {
                            Text("Shopper+")
                                .font(.title2Roboto)
                                .fontWeight(.bold)
                            
                            Text("Version 1.0.0")
                                .font(.bodyRoboto)
                                .foregroundColor(.secondary)
                            
                            Text("© 2025 VuWing Digital")
                                .font(.caption1Roboto)
                                .foregroundColor(.secondary)
                            
                            Text("A division of VuWing Corp")
                                .font(.caption1Roboto)
                                .foregroundColor(.secondary)
                        }
                        
                        Text("Intelligent price tracking and shopping optimization")
                            .font(.bodyRoboto)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                
                // Hidden Debug Section
                if showDebugSection {
                    Section("Debug") {
                        SettingsRowView(
                            icon: "ladybug.slash",
                            iconColor: .red,
                            title: "Debug Console",
                            subtitle: "Test connections and view system info"
                        ) {
                            showingDebugView = true
                        }
                        
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                                .frame(width: 30)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Developer Mode")
                                    .font(.bodyRoboto)
                                    .fontWeight(.medium)
                                Text("Debug features are enabled")
                                    .font(.caption1Roboto)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Button("Hide") {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    showDebugSection = false
                                    logoTapCount = 0
                                }
                            }
                            .font(.caption1Roboto)
                            .foregroundColor(.blue)
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
        }
        .preferredColorScheme(darkModeEnabled ? .dark : .light)
        .sheet(isPresented: $showingDebugView) {
            DebugCardView(showDebugSection: $showDebugSection)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
    
    private func logoTapped() {
        logoTapCount += 1
        
        // Haptic feedback for each tap if enabled
        if hapticsEnabled {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
        }
        
        // Show debug section after 7 taps
        if logoTapCount >= 7 {
            withAnimation(.easeInOut(duration: 0.5)) {
                showDebugSection = true
            }
            
            // Stronger haptic feedback when debug is unlocked
            if hapticsEnabled {
                let impact = UIImpactFeedbackGenerator(style: .heavy)
                impact.impactOccurred()
            }
        }
        
        // Reset counter after 10 seconds of inactivity
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            if logoTapCount < 7 {
                logoTapCount = 0
            }
        }
    }
}

struct SettingsRowView: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
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
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    SettingsView()
}
