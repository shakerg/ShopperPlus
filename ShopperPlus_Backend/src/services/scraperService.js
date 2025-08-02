const axios = require('axios');
const { SocksProxyAgent } = require('socks-proxy-agent');
const cheerio = require('cheerio');
const database = require('../config/database');
const cache = require('../config/cache');
const logger = require('../utils/logger');

class ScraperService {
  constructor() {
    this.torProxyHost = process.env.TOR_PROXY_HOST || 'localhost';
    this.torProxyPort = process.env.TOR_PROXY_PORT || 9050;
    this.maxConcurrentScrapers = parseInt(process.env.MAX_CONCURRENT_SCRAPERS) || 5;
    this.scraperDelay = parseInt(process.env.SCRAPER_DELAY_MS) || 2000;
    this.circuitRotationRequests = parseInt(process.env.CIRCUIT_ROTATION_REQUESTS) || 75;
    this.userAgents = [
      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1',
      'Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1',
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
    ];
    this.requestCount = 0;
    this.activeScrapers = 0;
  }

  async processQueue() {
    try {
      logger.info('Starting scraper queue processing');
      
      // Get pending scrape jobs
      const jobs = await database.query(
        `SELECT sj.id, sj.product_id, p.canonical_url, sj.retry_count
         FROM scrape_jobs sj
         JOIN products p ON sj.product_id = p.id
         WHERE sj.status = 'pending' AND sj.retry_count < 3
         ORDER BY sj.created_at ASC
         LIMIT $1`,
        [this.maxConcurrentScrapers * 2]
      );

      if (jobs.rows.length === 0) {
        logger.info('No pending scrape jobs found');
        return;
      }

      logger.info(`Found ${jobs.rows.length} pending scrape jobs`);

      // Process jobs with concurrency limit
      const chunks = this.chunkArray(jobs.rows, this.maxConcurrentScrapers);
      
      for (const chunk of chunks) {
        const promises = chunk.map(job => this.processJob(job));
        await Promise.allSettled(promises);
        
        // Delay between chunks to be respectful
        if (chunks.indexOf(chunk) < chunks.length - 1) {
          await this.delay(this.scraperDelay);
        }
      }

      logger.info('Scraper queue processing completed');
    } catch (error) {
      logger.error('Error processing scraper queue:', error);
      throw error;
    }
  }

  async processJob(job) {
    const { id: jobId, product_id: productId, canonical_url: url, retry_count: retryCount } = job;
    
    try {
      this.activeScrapers++;
      logger.info(`Processing scrape job ${jobId} for product ${productId}`);

      // Mark job as started
      await database.query(
        'UPDATE scrape_jobs SET status = $1, started_at = CURRENT_TIMESTAMP WHERE id = $2',
        ['running', jobId]
      );

      // Perform the scrape
      const productData = await this.scrapeProduct(url);

      if (productData) {
        // Update product data
        await database.query(
          `UPDATE products 
           SET title = COALESCE($1, title), 
               image_url = COALESCE($2, image_url),
               current_price = $3,
               currency = COALESCE($4, currency),
               last_checked = CURRENT_TIMESTAMP
           WHERE id = $5`,
          [productData.title, productData.imageUrl, productData.price, productData.currency, productId]
        );

        // Add to price history
        if (productData.price) {
          await database.query(
            'INSERT INTO price_history (product_id, price, currency, source) VALUES ($1, $2, $3, $4)',
            [productId, productData.price, productData.currency || 'USD', 'scraper']
          );
        }

        // Update cache
        await cache.setProductMeta(productId, {
          title: productData.title,
          image_url: productData.imageUrl,
          canonical_url: url
        });

        if (productData.price) {
          await cache.setProductPrice(productId, {
            price: productData.price,
            currency: productData.currency,
            last_checked: new Date()
          });
        }

        // Mark job as completed
        await database.query(
          'UPDATE scrape_jobs SET status = $1, completed_at = CURRENT_TIMESTAMP WHERE id = $2',
          ['completed', jobId]
        );

        // Check for price drop notifications
        await this.checkPriceDropNotifications(productId, productData.price);

        logger.info(`Successfully scraped product ${productId}: ${productData.title} - $${productData.price}`);
      } else {
        throw new Error('No product data extracted');
      }

    } catch (error) {
      logger.error(`Scrape job ${jobId} failed:`, error);

      // Update job with error
      await database.query(
        `UPDATE scrape_jobs 
         SET status = $1, error_message = $2, retry_count = retry_count + 1, completed_at = CURRENT_TIMESTAMP
         WHERE id = $3`,
        ['failed', error.message, jobId]
      );

      // Requeue if retries available
      if (retryCount < 2) {
        await database.query(
          'INSERT INTO scrape_jobs (product_id, status) VALUES ($1, $2)',
          [productId, 'pending']
        );
        logger.info(`Requeued job for product ${productId} (retry ${retryCount + 1}/3)`);
      }
    } finally {
      this.activeScrapers--;
    }
  }

