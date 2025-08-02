# Shopper+ iOS App

**Shopper+** is a price tracking iOS app built with SwiftUI that allows users to track product prices from various online stores. The app uses CloudKit for data synchronization and a backend service for price monitoring.

## Features

- **Product URL Tracking**: Add products by pasting URLs from supported stores
- **Price History**: Track price changes over time with visual charts
- **CloudKit Sync**: Automatic synchronization across devices
- **Push Notifications**: Get notified when prices drop
- **Target Price Alerts**: Set target prices and get alerts when reached
- **Roboto Font**: Custom typography using Google's Roboto font family

## Architecture

The app follows a clean MVVM architecture with SwiftUI:

- **Models**: `TrackedItem`, `PriceEntry`, `NotificationSettings`
- **Views**: SwiftUI views with custom Roboto typography
- **ViewModels**: `ShopperPlusViewModel` for state management
- **Services**: `CloudKitManager` and `NetworkingService`

## Data Flow

1. **User Input** → CloudKit (user state) 
2. **CloudKit** → Backend (product/price state)
3. **Backend** → Push Notifications
4. **Sync Now** refreshes data from backend

## Getting Started

### Prerequisites

- Xcode 15.0 or later
- iOS 18.5 SDK
- Apple Developer Account (for CloudKit and push notifications)

### Building the App

1. Clone the repository
2. Open `ShopperPlus.xcodeproj` in Xcode
3. Configure your development team in project settings
4. Update the CloudKit container identifier in `CloudKitManager.swift`
5. Build and run on iOS Simulator or device

### Fonts

The app uses Google's Roboto font family for consistent typography. The font files are located in the `ShopperPlus/Resources/Fonts/` folder and are automatically included in the app bundle.

Font variants included:
- Roboto Regular
- Roboto Medium  
- Roboto Bold
- Roboto Light
- Roboto SemiBold
- Roboto Italic

## Project Structure

```
ShopperPlus/
├── Models/
│   ├── TrackedItem.swift
│   ├── PriceEntry.swift
│   └── NotificationSettings.swift
├── Views/
│   ├── ContentView.swift
│   ├── TrackedItemsListView.swift
│   ├── TrackedItemRowView.swift
│   ├── TrackedItemDetailView.swift
│   ├── EmptyStateView.swift
│   └── AddItemSheet.swift
├── ViewModels/
│   └── ShopperPlusViewModel.swift
├── Services/
│   ├── CloudKitManager.swift
│   └── NetworkingService.swift
├── Extensions/
│   └── Font+Roboto.swift
├── Resources/
│   └── Fonts/
│       ├── Roboto-Regular.ttf
│       ├── Roboto-Medium.ttf
│       ├── Roboto-Bold.ttf
│       ├── Roboto-Light.ttf
│       ├── Roboto-SemiBold.ttf
│       └── Roboto-Italic.ttf
│   ├── EmptyStateView.swift
│   └── AddItemSheet.swift
├── ViewModels/
│   └── ShopperPlusViewModel.swift
├── Services/
│   ├── CloudKitManager.swift
│   └── NetworkingService.swift
├── Extensions/
│   └── Font+Roboto.swift
└── Assets.xcassets/
```

## Supported Stores (Planned)

- Amazon
- eBay  
- Target
- Best Buy
- Walmart
- More coming soon!

## CloudKit Setup

1. Enable CloudKit in your app's capabilities
2. Create a new CloudKit container or use existing
3. Update the container identifier in `CloudKitManager.swift`
4. Deploy the schema to production for real usage

## Backend Integration

The app is designed to work with a backend API at `api.shopper.vuwing-digital.com`. The backend handles:

- Product information extraction
- Price monitoring and updates
- Push notification delivery
- Data caching and optimization

## License

This project is part of the emu-foundations iPhone Apps collection.

## Next Steps

- [ ] Implement barcode scanning
- [ ] Add more supported stores
- [ ] Implement sharing features
- [ ] Add price prediction analytics
- [ ] Create companion watchOS app
