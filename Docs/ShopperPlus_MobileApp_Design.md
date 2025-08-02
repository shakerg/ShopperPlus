# Shopper+ Mobile App Design Plan
**Date:** 2025-07-30

## Overview
Shopper+ is an iOS-first mobile app that allows users to track products via pasted URLs, monitor price changes, and receive notifications.
The design uses a **dual-layer data model**:
1. **CloudKit** stores user URL tracking data for sync, recovery, and portability.
2. **Backend** provides reliable price checking, caching, and notifications.

## Goals
- Reliable product tracking
- CloudKit-backed recoverability
- Clean SwiftUI app architecture (MVVM)
- Backend-driven notifications (v1 with hybrid local + backend)

## Architecture
**Layers:**
- UI (SwiftUI)
- ViewModel (MVVM)
- Local Persistence (CloudKit)
- Networking (api.shopper.vuwing-digital.com)

**Data Flow:**
User Action -> CloudKit (user state) -> Backend (product/price state)
     ^                                          |
     |--------------- Sync Now refresh ---------|

**Core Models:**
- TrackedItem
- PriceEntry
- BarcodeEntry
- UserSettings
- NotificationSettings

## User Stories
1. As a user, I want to paste a product URL to track it.
2. As a user, I want to see the current price and history of a tracked item.
3. As a user, I want to receive notifications when the price decreases.


## Features (MVP)
1. Paste product URL → track item
2. CloudKit storage of tracked items
3. "Sync Now" manual sync button
4. Price fetch: local (opportunistic) + backend
5. Notifications: backend driven
6. Recoverability: reinstall/new device uses CloudKit state

## Sync Now Workflow
- Pull tracked items from CloudKit
- Send diff to backend
- Receive updated prices from backend
- Update UI

## Data Structures (Swift)
TrackedItem and PriceEntry structs (id, title, url, imageUrl, priceHistory, etc.)

## Dependencies
- CloudKit: iCloud user sync
- SwiftUI: UI
- URLSession: Networking
- BGTaskScheduler: Background refresh (lightweight)
- Push Notifications: APNs

<!-- ## Roadmap
1. iOS MVP (SwiftUI + CloudKit)
2. Backend integration with sync
3. Android + cross-platform sync (React Native) -->
