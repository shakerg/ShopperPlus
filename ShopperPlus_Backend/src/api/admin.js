const express = require('express');
const path = require('path');
const database = require('../config/database');
const logger = require('../utils/logger');

const router = express.Router();

// Serve static files for the admin portal
router.use('/static', (req, res, next) => {
  res.setHeader('Content-Security-Policy', 
    "default-src 'self'; " +
    "script-src 'self' 'unsafe-eval' 'unsafe-inline'; " +
    "style-src 'self' 'unsafe-inline'; " +
    "img-src 'self' data: blob:; " +
    "font-src 'self' data:; " +
    "connect-src 'self';"
  );
  next();
}, express.static(path.join(__dirname, '../public')));

router.use('/css', (req, res, next) => {
  res.setHeader('Content-Security-Policy', 
    "default-src 'self'; " +
    "script-src 'self' 'unsafe-eval' 'unsafe-inline'; " +
    "style-src 'self' 'unsafe-inline'; " +
    "img-src 'self' data: blob:; " +
    "font-src 'self' data:; " +
    "connect-src 'self';"
  );
  next();
}, express.static(path.join(__dirname, '../public/css')));

router.use('/js', (req, res, next) => {
  res.setHeader('Content-Security-Policy', 
    "default-src 'self'; " +
    "script-src 'self' 'unsafe-eval' 'unsafe-inline'; " +
    "style-src 'self' 'unsafe-inline'; " +
    "img-src 'self' data: blob:; " +
    "font-src 'self' data:; " +
    "connect-src 'self';"
  );
  next();
}, express.static(path.join(__dirname, '../public/js')));

// Main admin portal route
router.get('/', (req, res) => {
  // Set more permissive CSP for admin portal to allow Chart.js
  res.setHeader('Content-Security-Policy', 
    "default-src 'self'; " +
    "script-src 'self' 'unsafe-eval' 'unsafe-inline'; " +
    "style-src 'self' 'unsafe-inline'; " +
    "img-src 'self' data: blob:; " +
    "font-src 'self' data:; " +
    "connect-src 'self';"
  );
  res.sendFile(path.join(__dirname, '../public/index.html'));
});

// Favicon for admin portal
router.get('/favicon.ico', (req, res) => {
  res.status(204).end();
});

// Legacy dashboard view route (redirect to main portal)
router.get('/dashboard/view', (req, res) => {
  res.redirect('/api/admin/');
});

