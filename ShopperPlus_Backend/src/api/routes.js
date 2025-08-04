const express = require('express');
const Joi = require('joi');
const database = require('../config/database');
const cache = require('../config/cache');
const scraperService = require('../services/scraperService');
const notificationService = require('../services/notificationService');
const logger = require('../utils/logger');

// Import admin routes
const adminRoutes = require('./admin');

const router = express.Router();

// Validation schemas
const syncSchema = Joi.object({
  userId: Joi.string().required(),
  products: Joi.array().items(
    Joi.object({
      url: Joi.string().uri().required(),
      targetPrice: Joi.number().positive().optional()
    })
  ).required()
});

const productSchema = Joi.object({
  url: Joi.string().uri().required()
});

const priceCheckSchema = Joi.object({
  url: Joi.string().uri().required()
});

const syncRequestSchema = Joi.object({
  items: Joi.array().items(
    Joi.object({
      id: Joi.string().required(),
      url: Joi.string().uri().required(),
      lastUpdated: Joi.date().required()
    })
  ).required()
});

const notificationSchema = Joi.object({
  deviceToken: Joi.string().required(),
  userId: Joi.string().required(),
  platform: Joi.string().valid('ios', 'android').required()
});

// Add CORS headers middleware for all routes
router.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  res.header('Access-Control-Allow-Headers', 'Origin, X-Requested-With, Content-Type, Accept, Authorization');
  
  if (req.method === 'OPTIONS') {
    res.sendStatus(200);
  } else {
    next();
  }
});

// Create v1 router
const v1Router = express.Router();

// POST /api/v1/sync - Sync user watchlist from CloudKit
v1Router.post('/sync', async (req, res, next) => {
  try {
    const { error, value } = syncSchema.validate(req.body);
    if (error) {
      return res.status(400).json({
        success: false,
        error: 'Validation Error',
        details: error.details[0].message
      });
    }

    const { userId, products } = value;

    // Check cache first
    const cachedSync = await cache.getUserSync(userId);
    if (cachedSync) {
      return res.json({
        success: true,
        message: 'Sync data from cache',
        data: cachedSync,
        cached: true
      });
    }

    const results = [];
    
    for (const productData of products) {
      try {
        // Check if product exists
        let productResult = await database.query(
          'SELECT id, current_price, currency, last_checked FROM products WHERE canonical_url = $1',
          [productData.url]
        );

        let productId;
        
        if (productResult.rows.length === 0) {
          // Create new product
          const insertResult = await database.query(
            'INSERT INTO products (canonical_url) VALUES ($1) RETURNING id',
            [productData.url]
          );
          productId = insertResult.rows[0].id;
          
          // Queue for scraping
          await database.query(
            'INSERT INTO scrape_jobs (product_id, status) VALUES ($1, $2)',
            [productId, 'pending']
          );
          
          results.push({
            url: productData.url,
            productId,
            status: 'created',
            message: 'Product added to watchlist and queued for scraping'
          });
        } else {
          productId = productResult.rows[0].id;
          const lastChecked = productResult.rows[0].last_checked;
          const cacheAge = Date.now() - new Date(lastChecked).getTime();
          
          // If data is older than 1 hour, queue for re-scraping
          if (cacheAge > 3600000) {
            await database.query(
              'INSERT INTO scrape_jobs (product_id, status) VALUES ($1, $2)',
              [productId, 'pending']
            );
            
            results.push({
              url: productData.url,
              productId,
              currentPrice: productResult.rows[0].current_price,
              currency: productResult.rows[0].currency,
              lastChecked: lastChecked,
              status: 'queued_for_update',
              message: 'Product found, queued for price update'
            });
          } else {
            results.push({
              url: productData.url,
              productId,
              currentPrice: productResult.rows[0].current_price,
              currency: productResult.rows[0].currency,
              lastChecked: lastChecked,
              status: 'current',
              message: 'Product price is current'
            });
          }
        }

        // Update user watchlist
        await database.query(
          `INSERT INTO user_watchlist (user_id, product_id, target_price)
           VALUES ($1, $2, $3)
           ON CONFLICT (user_id, product_id) 
           DO UPDATE SET target_price = $3, updated_at = CURRENT_TIMESTAMP`,
          [userId, productId, productData.targetPrice || null]
        );

      } catch (productError) {
        logger.error('Error processing product:', { url: productData.url, error: productError.message });
        results.push({
          url: productData.url,
          status: 'error',
          message: productError.message
        });
      }
    }

    const responseData = {
      userId,
      products: results,
      syncedAt: new Date().toISOString()
    };

    // Cache the response
    await cache.setUserSync(userId, responseData);

    res.json({
      success: true,
      message: 'Sync completed successfully',
      data: responseData
    });

  } catch (error) {
    next(error);
  }
});