  async scrapeProduct(url) {
    try {
      const domain = new URL(url).hostname;
      
      // Check domain rate limiting
      const lastScrapeKey = await cache.getDomainLastScrape(domain);
      if (lastScrapeKey) {
        const timeSinceLastScrape = Date.now() - parseInt(lastScrapeKey);
        if (timeSinceLastScrape < this.scraperDelay) {
          await this.delay(this.scraperDelay - timeSinceLastScrape);
        }
      }

      // Set up Tor proxy
      const proxyAgent = new SocksProxyAgent(`socks5://${this.torProxyHost}:${this.torProxyPort}`);
      
      // Rotate user agent
      const userAgent = this.userAgents[Math.floor(Math.random() * this.userAgents.length)];

      const axiosConfig = {
        httpsAgent: proxyAgent,
        httpAgent: proxyAgent,
        timeout: 30000,
        headers: {
          'User-Agent': userAgent,
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
          'Accept-Language': 'en-US,en;q=0.5',
          'Accept-Encoding': 'gzip, deflate',
          'Connection': 'keep-alive',
          'Upgrade-Insecure-Requests': '1'
        }
      };

      logger.debug(`Scraping ${url} through Tor proxy`);
      const response = await axios.get(url, axiosConfig);

      // Update domain scrape timestamp
      await cache.setDomainLastScrape(domain, Date.now().toString());

      // Increment request count for circuit rotation
      this.requestCount++;
      if (this.requestCount >= this.circuitRotationRequests) {
        await this.rotateCircuit();
        this.requestCount = 0;
      }

      // Parse the HTML
      const $ = cheerio.load(response.data);
      
      // Extract product data using common selectors
      const productData = this.extractProductData($, url);
      
      return productData;

    } catch (error) {
      logger.error(`Failed to scrape ${url}:`, error.message);
      
      // Fallback to direct connection if Tor fails
      if (error.message.includes('SOCKS') || error.message.includes('proxy')) {
        logger.warn(`Tor proxy failed for ${url}, attempting direct connection`);
        return await this.scrapeProductDirect(url);
      }
      
      throw error;
    }
  }

  async scrapeProductDirect(url) {
    try {
      const userAgent = this.userAgents[Math.floor(Math.random() * this.userAgents.length)];
      
      const response = await axios.get(url, {
        timeout: 15000,
        headers: {
          'User-Agent': userAgent,
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'en-US,en;q=0.5'
        }
      });

      const $ = cheerio.load(response.data);
      return this.extractProductData($, url);

    } catch (error) {
      logger.error(`Direct scraping failed for ${url}:`, error.message);
      throw error;
    }
  }

