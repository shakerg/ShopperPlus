#!/usr/bin/env node

/**
 * Scraper Worker - Standalone worker process for background scraping
 * Can be run independently or triggered by the main application
 */

// Only load dotenv if .env file exists (for local development)
const fs = require('fs');
if (fs.existsSync('.env')) {
  require('dotenv').config();
}
const logger = require('../utils/logger');
const database = require('../config/database');
const cache = require('../config/cache');
const scraperService = require('../services/scraperService');

class ScraperWorker {
  constructor() {
    this.isRunning = false;
    this.shouldStop = false;
  }

  async start() {
    try {
      if (this.isRunning) {
        logger.warn('Scraper worker is already running');
        return;
      }

      logger.info('Starting scraper worker...');
      this.isRunning = true;

      // Initialize connections
      await database.connect();
      await cache.connect();

      logger.info('Scraper worker started successfully');

      // Process queue once
      await this.processQueue();

    } catch (error) {
      logger.error('Failed to start scraper worker:', error);
      throw error;
    } finally {
      this.isRunning = false;
    }
  }

  async processQueue() {
    try {
      if (this.shouldStop) {
        logger.info('Scraper worker stop requested');
        return;
      }

      await scraperService.processQueue();
      
    } catch (error) {
      logger.error('Error in scraper worker queue processing:', error);
      throw error;
    }
  }

  async stop() {
    logger.info('Stopping scraper worker...');
    this.shouldStop = true;
    
    // Wait for current operations to complete
    while (this.isRunning) {
      await new Promise(resolve => setTimeout(resolve, 100));
    }

    // Close connections
    await database.disconnect();
    await cache.disconnect();
    
    logger.info('Scraper worker stopped');
  }
}

// Handle graceful shutdown
const worker = new ScraperWorker();

process.on('SIGTERM', async () => {
  logger.info('Received SIGTERM, shutting down scraper worker...');
  await worker.stop();
  process.exit(0);
});

process.on('SIGINT', async () => {
  logger.info('Received SIGINT, shutting down scraper worker...');
  await worker.stop();
  process.exit(0);
});

// Export for use by main application
module.exports = {
  processQueue: () => scraperService.processQueue()
};

// Run if called directly
if (require.main === module) {
  const runContinuous = process.env.SCRAPER_CONTINUOUS === 'true';
  
  if (runContinuous) {
    // Kubernetes mode: run continuously
    worker.start()
      .then(async () => {
        logger.info('Scraper worker started in continuous mode');
        
        // Keep running and check for jobs periodically
        const intervalMs = parseInt(process.env.SCRAPER_INTERVAL_MS) || 30000; // 30 seconds default
        
        setInterval(async () => {
          try {
            if (!worker.shouldStop) {
              await worker.processQueue();
            }
          } catch (error) {
            logger.error('Error in periodic queue processing:', error);
          }
        }, intervalMs);
        
        // Keep the process alive
        process.on('SIGTERM', async () => {
          logger.info('Received SIGTERM, shutting down scraper worker...');
          await worker.stop();
          process.exit(0);
        });
        
        process.on('SIGINT', async () => {
          logger.info('Received SIGINT, shutting down scraper worker...');
          await worker.stop();
          process.exit(0);
        });
      })
      .catch((error) => {
        logger.error('Scraper worker failed to start:', error);
        process.exit(1);
      });
  } else {
    // One-time mode: run once and exit
    worker.start()
      .then(() => {
        logger.info('Scraper worker completed successfully');
        process.exit(0);
      })
      .catch((error) => {
        logger.error('Scraper worker failed:', error);
        process.exit(1);
      });
  }
}
