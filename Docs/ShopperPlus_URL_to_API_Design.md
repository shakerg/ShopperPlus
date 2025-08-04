# Shopper+ Design Plan: URL-to-API Pipeline for Product Metadata and Affiliate Integration
**Date:** 2025-08-04

## Overview
When a user pastes or shares a product URL into Shopper+, the app will extract the product identifier from the URL and leverage **official retailer APIs** (Amazon, Walmart, Target, BestBuy, etc.) to fetch clean, structured product data.  
This eliminates the need for scraping and ensures reliable data and affiliate support.

---

## Goals
- Extract product metadata (title, price, images) **directly from official APIs**
- **Normalize URLs** with Shopper+ affiliate tags
- Store and refresh product information through backend APIs
- Reduce reliance on scraping or Tor proxies

---

## Workflow

### 1. Input: User Shares or Pastes URL
- Triggers:
  - **Paste in text field**
  - **Share Extension** from Safari/Amazon/Walmart apps

### 2. Extract Product Identifier
- Parse the URL using regex or `URLComponents`
- Identify the **retailer** and **product ID** format:

#### Amazon
```
https://www.amazon.com/dp/B09XYZ1234/ref=...
ASIN = B09XYZ1234
```

#### Walmart
```
https://www.walmart.com/ip/123456789
Item ID = 123456789
```

#### Target
```
https://www.target.com/p/-/A-8675309
Item ID = 8675309
```

#### Best Buy
```
https://www.bestbuy.com/site/product-name/123456.p
SKU = 123456
```

### 3. API Lookup
Depending on the retailer, Shopper+ backend (or device) calls the corresponding API:

#### Amazon (Product Advertising API v5)
- Endpoint: `https://webservices.amazon.com/paapi5/getitems`
- Input: `ItemIds = ASIN`
- Resources: Title, Images, Offers
- Output: JSON with title, price, image, affiliate URL

#### Walmart API
- Endpoint: `https://developer.api.walmart.com/api-proxy/service/affil/product/v2/{itemId}`
- Output: JSON with name, image, price

#### Target API
- Provided via CJ.com or Rakuten affiliate APIs.

#### BestBuy
- BestBuy Developer API (requires key)

### 4. Normalize URL & Inject Affiliate Tag
- Replace user’s original URL with a **Shopper+ affiliate-tagged URL**:
  - Amazon: `https://www.amazon.com/dp/B09XYZ1234?tag=shopperplus-20`
  - Walmart: append `affp1=...`
  - Target/BestBuy: append affiliate parameters
- Ensures **purchases earn affiliate commissions**

### 5. Store in CloudKit + Backend
- Store:
  - Product ID
  - Clean affiliate URL
  - Title, image URL, price
  - Retailer type
- Allows syncing across devices and offline recovery

### 6. Backend Periodic Refresh
- Backend re-fetches product details using APIs periodically (e.g., daily)
- Sends push notifications if price drops

---

## System Architecture

```
User Shares URL
       ↓
Shopper+ extracts product ID
       ↓
Check retailer → call retailer API
       ↓
API returns metadata + affiliate URL
       ↓
Normalize URL (add our affiliate tag)
       ↓
Store in CloudKit and sync with backend
       ↓
Backend refreshes data using APIs
```

---

## Data Model

```
TrackedItem:
- id (UUID)
- retailer (enum)
- productId (ASIN, SKU, etc.)
- affiliateUrl
- title
- imageUrl
- currentPrice
- lastChecked
- targetPrice (optional)
```

---

## Benefits
- **Reliable**: No scraping or CAPTCHAs
- **Accurate**: Data direct from retailer APIs
- **Scalable**: Can handle many users without IP blocking
- **Monetized**: Every product link includes your affiliate tag

---

## Future Fallbacks
- For retailers without an API:
  - Shopper+ fetches metadata on the **device once** (when link is shared)
  - Backend refresh via **3rd-party aggregators (PriceAPI, Rainforest API)**

---

## Next Steps
1. Implement **URL parsing module** (Swift/Backend)
2. Integrate **Amazon PA API v5**
3. Integrate Walmart and Target APIs via affiliate networks
4. Build backend refresh jobs
5. Add affiliate link normalization logic
