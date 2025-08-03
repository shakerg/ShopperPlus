# ShopperPlus Admin Portal

A comprehensive web-based administration interface for monitoring and managing your ShopperPlus backend infrastructure.

## Features

### 📊 **Dashboard**
- Real-time overview of key metrics
- User statistics and activity trends
- Quick access to important system information

### 👥 **User Analytics**
- Total users and growth metrics
- User activity patterns
- Items per user statistics

### 📦 **Product Management**
- Product catalog overview
- Data completeness metrics (titles, prices, images)
- Product filtering and search

### 🌐 **Domain Distribution**
- Detailed breakdown by retailer (Amazon, Target, Walmart, etc.)
- Product count and user tracking per domain
- Price range analysis by retailer

### 🤖 **Scraping Monitor**
- Real-time scraping performance metrics
- Success/failure rates
- Job queue status and controls
- Manual scraping triggers

### 📈 **Advanced Analytics**
- Historical trends and patterns
- Performance metrics
- Growth analytics

### ⚙️ **System Status**
- Container health monitoring
- Database performance metrics
- Cache status and performance

## Access URLs

- **Admin Portal**: `https://your-domain.com/api/admin/`
- **Dashboard API**: `https://your-domain.com/api/admin/dashboard`
- **Legacy View**: `https://your-domain.com/api/admin/dashboard/view` (redirects to main portal)

## Security

- **Private Hosting**: Runs on your Kubernetes cluster
- **No External Dependencies**: All assets served locally
- **Privacy-Focused**: No personal user data exposed
- **Admin-Only Access**: Not exposed to end users

## Technical Stack

- **Frontend**: Vanilla JavaScript with Chart.js for visualizations
- **Backend**: Node.js/Express API endpoints
- **Database**: PostgreSQL with optimized analytics queries
- **Styling**: Modern CSS with responsive design
- **Charts**: Chart.js for data visualization

## Features Overview

### Real-Time Data
- Auto-refreshes every 5 minutes
- Manual refresh capability
- Live scraping job monitoring

### Data Export
- JSON export of all analytics data
- Historical data preservation
- Backup and reporting capabilities

### Responsive Design
- Mobile-friendly interface
- Tablet and desktop optimized
- Progressive enhancement

### Performance
- Optimized database queries
- Caching for better performance
- Minimal resource usage

## Usage

1. **Access the portal** at `/api/admin/`
2. **Navigate** using the left sidebar
3. **Refresh data** manually or wait for auto-refresh
4. **Export data** using the export button
5. **Monitor scraping** in the Scraping section

## Data Insights

The portal provides insights into:

- **User Behavior**: How users interact with the app
- **Popular Retailers**: Which domains are most tracked
- **System Performance**: Scraping success rates and speed
- **Data Quality**: Completeness of product information
- **Growth Metrics**: User adoption and usage trends

## Deployment

The admin portal is automatically deployed with your backend:

```yaml
# Already included in your backend.yaml
image: registry.redcloud.land/shopper-plus-backend:v1.0.3
```

Static files are served directly by the Express server, no additional configuration needed.

## Development

To modify the admin portal:

1. **HTML**: Edit `/src/public/index.html`
2. **CSS**: Edit `/src/public/css/admin.css`
3. **JavaScript**: Edit `/src/public/js/admin.js`
4. **API**: Edit `/src/api/admin.js`

Changes require rebuilding and redeploying the backend image.

---

**ShopperPlus Admin Portal v1.0.3** - Built for scalable price tracking infrastructure