// Admin dashboard route
router.get('/dashboard', async (req, res, next) => {
  try {
    logger.info('Admin dashboard accessed', { ip: req.ip, userAgent: req.get('User-Agent') });

    // Get user statistics
    const userStats = await database.query(`
      SELECT 
        COUNT(DISTINCT user_id) as total_users,
        COUNT(*) as total_watchlist_items,
        ROUND(AVG(items_per_user), 2) as avg_items_per_user,
        MAX(items_per_user) as max_items_per_user
      FROM (
        SELECT 
          user_id,
          COUNT(*) as items_per_user
        FROM user_watchlist 
        GROUP BY user_id
      ) user_counts
    `);

    // Get domain statistics
    const domainStats = await database.query(`
      SELECT 
        CASE 
          WHEN canonical_url ILIKE '%amazon.%' OR canonical_url ILIKE '%a.co/%' THEN 'Amazon'
          WHEN canonical_url ILIKE '%bestbuy.%' THEN 'Best Buy'
          WHEN canonical_url ILIKE '%target.%' THEN 'Target'
          WHEN canonical_url ILIKE '%wayfair.%' THEN 'Wayfair'
          WHEN canonical_url ILIKE '%walmart.%' THEN 'Walmart'
          WHEN canonical_url ILIKE '%ebay.%' THEN 'eBay'
          WHEN canonical_url ILIKE '%costco.%' THEN 'Costco'
          WHEN canonical_url ILIKE '%homedepot.%' THEN 'Home Depot'
          WHEN canonical_url ILIKE '%lowes.%' THEN 'Lowes'
          ELSE 'Other'
        END as domain,
        COUNT(*) as product_count,
        COUNT(DISTINCT uw.user_id) as unique_users_tracking,
        ROUND(AVG(p.current_price), 2) as avg_price,
        MIN(p.current_price) as min_price,
        MAX(p.current_price) as max_price
      FROM products p
      LEFT JOIN user_watchlist uw ON p.id = uw.product_id
      WHERE p.canonical_url IS NOT NULL
      GROUP BY 
        CASE 
          WHEN canonical_url ILIKE '%amazon.%' OR canonical_url ILIKE '%a.co/%' THEN 'Amazon'
          WHEN canonical_url ILIKE '%bestbuy.%' THEN 'Best Buy'
          WHEN canonical_url ILIKE '%target.%' THEN 'Target'
          WHEN canonical_url ILIKE '%wayfair.%' THEN 'Wayfair'
          WHEN canonical_url ILIKE '%walmart.%' THEN 'Walmart'
          WHEN canonical_url ILIKE '%ebay.%' THEN 'eBay'
          WHEN canonical_url ILIKE '%costco.%' THEN 'Costco'
          WHEN canonical_url ILIKE '%homedepot.%' THEN 'Home Depot'
          WHEN canonical_url ILIKE '%lowes.%' THEN 'Lowes'
          ELSE 'Other'
        END
      ORDER BY product_count DESC
    `);

    // Get product statistics
    const productStats = await database.query(`
      SELECT 
        COUNT(*) as total_products,
        COUNT(CASE WHEN current_price IS NOT NULL THEN 1 END) as products_with_price,
        COUNT(CASE WHEN image_url IS NOT NULL THEN 1 END) as products_with_image,
        COUNT(CASE WHEN title IS NOT NULL AND title != 'Product' THEN 1 END) as products_with_title,
        ROUND(AVG(current_price), 2) as avg_product_price,
        COUNT(CASE WHEN last_checked > NOW() - INTERVAL '24 hours' THEN 1 END) as recently_checked
      FROM products
    `);

    // Get scraping statistics
    const scrapingStats = await database.query(`
      SELECT 
        COUNT(*) as total_scrape_jobs,
        COUNT(CASE WHEN status = 'completed' THEN 1 END) as completed_jobs,
        COUNT(CASE WHEN status = 'failed' THEN 1 END) as failed_jobs,
        COUNT(CASE WHEN status = 'pending' THEN 1 END) as pending_jobs,
        COUNT(CASE WHEN created_at > NOW() - INTERVAL '24 hours' THEN 1 END) as jobs_last_24h,
        ROUND(
          (COUNT(CASE WHEN status = 'completed' THEN 1 END) * 100.0 / NULLIF(COUNT(*), 0)), 
          2
        ) as success_rate
      FROM scrape_jobs
    `);

    // Get user activity statistics
    const activityStats = await database.query(`
      SELECT 
        COUNT(CASE WHEN created_at > NOW() - INTERVAL '24 hours' THEN 1 END) as new_items_24h,
        COUNT(CASE WHEN created_at > NOW() - INTERVAL '7 days' THEN 1 END) as new_items_7d,
        COUNT(CASE WHEN created_at > NOW() - INTERVAL '30 days' THEN 1 END) as new_items_30d,
        COUNT(CASE WHEN notifications_enabled = true THEN 1 END) as items_with_notifications
      FROM user_watchlist
    `);

    // Get price history statistics
    const priceHistoryStats = await database.query(`
      SELECT 
        COUNT(*) as total_price_entries,
        COUNT(DISTINCT product_id) as products_with_history,
        COUNT(CASE WHEN scraped_at > NOW() - INTERVAL '24 hours' THEN 1 END) as price_checks_24h
      FROM price_history
    `);

    const analytics = {
      overview: {
        total_users: parseInt(userStats.rows[0].total_users) || 0,
        total_watchlist_items: parseInt(userStats.rows[0].total_watchlist_items) || 0,
        avg_items_per_user: parseFloat(userStats.rows[0].avg_items_per_user) || 0,
        max_items_per_user: parseInt(userStats.rows[0].max_items_per_user) || 0,
        total_products: parseInt(productStats.rows[0].total_products) || 0
      },
      domains: domainStats.rows.map(row => ({
        domain: row.domain,
        product_count: parseInt(row.product_count) || 0,
        unique_users_tracking: parseInt(row.unique_users_tracking) || 0,
        avg_price: parseFloat(row.avg_price) || 0,
        min_price: parseFloat(row.min_price) || 0,
        max_price: parseFloat(row.max_price) || 0
      })),
      products: {
        total: parseInt(productStats.rows[0].total_products) || 0,
        with_price: parseInt(productStats.rows[0].products_with_price) || 0,
        with_image: parseInt(productStats.rows[0].products_with_image) || 0,
        with_title: parseInt(productStats.rows[0].products_with_title) || 0,
        avg_price: parseFloat(productStats.rows[0].avg_product_price) || 0,
        recently_checked: parseInt(productStats.rows[0].recently_checked) || 0
      },
      scraping: {
        total_jobs: parseInt(scrapingStats.rows[0].total_scrape_jobs) || 0,
        completed: parseInt(scrapingStats.rows[0].completed_jobs) || 0,
        failed: parseInt(scrapingStats.rows[0].failed_jobs) || 0,
        pending: parseInt(scrapingStats.rows[0].pending_jobs) || 0,
        jobs_24h: parseInt(scrapingStats.rows[0].jobs_last_24h) || 0,
        success_rate: parseFloat(scrapingStats.rows[0].success_rate) || 0
      },
      activity: {
        new_items_24h: parseInt(activityStats.rows[0].new_items_24h) || 0,
        new_items_7d: parseInt(activityStats.rows[0].new_items_7d) || 0,
        new_items_30d: parseInt(activityStats.rows[0].new_items_30d) || 0,
        items_with_notifications: parseInt(activityStats.rows[0].items_with_notifications) || 0
      },
      price_history: {
        total_entries: parseInt(priceHistoryStats.rows[0].total_price_entries) || 0,
        products_with_history: parseInt(priceHistoryStats.rows[0].products_with_history) || 0,
        price_checks_24h: parseInt(priceHistoryStats.rows[0].price_checks_24h) || 0
      },
      generated_at: new Date().toISOString()
    };

    res.json({
      success: true,
      data: analytics
    });

  } catch (error) {
    logger.error('Admin dashboard error:', error);
    next(error);
  }
});