// GET /api/v1/price/:productId - Get current price for a product
v1Router.get('/price/:productId', async (req, res, next) => {
  try {
    const productId = parseInt(req.params.productId);
    
    if (isNaN(productId)) {
      return res.status(400).json({
        success: false,
        error: 'Invalid product ID'
      });
    }

    // Check cache first
    const cachedPrice = await cache.getProductPrice(productId);
    if (cachedPrice) {
      return res.json({
        success: true,
        data: cachedPrice,
        cached: true
      });
    }

    // Get from database
    const result = await database.query(
      `SELECT p.id, p.canonical_url, p.title, p.image_url, p.current_price, 
              p.currency, p.last_checked,
              (SELECT json_agg(json_build_object('price', price, 'date', scraped_at)) 
               FROM (SELECT price, scraped_at FROM price_history 
                     WHERE product_id = p.id 
                     ORDER BY scraped_at DESC LIMIT 10) ph) as price_history
       FROM products p 
       WHERE p.id = $1`,
      [productId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'Product not found'
      });
    }

    const product = result.rows[0];
    
    // Cache the result
    await cache.setProductPrice(productId, product);

    res.json({
      success: true,
      data: product,
      cached: false
    });

  } catch (error) {
    next(error);
  }
});

// POST /api/v1/product - Add a new product for monitoring
v1Router.post('/product', async (req, res, next) => {
  try {
    const { error, value } = productSchema.validate(req.body);
    if (error) {
      return res.status(400).json({
        success: false,
        error: 'Validation Error',
        details: error.details[0].message
      });
    }

    const { url } = value;

    // Check if product already exists
    const existingProduct = await database.query(
      'SELECT id FROM products WHERE canonical_url = $1',
      [url]
    );

    if (existingProduct.rows.length > 0) {
      return res.json({
        success: true,
        data: {
          productId: existingProduct.rows[0].id,
          message: 'Product already exists'
        }
      });
    }

    // Create new product
    const result = await database.query(
      'INSERT INTO products (canonical_url) VALUES ($1) RETURNING id',
      [url]
    );

    const productId = result.rows[0].id;

    // Queue for immediate scraping
    await database.query(
      'INSERT INTO scrape_jobs (product_id, status) VALUES ($1, $2)',
      [productId, 'pending']
    );

    // Trigger scraping process
    scraperService.processQueue().catch(error => {
      logger.error('Failed to trigger scraper:', error);
    });

    res.status(201).json({
      success: true,
      data: {
        productId,
        url,
        status: 'created',
        message: 'Product created and queued for scraping'
      }
    });

  } catch (error) {
    next(error);
  }
});

// GET /api/v1/products - Get all products for a user
v1Router.get('/products', async (req, res, next) => {
  try {
    const { userId } = req.query;
    
    if (!userId) {
      return res.status(400).json({
        success: false,
        error: 'userId parameter is required'
      });
    }

    const result = await database.query(
      `SELECT p.id, p.canonical_url, p.title, p.image_url, p.current_price, 
              p.currency, p.last_checked, uw.target_price, uw.notifications_enabled
       FROM products p
       JOIN user_watchlist uw ON p.id = uw.product_id
       WHERE uw.user_id = $1
       ORDER BY uw.updated_at DESC`,
      [userId]
    );

    res.json({
      success: true,
      data: result.rows
    });

  } catch (error) {
    next(error);
  }
});

// DELETE /api/v1/watchlist/:userId/:productId - Remove product from user's watchlist
v1Router.delete('/watchlist/:userId/:productId', async (req, res, next) => {
  try {
    const { userId, productId } = req.params;
    
    const result = await database.query(
      'DELETE FROM user_watchlist WHERE user_id = $1 AND product_id = $2',
      [userId, parseInt(productId)]
    );

    if (result.rowCount === 0) {
      return res.status(404).json({
        success: false,
        error: 'Watchlist entry not found'
      });
    }

    res.json({
      success: true,
      message: 'Product removed from watchlist'
    });

  } catch (error) {
    next(error);
  }
});