  extractProductData($, url) {
    const domain = new URL(url).hostname.toLowerCase();
    
    let title, price, imageUrl, currency = 'USD';

    // Amazon
    if (domain.includes('amazon.')) {
      title = $('#productTitle').text().trim() || 
              $('[data-cy="title"]').text().trim() ||
              $('.product-title').text().trim();
      
      price = $('.a-price-whole').first().text().replace(/[^0-9.]/g, '') ||
              $('.a-offscreen').first().text().replace(/[^0-9.]/g, '') ||
              $('.a-price .a-offscreen').first().text().replace(/[^0-9.]/g, '');
      
      imageUrl = $('#landingImage').attr('src') || 
                 $('.a-dynamic-image').first().attr('src') ||
                 $('img[data-old-hires]').first().attr('data-old-hires');
    }
    
    // Target
    else if (domain.includes('target.com')) {
      title = $('[data-test="product-title"]').text().trim() ||
              $('.ProductTitle').text().trim();
      
      price = $('[data-test="product-price"]').text().replace(/[^0-9.]/g, '') ||
              $('.Price').text().replace(/[^0-9.]/g, '');
      
      imageUrl = $('[data-test="hero-image-zoom-in"] img').attr('src') ||
                 $('.ProductImages img').first().attr('src');
    }
    
    // Walmart
    else if (domain.includes('walmart.com')) {
      title = $('[data-automation-id="product-title"]').text().trim() ||
              $('.prod-ProductTitle').text().trim();
      
      price = $('[data-automation-id="product-price"]').text().replace(/[^0-9.]/g, '') ||
              $('.price-current').text().replace(/[^0-9.]/g, '');
      
      imageUrl = $('[data-automation-id="hero-image"]').attr('src') ||
                 $('.prod-hero-image img').attr('src');
    }
    
    // Best Buy
    else if (domain.includes('bestbuy.com')) {
      title = $('.sku-title h1').text().trim() ||
              $('.sr-product-title').text().trim();
      
      price = $('.pricing-price__range').text().replace(/[^0-9.]/g, '') ||
              $('.sr-price').text().replace(/[^0-9.]/g, '');
      
      imageUrl = $('.primary-image').attr('src') ||
                 $('.hero-image img').attr('src');
    }
    
    // Generic fallback selectors
    else {
      // Try common title selectors
      title = $('h1').first().text().trim() ||
              $('.product-title, .product-name, .item-title').first().text().trim() ||
              $('[class*="title"], [class*="name"]').first().text().trim();
      
      // Try common price selectors
      const priceText = $('.price, .cost, .amount, [class*="price"], [class*="cost"]').first().text() ||
                       $('[data-price], [data-cost]').first().attr('data-price') ||
                       $('meta[property="product:price:amount"]').attr('content');
      
      price = priceText ? priceText.replace(/[^0-9.]/g, '') : null;
      
      // Try common image selectors
      imageUrl = $('meta[property="og:image"]').attr('content') ||
                 $('.product-image img, .item-image img').first().attr('src') ||
                 $('img[alt*="product"], img[alt*="item"]').first().attr('src');
    }

    // Clean up extracted data
    if (title) {
      title = title.substring(0, 500).trim();
    }
    
    if (price) {
      price = parseFloat(price);
      if (isNaN(price) || price <= 0) {
        price = null;
      }
    }

    if (imageUrl && !imageUrl.startsWith('http')) {
      const baseUrl = new URL(url);
      imageUrl = new URL(imageUrl, baseUrl.origin).href;
    }

    logger.debug('Extracted product data:', { title, price, imageUrl, url });

    return {
      title: title || null,
      price: price || null,
      imageUrl: imageUrl || null,
      currency
    };
  }

  async rotateCircuit() {
    try {
      logger.info('Rotating Tor circuit');
      
      // Send NEWNYM signal to Tor control port
      const controlAgent = new SocksProxyAgent(`socks5://${this.torProxyHost}:${process.env.TOR_CONTROL_PORT || 9051}`);
      
      // In a real implementation, you'd connect to the control port and send NEWNYM
      // For now, we'll just log and continue
      logger.info('Circuit rotation requested (implementation pending)');
      
    } catch (error) {
      logger.warn('Circuit rotation failed:', error.message);
    }
  }

  async checkPriceDropNotifications(productId, currentPrice) {
    try {
      if (!currentPrice) return;

      // Get users watching this product with target prices
      const watchers = await database.query(
        `SELECT uw.user_id, uw.target_price, p.title, p.canonical_url
         FROM user_watchlist uw
         JOIN products p ON uw.product_id = p.id
         WHERE uw.product_id = $1 
         AND uw.target_price IS NOT NULL 
         AND uw.notifications_enabled = true
         AND $2 <= uw.target_price`,
        [productId, currentPrice]
      );

      if (watchers.rows.length > 0) {
        logger.info(`Price drop detected for product ${productId}: $${currentPrice}`);
        
        for (const watcher of watchers.rows) {
          // Send notification (implementation would go here)
          logger.info(`Sending price drop notification to user ${watcher.user_id}`);
          
          // TODO: Implement actual push notification using Apple Push Notifications
          // const notificationService = require('../services/notificationService');
          // await notificationService.sendPriceDropNotification(watcher);
        }
      }
    } catch (error) {
      logger.error('Error checking price drop notifications:', error);
    }
  }

  chunkArray(array, size) {
    const chunks = [];
    for (let i = 0; i < array.length; i += size) {
      chunks.push(array.slice(i, i + size));
    }
    return chunks;
  }

  delay(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
}

module.exports = new ScraperService();
