const Memcached = require('memcached');
const logger = require('../utils/logger');

class Cache {
  constructor() {
    this.client = null;
    this.connected = false;
  }

  async connect() {
    try {
      const host = `${process.env.MEMCACHED_HOST}:${process.env.MEMCACHED_PORT}`;
      
      this.client = new Memcached(host, {
        timeout: 5000,
        retries: 3,
        retry: 10000,
        remove: true,
        failOverServers: undefined
      });

      // Test connection
      await this.ping();
      this.connected = true;
      
      logger.info('Cache connection established');
    } catch (error) {
      logger.error('Cache connection failed:', error);
      throw error;
    }
  }

  async disconnect() {
    if (this.client) {
      this.client.end();
      this.connected = false;
      logger.info('Cache connection closed');
    }
  }

  async ping() {
    return new Promise((resolve, reject) => {
      this.client.version((err, result) => {
        if (err) {
          reject(err);
        } else {
          resolve(result);
        }
      });
    });
  }

  async get(key) {
    if (!this.connected) {
      logger.warn('Cache not connected, skipping get operation');
      return null;
    }

    return new Promise((resolve, reject) => {
      this.client.get(key, (err, data) => {
        if (err) {
          logger.error('Cache get error:', { key, error: err.message });
          resolve(null); // Return null on error to fallback to database
        } else {
          logger.debug('Cache hit:', { key, hasData: !!data });
          resolve(data);
        }
      });
    });
  }

  async set(key, value, ttl = 3600) {
    if (!this.connected) {
      logger.warn('Cache not connected, skipping set operation');
      return false;
    }

    return new Promise((resolve, reject) => {
      this.client.set(key, value, ttl, (err) => {
        if (err) {
          logger.error('Cache set error:', { key, ttl, error: err.message });
          resolve(false);
        } else {
          logger.debug('Cache set:', { key, ttl });
          resolve(true);
        }
      });
    });
  }

  async del(key) {
    if (!this.connected) {
      return false;
    }

    return new Promise((resolve, reject) => {
      this.client.del(key, (err) => {
        if (err) {
          logger.error('Cache delete error:', { key, error: err.message });
          resolve(false);
        } else {
          logger.debug('Cache delete:', { key });
          resolve(true);
        }
      });
    });
  }

  async flush() {
    if (!this.connected) {
      return false;
    }

    return new Promise((resolve, reject) => {
      this.client.flush((err) => {
        if (err) {
          logger.error('Cache flush error:', err);
          resolve(false);
        } else {
          logger.info('Cache flushed successfully');
          resolve(true);
        }
      });
    });
  }

  // Cache key generators
  productPriceKey(productId) {
    return `product:price:${productId}`;
  }

  productMetaKey(productId) {
    return `product:meta:${productId}`;
  }

  apiSyncKey(userId) {
    return `api:sync:${userId}`;
  }

  domainScrapeKey(domain) {
    return `domain:scrape:${domain}`;
  }

  // High-level cache operations
  async getProductPrice(productId) {
    const key = this.productPriceKey(productId);
    return await this.get(key);
  }

  async setProductPrice(productId, priceData, ttl = parseInt(process.env.PRICE_CACHE_TTL)) {
    const key = this.productPriceKey(productId);
    return await this.set(key, priceData, ttl);
  }

  async getProductMeta(productId) {
    const key = this.productMetaKey(productId);
    return await this.get(key);
  }

  async setProductMeta(productId, metaData, ttl = parseInt(process.env.PRODUCT_META_CACHE_TTL)) {
    const key = this.productMetaKey(productId);
    return await this.set(key, metaData, ttl);
  }

  async getUserSync(userId) {
    const key = this.apiSyncKey(userId);
    return await this.get(key);
  }

  async setUserSync(userId, syncData, ttl = parseInt(process.env.API_CACHE_TTL)) {
    const key = this.apiSyncKey(userId);
    return await this.set(key, syncData, ttl);
  }

  async getDomainLastScrape(domain) {
    const key = this.domainScrapeKey(domain);
    return await this.get(key);
  }

  async setDomainLastScrape(domain, timestamp, ttl = 3600) {
    const key = this.domainScrapeKey(domain);
    return await this.set(key, timestamp, ttl);
  }

  async warmCache() {
    try {
      logger.info('Starting cache warming process');
      
      const database = require('./database');
      
      // Get most active products (last 24 hours)
      const result = await database.query(`
        SELECT p.id, p.canonical_url, p.title, p.image_url, p.current_price, p.currency
        FROM products p
        JOIN user_watchlist uw ON p.id = uw.product_id
        WHERE p.last_checked > NOW() - INTERVAL '24 hours'
        GROUP BY p.id
        ORDER BY COUNT(uw.id) DESC
        LIMIT 100
      `);

      let warmedCount = 0;
      for (const product of result.rows) {
        // Cache product metadata
        await this.setProductMeta(product.id, {
          title: product.title,
          image_url: product.image_url,
          canonical_url: product.canonical_url
        });

        // Cache current price
        if (product.current_price) {
          await this.setProductPrice(product.id, {
            price: product.current_price,
            currency: product.currency,
            last_checked: new Date()
          });
        }

        warmedCount++;
      }

      logger.info(`Cache warming completed: ${warmedCount} products cached`);
    } catch (error) {
      logger.error('Cache warming failed:', error);
      throw error;
    }
  }
}

module.exports = new Cache();