// POST /api/v1/products/info - Get product information with synchronous scraping
v1Router.post('/products/info', async (req, res, next) => {
  try {
    logger.info('Product info request received:', req.body);
    
    const { error, value } = productSchema.validate(req.body);
    if (error) {
      logger.warn('Validation error:', error.details[0].message);
      return res.status(400).json({
        success: false,
        error: 'Validation Error',
        details: error.details[0].message
      });
    }

    const { url } = value;
    logger.info(`Processing product info request for: ${url}`);

    // Check if product already exists and has recent data
    const existingProduct = await database.query(
      `SELECT id, title, image_url, current_price, currency, last_checked, 
              created_at
       FROM products 
       WHERE canonical_url = $1`,
      [url]
    );

    if (existingProduct.rows.length > 0) {
      const product = existingProduct.rows[0];
      const lastChecked = product.last_checked;
      const dataAge = lastChecked ? Date.now() - new Date(lastChecked).getTime() : Infinity;
      
      // If data is less than 1 hour old and has real product data, return it immediately
      if (dataAge < 3600000 && product.title && 
          product.title !== 'Loading product info...' && 
          !product.title.startsWith('Loading')) {
        logger.info(`Returning cached product data for: ${url}`);
        return res.json({
          title: product.title || 'Product',
          price: product.current_price,
          currency: product.currency || 'USD',
          imageUrl: product.image_url,
          availability: product.current_price ? 'Available' : 'Unknown',
          lastUpdated: product.last_checked || product.created_at
        });
      }
    }

    // Create new product or update existing one that needs refresh
    let productId, createdAt;
    
    if (existingProduct.rows.length > 0) {
      // Update existing product
      productId = existingProduct.rows[0].id;
      createdAt = existingProduct.rows[0].created_at;
      logger.info(`Refreshing existing product ${productId} for: ${url}`);
    } else {
      // Create new product
      const result = await database.query(
        'INSERT INTO products (canonical_url) VALUES ($1) RETURNING id, created_at',
        [url]
      );
      productId = result.rows[0].id;
      createdAt = result.rows[0].created_at;
      logger.info(`Created new product ${productId} for: ${url}`);
    }

    // Scrape directly instead of using the queue system
    try {
      logger.info(`Starting direct scraping for product ${productId}: ${url}`);
      
      // Scrape the product directly
      const scrapedData = await scraperService.scrapeProductDirect(url);
      
      if (scrapedData && scrapedData.title) {
        // Update the product with scraped data
        await database.query(
          `UPDATE products 
           SET title = $1, current_price = $2, currency = $3, image_url = $4, 
               last_checked = CURRENT_TIMESTAMP 
           WHERE id = $5`,
          [scrapedData.title, scrapedData.price, scrapedData.currency || 'USD', 
           scrapedData.imageUrl, productId]
        );
        
        logger.info(`Successfully scraped product ${productId}: ${scrapedData.title}`);
        
        return res.json({
          title: scrapedData.title,
          price: scrapedData.price,
          currency: scrapedData.currency || 'USD',
          imageUrl: scrapedData.imageUrl,
          availability: scrapedData.price ? 'Available' : 'Unknown',
          lastUpdated: new Date().toISOString()
        });
      } else {
        logger.warn(`Scraping failed for product ${productId}: ${url}`);
        
        return res.json({
          title: 'Product information unavailable',
          price: null,
          currency: 'USD',
          imageUrl: null,
          availability: 'Unknown',
          lastUpdated: new Date().toISOString()
        });
      }
      
    } catch (scrapingError) {
      logger.error(`Scraping error for product ${productId}:`, scrapingError);
      
      return res.status(500).json({
        success: false,
        error: 'Scraping failed',
        details: scrapingError.message
      });
    }

  } catch (error) {
    next(error);
  }
});

// POST /api/v1/prices/check - Check current price for a URL (iOS app compatibility)
v1Router.post('/prices/check', async (req, res, next) => {
  try {
    const { error, value } = productSchema.validate(req.body);
    if (error) {
      return res.status(400).json({
        success: false,
        error: 'Validation Error',
        details: error.details[0].message
      });
    }

    const { url } = value;

    // Check if product exists
    const product = await database.query(
      `SELECT id, title, current_price, currency, last_checked, created_at
       FROM products 
       WHERE canonical_url = $1`,
      [url]
    );

    if (product.rows.length === 0) {
      return res.json({
        price: null,
        currency: 'USD',
        availability: 'Not found',
        lastUpdated: new Date(),
        success: false,
        error: 'Product not found'
      });
    }

    const productData = product.rows[0];
    
    // Check if price data is stale (older than 1 hour)
    const lastChecked = new Date(productData.last_checked || productData.created_at);
    const isStale = Date.now() - lastChecked.getTime() > 3600000; // 1 hour

    if (isStale) {
      // Queue for re-scraping
      await database.query(
        'INSERT INTO scrape_jobs (product_id, status) VALUES ($1, $2)',
        [productData.id, 'pending']
      );
      
      // Trigger scraping process
      scraperService.processQueue().catch(error => {
        logger.error('Failed to trigger scraper:', error);
      });
    }

    res.json({
      price: productData.current_price,
      currency: productData.currency || 'USD',
      availability: productData.current_price ? 'Available' : 'Unknown',
      lastUpdated: lastChecked,
      success: true,
      error: null
    });

  } catch (error) {
    next(error);
  }
});

