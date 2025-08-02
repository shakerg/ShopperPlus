const { Pool } = require('pg');
const logger = require('../utils/logger');

class Database {
  constructor() {
    this.pool = null;
  }

  async connect() {
    try {
      const sslConfig = process.env.DB_SSL === 'true' 
        ? { rejectUnauthorized: false } 
        : false;

      this.pool = new Pool({
        host: process.env.DB_HOST,
        port: process.env.DB_PORT,
        database: process.env.DB_NAME,
        user: process.env.DB_USER,
        password: process.env.DB_PASSWORD,
        max: 20,
        idleTimeoutMillis: 30000,
        connectionTimeoutMillis: 2000,
        ssl: sslConfig
      });

      // Test connection
      const client = await this.pool.connect();
      await client.query('SELECT NOW()');
      client.release();
      
      logger.info('Database connection established');
    } catch (error) {
      logger.error('Database connection failed:', error);
      throw error;
    }
  }

  async disconnect() {
    if (this.pool) {
      await this.pool.end();
      logger.info('Database connection closed');
    }
  }

  async query(text, params) {
    const start = Date.now();
    try {
      const result = await this.pool.query(text, params);
      const duration = Date.now() - start;
      logger.debug('Query executed', { text, duration, rows: result.rowCount });
      return result;
    } catch (error) {
      logger.error('Database query error:', { text, params, error: error.message });
      throw error;
    }
  }

  async migrate() {
    try {
      logger.info('Running database migrations...');
      
      // Create tables if they don't exist
      await this.query(`
        CREATE TABLE IF NOT EXISTS products (
          id SERIAL PRIMARY KEY,
          canonical_url VARCHAR(2048) UNIQUE NOT NULL,
          title VARCHAR(1024),
          image_url VARCHAR(2048),
          current_price DECIMAL(10,2),
          currency VARCHAR(3) DEFAULT 'USD',
          last_checked TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          cache_ttl INTEGER DEFAULT 3600,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );
      `);

      await this.query(`
        CREATE TABLE IF NOT EXISTS price_history (
          id SERIAL PRIMARY KEY,
          product_id INTEGER REFERENCES products(id) ON DELETE CASCADE,
          price DECIMAL(10,2) NOT NULL,
          currency VARCHAR(3) DEFAULT 'USD',
          source VARCHAR(50) DEFAULT 'scraper',
          scraped_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );
      `);

      await this.query(`
        CREATE TABLE IF NOT EXISTS user_watchlist (
          id SERIAL PRIMARY KEY,
          user_id VARCHAR(255) NOT NULL,
          product_id INTEGER REFERENCES products(id) ON DELETE CASCADE,
          target_price DECIMAL(10,2),
          currency VARCHAR(3) DEFAULT 'USD',
          notifications_enabled BOOLEAN DEFAULT true,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          UNIQUE(user_id, product_id)
        );
      `);

      await this.query(`
        CREATE TABLE IF NOT EXISTS scrape_jobs (
          id SERIAL PRIMARY KEY,
          product_id INTEGER REFERENCES products(id) ON DELETE CASCADE,
          status VARCHAR(20) DEFAULT 'pending',
          tor_circuit_id VARCHAR(100),
          error_message TEXT,
          retry_count INTEGER DEFAULT 0,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          started_at TIMESTAMP,
          completed_at TIMESTAMP
        );
      `);

      // Create indexes for better performance
      await this.query(`
        CREATE INDEX IF NOT EXISTS idx_products_url ON products(canonical_url);
      `);
      
      await this.query(`
        CREATE INDEX IF NOT EXISTS idx_price_history_product_date ON price_history(product_id, scraped_at DESC);
      `);
      
      await this.query(`
        CREATE INDEX IF NOT EXISTS idx_user_watchlist_user ON user_watchlist(user_id);
      `);
      
      await this.query(`
        CREATE INDEX IF NOT EXISTS idx_scrape_jobs_status ON scrape_jobs(status, created_at);
      `);

      // Create trigger to update updated_at timestamp
      await this.query(`
        CREATE OR REPLACE FUNCTION update_updated_at_column()
        RETURNS TRIGGER AS $$
        BEGIN
          NEW.updated_at = CURRENT_TIMESTAMP;
          RETURN NEW;
        END;
        $$ language 'plpgsql';
      `);

      await this.query(`
        DROP TRIGGER IF EXISTS update_products_updated_at ON products;
        CREATE TRIGGER update_products_updated_at BEFORE UPDATE ON products
        FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
      `);

      await this.query(`
        DROP TRIGGER IF EXISTS update_user_watchlist_updated_at ON user_watchlist;
        CREATE TRIGGER update_user_watchlist_updated_at BEFORE UPDATE ON user_watchlist
        FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
      `);

      logger.info('Database migrations completed successfully');
    } catch (error) {
      logger.error('Database migration failed:', error);
      throw error;
    }
  }

  async cleanupOldData() {
    try {
      // Clean up old price history (keep last 90 days)
      const result = await this.query(`
        DELETE FROM price_history 
        WHERE created_at < NOW() - INTERVAL '90 days'
      `);
      
      // Clean up completed scrape jobs older than 7 days
      const result2 = await this.query(`
        DELETE FROM scrape_jobs 
        WHERE status IN ('completed', 'failed') 
        AND created_at < NOW() - INTERVAL '7 days'
      `);

      logger.info(`Cleanup completed: ${result.rowCount} price history records, ${result2.rowCount} scrape jobs removed`);
    } catch (error) {
      logger.error('Data cleanup failed:', error);
      throw error;
    }
  }
}

module.exports = new Database();