// Admin dashboard HTML page
router.get('/dashboard/view', (req, res) => {
  const html = `
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>ShopperPlus Admin Dashboard</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { 
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: white;
            border-radius: 20px;
            padding: 30px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.1);
        }
        .header {
            text-align: center;
            margin-bottom: 40px;
            padding-bottom: 20px;
            border-bottom: 2px solid #f0f0f0;
        }
        .header h1 {
            color: #333;
            font-size: 2.5em;
            margin-bottom: 10px;
        }
        .header p {
            color: #666;
            font-size: 1.1em;
        }
        .grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 25px;
            margin-bottom: 30px;
        }
        .card {
            background: linear-gradient(135deg, #f8f9ff 0%, #ffffff 100%);
            border-radius: 15px;
            padding: 25px;
            border: 1px solid #e0e7ff;
            transition: transform 0.2s ease, box-shadow 0.2s ease;
        }
        .card:hover {
            transform: translateY(-5px);
            box-shadow: 0 15px 35px rgba(0,0,0,0.1);
        }
        .card h3 {
            color: #4f46e5;
            font-size: 1.3em;
            margin-bottom: 20px;
            display: flex;
            align-items: center;
        }
        .card h3::before {
            content: "📊";
            margin-right: 10px;
            font-size: 1.2em;
        }
        .stat {
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 12px 0;
            border-bottom: 1px solid #f0f0f0;
        }
        .stat:last-child { border-bottom: none; }
        .stat-label {
            color: #666;
            font-weight: 500;
        }
        .stat-value {
            color: #333;
            font-weight: 700;
            font-size: 1.1em;
        }
        .domain-card {
            background: linear-gradient(135deg, #fff7ed 0%, #ffffff 100%);
            border: 1px solid #fed7aa;
        }
        .domain-card h3::before { content: "🛍️"; }
        .domain-item {
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 15px;
            margin: 10px 0;
            background: white;
            border-radius: 10px;
            border-left: 4px solid #f97316;
        }
        .domain-name {
            font-weight: 600;
            color: #333;
        }
        .domain-stats {
            text-align: right;
            font-size: 0.9em;
            color: #666;
        }
        .refresh-btn {
            background: linear-gradient(135deg, #4f46e5 0%, #7c3aed 100%);
            color: white;
            border: none;
            padding: 12px 24px;
            border-radius: 10px;
            font-size: 1em;
            font-weight: 600;
            cursor: pointer;
            transition: all 0.2s ease;
            margin: 20px auto;
            display: block;
        }
        .refresh-btn:hover {
            transform: translateY(-2px);
            box-shadow: 0 10px 25px rgba(79, 70, 229, 0.3);
        }
        .loading { opacity: 0.6; pointer-events: none; }
        .timestamp {
            text-align: center;
            color: #888;
            font-style: italic;
            margin-top: 20px;
        }
        @media (max-width: 768px) {
            .grid { grid-template-columns: 1fr; }
            .container { padding: 20px; }
            .header h1 { font-size: 2em; }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>ShopperPlus Admin Dashboard</h1>
            <p>Real-time analytics and insights</p>
        </div>
        
        <button onclick="loadDashboard()" class="refresh-btn">🔄 Refresh Data</button>
        
        <div id="dashboard-content">
            <div class="grid">
                <div class="card">
                    <h3>Loading...</h3>
                    <p>Please wait while we fetch the latest analytics...</p>
                </div>
            </div>
        </div>
        
        <div class="timestamp" id="timestamp"></div>
    </div>

    <script>
        async function loadDashboard() {
            const content = document.getElementById('dashboard-content');
            const timestamp = document.getElementById('timestamp');
            
            content.innerHTML = '<div class="card"><h3>Loading...</h3><p>Fetching latest analytics...</p></div>';
            content.classList.add('loading');
            
            try {
                const response = await fetch('/api/admin/dashboard');
                const result = await response.json();
                
                if (result.success) {
                    renderDashboard(result.data);
                    timestamp.textContent = \`Last updated: \${new Date(result.data.generated_at).toLocaleString()}\`;
                } else {
                    content.innerHTML = '<div class="card"><h3>Error</h3><p>Failed to load dashboard data.</p></div>';
                }
            } catch (error) {
                content.innerHTML = '<div class="card"><h3>Error</h3><p>Network error loading dashboard data.</p></div>';
            }
            
            content.classList.remove('loading');
        }
        
        function renderDashboard(data) {
            const content = document.getElementById('dashboard-content');
            
            content.innerHTML = \`
                <div class="grid">
                    <div class="card">
                        <h3>User Overview</h3>
                        <div class="stat">
                            <span class="stat-label">Total Users</span>
                            <span class="stat-value">\${data.overview.total_users.toLocaleString()}</span>
                        </div>
                        <div class="stat">
                            <span class="stat-label">Total Tracked Items</span>
                            <span class="stat-value">\${data.overview.total_watchlist_items.toLocaleString()}</span>
                        </div>
                        <div class="stat">
                            <span class="stat-label">Avg Items per User</span>
                            <span class="stat-value">\${data.overview.avg_items_per_user}</span>
                        </div>
                        <div class="stat">
                            <span class="stat-label">Max Items per User</span>
                            <span class="stat-value">\${data.overview.max_items_per_user}</span>
                        </div>
                    </div>
                    
                    <div class="card">
                        <h3>Product Statistics</h3>
                        <div class="stat">
                            <span class="stat-label">Total Products</span>
                            <span class="stat-value">\${data.products.total.toLocaleString()}</span>
                        </div>
                        <div class="stat">
                            <span class="stat-label">With Price Data</span>
                            <span class="stat-value">\${data.products.with_price.toLocaleString()}</span>
                        </div>
                        <div class="stat">
                            <span class="stat-label">With Images</span>
                            <span class="stat-value">\${data.products.with_image.toLocaleString()}</span>
                        </div>
                        <div class="stat">
                            <span class="stat-label">Recently Checked</span>
                            <span class="stat-value">\${data.products.recently_checked.toLocaleString()}</span>
                        </div>
                    </div>
                    
                    <div class="card">
                        <h3>Scraping Performance</h3>
                        <div class="stat">
                            <span class="stat-label">Success Rate</span>
                            <span class="stat-value">\${data.scraping.success_rate}%</span>
                        </div>
                        <div class="stat">
                            <span class="stat-label">Jobs (24h)</span>
                            <span class="stat-value">\${data.scraping.jobs_24h.toLocaleString()}</span>
                        </div>
                        <div class="stat">
                            <span class="stat-label">Pending Jobs</span>
                            <span class="stat-value">\${data.scraping.pending.toLocaleString()}</span>
                        </div>
                        <div class="stat">
                            <span class="stat-label">Failed Jobs</span>
                            <span class="stat-value">\${data.scraping.failed.toLocaleString()}</span>
                        </div>
                    </div>
                    
                    <div class="card">
                        <h3>Recent Activity</h3>
                        <div class="stat">
                            <span class="stat-label">New Items (24h)</span>
                            <span class="stat-value">\${data.activity.new_items_24h.toLocaleString()}</span>
                        </div>
                        <div class="stat">
                            <span class="stat-label">New Items (7d)</span>
                            <span class="stat-value">\${data.activity.new_items_7d.toLocaleString()}</span>
                        </div>
                        <div class="stat">
                            <span class="stat-label">New Items (30d)</span>
                            <span class="stat-value">\${data.activity.new_items_30d.toLocaleString()}</span>
                        </div>
                        <div class="stat">
                            <span class="stat-label">With Notifications</span>
                            <span class="stat-value">\${data.activity.items_with_notifications.toLocaleString()}</span>
                        </div>
                    </div>
                </div>
                
                <div class="card domain-card">
                    <h3>Domain Distribution</h3>
                    \${data.domains.map(domain => \`
                        <div class="domain-item">
                            <div>
                                <div class="domain-name">\${domain.domain}</div>
                                <div class="domain-stats">\${domain.unique_users_tracking} users tracking</div>
                            </div>
                            <div>
                                <div class="stat-value">\${domain.product_count.toLocaleString()}</div>
                                <div class="domain-stats">products</div>
                            </div>
                        </div>
                    \`).join('')}
                </div>
            \`;
        }
        
        // Load dashboard on page load
        loadDashboard();
        
        // Auto-refresh every 5 minutes
        setInterval(loadDashboard, 5 * 60 * 1000);
    </script>
</body>
</html>
  `;
  
  res.send(html);
});

module.exports = router;