// POST /api/v1/prices/sync - Sync prices for multiple items (iOS app compatibility)
v1Router.post('/prices/sync', async (req, res, next) => {
  try {
    // Validate the sync request structure
    const syncRequestSchema = Joi.object({
      items: Joi.array().items(
        Joi.object({
          id: Joi.string().required(),
          url: Joi.string().uri().required(),
          lastUpdated: Joi.date().required()
        })
      ).required()
    });

    const { error, value } = syncRequestSchema.validate(req.body);
    if (error) {
      return res.status(400).json({
        success: false,
        error: 'Validation Error',
        details: error.details[0].message
      });
    }

    const { items } = value;
    const updates = [];

    for (const item of items) {
      try {
        // Check if product exists
        const product = await database.query(
          `SELECT id, title, current_price, currency, last_checked, created_at
           FROM products 
           WHERE canonical_url = $1`,
          [item.url]
        );

        if (product.rows.length === 0) {
          // Product doesn't exist, create it
          const newProduct = await database.query(
            'INSERT INTO products (canonical_url) VALUES ($1) RETURNING id, created_at',
            [item.url]
          );

          const productId = newProduct.rows[0].id;
          const createdAt = newProduct.rows[0].created_at;

          // Queue for scraping
          await database.query(
            'INSERT INTO scrape_jobs (product_id, status) VALUES ($1, $2)',
            [productId, 'pending']
          );

          updates.push({
            id: item.id,
            price: null,
            currency: 'USD',
            availability: 'Checking...',
            lastUpdated: createdAt,
            success: true,
            error: null
          });
        } else {
          const productData = product.rows[0];
          const lastChecked = new Date(productData.last_checked || productData.created_at);
          const clientLastUpdated = new Date(item.lastUpdated);
          
          // Check if we need to update
          const needsUpdate = lastChecked < clientLastUpdated || 
                            Date.now() - lastChecked.getTime() > 3600000; // 1 hour

          if (needsUpdate) {
            // Queue for re-scraping
            await database.query(
              'INSERT INTO scrape_jobs (product_id, status) VALUES ($1, $2)',
              [productData.id, 'pending']
            );
          }

          updates.push({
            id: item.id,
            price: productData.current_price,
            currency: productData.currency || 'USD',
            availability: productData.current_price ? 'Available' : 'Unknown',
            lastUpdated: lastChecked,
            success: true,
            error: null
          });
        }
      } catch (itemError) {
        logger.error('Error processing sync item:', { url: item.url, error: itemError.message });
        updates.push({
          id: item.id,
          price: null,
          currency: 'USD',
          availability: 'Error',
          lastUpdated: new Date(),
          success: false,
          error: itemError.message
        });
      }
    }

    // Trigger scraping process for any queued items
    scraperService.processQueue().catch(error => {
      logger.error('Failed to trigger scraper:', error);
    });

    res.json({
      updates,
      success: true,
      timestamp: new Date()
    });

  } catch (error) {
    next(error);
  }
});

// POST /api/v1/notifications/register - Register device for push notifications
v1Router.post('/notifications/register', async (req, res, next) => {
  try {
    const notificationSchema = Joi.object({
      deviceToken: Joi.string().required(),
      userId: Joi.string().required(),
      platform: Joi.string().valid('ios', 'android').required()
    });

    const { error, value } = notificationSchema.validate(req.body);
    if (error) {
      return res.status(400).json({
        success: false,
        error: 'Validation Error',
        details: error.details[0].message
      });
    }

    const { deviceToken, userId, platform } = value;

    // For now, just log the registration (you can expand this later)
    logger.info('Device registered for notifications:', {
      userId,
      platform,
      deviceToken: deviceToken.substring(0, 10) + '...' // Log partial token for security
    });

    // TODO: Store device tokens in database and integrate with push notification service
    // For now, just return success
    res.json({
      success: true,
      message: 'Device registered for notifications'
    });

  } catch (error) {
    next(error);
  }
});

// Mount v1 routes under /api/v1
router.use('/v1', v1Router);

// POST /api/scrape/trigger - Manually trigger scraping (for testing)
router.post('/scrape/trigger', async (req, res, next) => {
  try {
    const { productId } = req.body;
    
    if (productId) {
      // Trigger scraping for specific product
      await database.query(
        'INSERT INTO scrape_jobs (product_id, status) VALUES ($1, $2)',
        [parseInt(productId), 'pending']
      );
    }

    // Start processing queue
    scraperService.processQueue().catch(error => {
      logger.error('Failed to trigger scraper:', error);
    });

    res.json({
      success: true,
      message: 'Scraping triggered successfully'
    });

  } catch (error) {
    next(error);
  }
});

// Mount admin routes under /api/admin
router.use('/admin', adminRoutes);

module.exports = router;
