const express = require('express');
const Joi = require('joi');
const database = require('../config/database');
const cache = require('../config/cache');
const scraperService = require('../services/scraperService');
const notificationService = require('../services/notificationService');
const logger = require('../utils/logger');

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

// POST /api/sync - Sync user watchlist from CloudKit
router.post('/sync', async (req, res, next) => {
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

// GET /api/price/:productId - Get current price for a product
router.get('/price/:productId', async (req, res, next) => {
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

// POST /api/product - Add a new product for monitoring
router.post('/product', async (req, res, next) => {
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

// GET /api/products - Get all products for a user
router.get('/products', async (req, res, next) => {
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

// DELETE /api/watchlist/:userId/:productId - Remove product from user's watchlist
router.delete('/watchlist/:userId/:productId', async (req, res, next) => {
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

module.exports = router;
