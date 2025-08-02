//
//  ShopperPlusApp.swift
//  ShopperPlus
//
//  Created by Shaker Gilbert on 7/30/25.
//

import SwiftUI
import CloudKit

@main
struct ShopperPlusApp: App {
    let persistenceController = PersistenceController.shared
    @State private var showSplash = true

    init() {
        // Force portrait orientation on app launch
        configureOrientation()
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                if showSplash {
                    SplashScreenView(onSplashComplete: {
                        showSplash = false
                    })
                    .transition(.opacity)
                } else {
                    ContentView()
                        .environment(\.managedObjectContext, persistenceController.container.viewContext)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: showSplash)
            .onAppear {
                configureApp()
            }
        }
    }

    private func configureOrientation() {
        // Ensure app launches in portrait mode
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
        }
    }

    private func configureApp() {
        // Configure CloudKit
        configureCloudKit()

        // Register for remote notifications
        registerForPushNotifications()
    }

    private func configureCloudKit() {
        // CloudKit is configured automatically via CloudKitManager
        // This ensures the container is properly initialized
        _ = CloudKitManager.shared
    }

    private func registerForPushNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
    }
}

import UserNotifications
