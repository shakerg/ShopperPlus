# Shopper+ Backend

A scalable price monitoring and notification service designed for OpenShift/Kubernetes deployment.

## Overview

The Shopper+ Backend provides:
- 🔍 **Product Price Monitoring** - Scrapes e-commerce sites for price updates
- 🔔 **Price Drop Notifications** - Alerts users when prices drop below targets
- ⚡ **High-Performance Caching** - Memcached integration for fast response times
- 🔒 **Anonymous Scraping** - Tor proxy integration for IP rotation and anonymity
- 📱 **CloudKit Integration** - Syncs with iOS app user preferences
- 🚀 **Cloud-Native** - Designed for OpenShift/Kubernetes with Red Hat images

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   iOS App       │    │   Backend API   │    │   Scraper       │
│   (CloudKit)    │◄──►│   (Node.js)     │◄──►│   Workers       │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                │                        │
                                ▼                        ▼
                       ┌─────────────────┐    ┌─────────────────┐
                       │   Memcached     │    │   Tor Proxy     │
                       │   (Cache)       │    │   (Anonymity)   │
                       └─────────────────┘    └─────────────────┘
                                │
                                ▼
                       ┌─────────────────┐
                       │   PostgreSQL    │
                       │   (Database)    │
                       └─────────────────┘
```

## Features

### 🎯 Price Monitoring
- Supports major e-commerce sites (Amazon, Target, Walmart, Best Buy)
- Intelligent scraping with domain-specific extractors
- Configurable cache TTL and update frequencies
- Price history tracking and trend analysis

### 🔒 Anonymous Scraping
- Tor proxy integration for IP rotation
- User-Agent rotation and request randomization
- Circuit rotation every 50-100 requests
- Fallback to direct connection if Tor fails

### ⚡ Performance & Scalability
- Memcached for high-performance price lookups
- Horizontal pod autoscaling support
- Background job processing with queue management
- Connection pooling and resource optimization

### 🔔 Notifications
- Push notification support (Apple Push Notifications)
- Price drop alerts based on user-defined targets
- Configurable notification preferences per product

## Quick Start

### Prerequisites
- OpenShift/Kubernetes cluster
- Docker registry access
- kubectl or oc CLI tools


npm install -g npm-check-updates
ncu -u
npm install



### 1. Build Images
```bash
# Set your registry
export REGISTRY=your-registry.com

# Build and push images
./build.sh
```

### 2. Configure Secrets
Edit `k8s/secrets.yaml` with your actual values:
```yaml
stringData:
  DB_PASSWORD: "your-secure-password"
  JWT_SECRET: "your-jwt-secret-key"
  TOR_CONTROL_PASSWORD: "your-tor-password"
  APN_KEY_ID: "your-apn-key-id"
  APN_TEAM_ID: "your-apn-team-id"
```

### 3. Deploy
```bash
# Deploy to OpenShift/Kubernetes
REGISTRY=your-registry.com ./deploy.sh
```

### 4. Test
```bash
# Port forward for testing
kubectl port-forward service/shopper-plus-backend-service 8080:80

# Health check
curl http://localhost:8080/health

# Test product addition
curl -X POST http://localhost:8080/api/product \
  -H "Content-Type: application/json" \
  -d '{"url": "https://www.amazon.com/dp/B08N5WRWNW"}'
```

## API Endpoints

### POST /api/sync
Sync user watchlist from CloudKit
```json
{
  "userId": "user123",
  "products": [
    {
      "url": "https://www.amazon.com/dp/B08N5WRWNW",
      "targetPrice": 99.99
    }
  ]
}
```

### GET /api/price/{productId}
Get current price and history for a product

### POST /api/product
Add a new product for monitoring
```json
{
  "url": "https://www.amazon.com/dp/B08N5WRWNW"
}
```

### GET /api/products?userId=user123
Get all products for a user

### DELETE /api/watchlist/{userId}/{productId}
Remove product from user's watchlist

## Configuration

### Environment Variables
Key configuration options in `k8s/configmap.yaml`:

| Variable | Description | Default |
|----------|-------------|---------|
| `MAX_CONCURRENT_SCRAPERS` | Max parallel scrapers | 10 |
| `SCRAPER_DELAY_MS` | Delay between requests | 2000 |
| `CIRCUIT_ROTATION_REQUESTS` | Tor circuit rotation frequency | 75 |
| `PRICE_CACHE_TTL` | Price cache TTL (seconds) | 3600 |
| `RATE_LIMIT_MAX_REQUESTS` | API rate limit | 100 |

### Scaling
```bash
# Scale backend pods
kubectl scale deployment shopper-plus-backend --replicas=5

# Scale scraper workers
kubectl scale deployment shopper-plus-scraper --replicas=3
```

## Monitoring

### Health Checks
- **Liveness**: `/health` endpoint
- **Readiness**: `/health` endpoint with dependency checks
- **Database**: Connection pooling with automatic retry
- **Cache**: Graceful degradation if Memcached unavailable

### Logging
```bash
# View backend logs
kubectl logs -f deployment/shopper-plus-backend

# View scraper logs
kubectl logs -f deployment/shopper-plus-scraper

# View specific pod logs
kubectl logs -f pod/shopper-plus-backend-xxx
```

### Metrics
The application exposes metrics for monitoring:
- Request rates and response times
- Scraper success/failure rates
- Cache hit/miss ratios
- Database connection pool status

## Development

### Local Development
```bash
# Install dependencies
npm install

# Copy environment template
cp .env.example .env

# Start local PostgreSQL and Memcached
docker-compose up -d postgres memcached

# Run migrations
npm run db:migrate

# Start development server
npm run dev
```

### Running Tests
```bash
# Run test suite
npm test

# Run with coverage
npm run test:coverage

# Lint code
npm run lint
```

## Security

### Container Security
- Non-root user execution (UID 1001)
- Minimal privileges with capability dropping
- Read-only root filesystem where possible
- Network policies for pod-to-pod communication

### Data Security
- Secrets managed via Kubernetes secrets
- TLS termination at the edge
- Environment-specific configuration isolation
- Database connection encryption in production

## Troubleshooting

### Common Issues

**Tor Proxy Connection Failed**
```bash
# Check Tor proxy status
kubectl logs deployment/tor-proxy

# Verify service connectivity
kubectl exec -it deployment/shopper-plus-backend -- nc -zv tor-proxy-service 9050
```

**Database Connection Issues**
```bash
# Check PostgreSQL status
kubectl logs deployment/postgresql

# Test database connectivity
kubectl exec -it deployment/shopper-plus-backend -- nc -zv postgresql-service 5432
```

**Scraping Failures**
```bash
# Check scraper worker logs
kubectl logs deployment/shopper-plus-scraper

# View failed jobs in database
kubectl exec -it deployment/postgresql -- psql -U shopperplus -c "SELECT * FROM scrape_jobs WHERE status='failed';"
```

### Performance Tuning

**High Memory Usage**
- Reduce `MAX_CONCURRENT_SCRAPERS`
- Increase scraper pod memory limits
- Monitor Memcached memory usage

**Slow Response Times**
- Check cache hit rates
- Scale backend replicas
- Optimize database queries

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For issues and questions:
- 📧 Email: support@shopper-plus.com
- 📝 Issues: GitHub Issues
- 📖 Docs: [Full Documentation](docs/)

---

Built with ❤️ for the Shopper+ ecosystem
