// Only load dotenv if .env file exists (for local development)
const fs = require('fs');
if (fs.existsSync('.env')) {
  require('dotenv').config();
}
const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const compression = require('compression');
const morgan = require('morgan');
const cron = require('node-cron');

const logger = require('./utils/logger');
const database = require('./config/database');
const cache = require('./config/cache');
const apiRoutes = require('./api/routes');
const scraperWorker = require('./scrapers/worker');
const { rateLimiter } = require('./middleware/rateLimiter');
const errorHandler = require('./middleware/errorHandler');

const app = express();
const PORT = process.env.PORT || 3000;

// Security middleware
app.use(helmet());
app.use(cors({
  origin: process.env.CORS_ORIGIN || '*',
  credentials: true
}));

// Request parsing and compression
app.use(compression());
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// Logging
app.use(morgan('combined', { stream: { write: message => logger.info(message.trim()) } }));

// Rate limiting
app.use(rateLimiter);

// Health check endpoint
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    memory: process.memoryUsage(),
    version: process.env.npm_package_version || '1.0.0'
  });
});

// API routes
app.use('/api', apiRoutes);

// Error handling
app.use(errorHandler);

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({
    error: 'Not Found',
    message: 'The requested resource was not found'
  });
});

// Initialize services
async function initializeServices() {
  try {
    // Initialize database connection
    await database.connect();
    logger.info('Database connected successfully');

    // Initialize cache connection
    await cache.connect();
    logger.info('Cache connected successfully');

    // Run database migrations if needed
    await database.migrate();
    logger.info('Database migrations completed');

    // Start the HTTP server
    const server = app.listen(PORT, '0.0.0.0', () => {
      logger.info(`Shopper+ Backend started on port ${PORT}`);
    });

    // Schedule background jobs
    scheduleJobs();

    // Graceful shutdown
    process.on('SIGTERM', () => gracefulShutdown(server));
    process.on('SIGINT', () => gracefulShutdown(server));

  } catch (error) {
    logger.error('Failed to initialize services:', error);
    process.exit(1);
  }
}

// Schedule background jobs
function scheduleJobs() {
  // Run price updates every 30 minutes
  cron.schedule('*/30 * * * *', async () => {
    logger.info('Starting scheduled price update job');
    try {
      await scraperWorker.processQueue();
    } catch (error) {
      logger.error('Price update job failed:', error);
    }
  });

  // Clean up old price history daily at 2 AM
  cron.schedule('0 2 * * *', async () => {
    logger.info('Starting cleanup job');
    try {
      await database.cleanupOldData();
    } catch (error) {
      logger.error('Cleanup job failed:', error);
    }
  });

  // Cache warming every 6 hours
  cron.schedule('0 */6 * * *', async () => {
    logger.info('Starting cache warming job');
    try {
      await cache.warmCache();
    } catch (error) {
      logger.error('Cache warming job failed:', error);
    }
  });

  logger.info('Background jobs scheduled successfully');
}

// Graceful shutdown
async function gracefulShutdown(server) {
  logger.info('Received shutdown signal, starting graceful shutdown...');
  
  // Stop accepting new connections
  server.close(async () => {
    try {
      // Close database connections
      await database.disconnect();
      logger.info('Database connections closed');

      // Close cache connections
      await cache.disconnect();
      logger.info('Cache connections closed');

      logger.info('Graceful shutdown completed');
      process.exit(0);
    } catch (error) {
      logger.error('Error during shutdown:', error);
      process.exit(1);
    }
  });

  // Force shutdown after 30 seconds
  setTimeout(() => {
    logger.error('Forced shutdown due to timeout');
    process.exit(1);
  }, 30000);
}

// Start the application
if (require.main === module) {
  initializeServices();
}

module.exports = app;
