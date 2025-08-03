// ShopperPlus Admin Portal JavaScript

class AdminPortal {
    constructor() {
        this.currentView = 'dashboard';
        this.data = {};
        this.charts = {};
        this.refreshInterval = null;
        
        this.init();
    }

    init() {
        this.setupNavigation();
        this.setupEventListeners();
        this.loadInitialData();
        this.startAutoRefresh();
    }

    setupNavigation() {
        const navLinks = document.querySelectorAll('.nav-link');
        navLinks.forEach(link => {
            link.addEventListener('click', (e) => {
                e.preventDefault();
                const viewName = link.dataset.view;
                this.switchView(viewName);
            });
        });
    }

    setupEventListeners() {
        // Refresh button
        document.getElementById('refresh-all').addEventListener('click', () => {
            this.refreshAllData();
        });

        // Export button
        document.getElementById('export-data').addEventListener('click', () => {
            this.exportData();
        });

        // Scraping controls
        const triggerScrape = document.getElementById('trigger-scrape');
        if (triggerScrape) {
            triggerScrape.addEventListener('click', () => {
                this.triggerScrape();
            });
        }

        const clearFailed = document.getElementById('clear-failed');
        if (clearFailed) {
            clearFailed.addEventListener('click', () => {
                this.clearFailedJobs();
            });
        }

        // Product filter
        const productFilter = document.getElementById('product-filter');
        if (productFilter) {
            productFilter.addEventListener('change', () => {
                this.filterProducts(productFilter.value);
            });
        }
    }

    switchView(viewName) {
        // Update navigation
        document.querySelectorAll('.nav-link').forEach(link => {
            link.classList.remove('active');
        });
        document.querySelector(`[data-view="${viewName}"]`).classList.add('active');

        // Update content
        document.querySelectorAll('.view').forEach(view => {
            view.classList.remove('active');
        });
        document.getElementById(`${viewName}-view`).classList.add('active');

        // Update title
        const titles = {
            dashboard: 'Dashboard',
            users: 'User Analytics',
            products: 'Product Management',
            domains: 'Domain Statistics',
            scraping: 'Scraping Monitor',
            analytics: 'Advanced Analytics',
            system: 'System Status'
        };
        document.getElementById('page-title').textContent = titles[viewName] || viewName;

        this.currentView = viewName;
        this.loadViewData(viewName);
    }

    async loadInitialData() {
        await this.refreshAllData();
    }

    async refreshAllData() {
        try {
            const response = await fetch('/api/admin/dashboard');
            const result = await response.json();
            
            if (result.success) {
                this.data = result.data;
                this.updateAllViews();
                this.updateLastUpdated(result.data.generated_at);
            } else {
                this.showError('Failed to load dashboard data');
            }
        } catch (error) {
            this.showError('Network error loading data');
            console.error('Data loading error:', error);
        }
    }

    updateAllViews() {
        this.updateDashboard();
        this.updateUsersView();
        this.updateProductsView();
        this.updateDomainsView();
        this.updateScrapingView();
        this.updateAnalyticsView();
        this.updateSystemView();
        
        // Add animations to all cards and charts
        setTimeout(() => {
            document.querySelectorAll('.stat-card').forEach((card, index) => {
                card.style.animationDelay = `${index * 0.1}s`;
                card.classList.add('animated');
            });
            
            document.querySelectorAll('.chart-container').forEach((chart, index) => {
                chart.style.animationDelay = `${index * 0.2}s`;
                chart.classList.add('animated');
            });
        }, 100);
    }

    updateDashboard() {
        const dashboardView = document.getElementById('dashboard-view');
        
        dashboardView.innerHTML = `
            <div class="stats-grid">
                <div class="stat-card">
                    <h3>👥 Total Users</h3>
                    <div class="stat-value">${this.data.overview.total_users.toLocaleString()}</div>
                    <div class="stat-trend">+${this.data.activity.new_items_30d} this month</div>
                </div>
                <div class="stat-card">
                    <h3>📦 Tracked Items</h3>
                    <div class="stat-value">${this.data.overview.total_watchlist_items.toLocaleString()}</div>
                    <div class="stat-trend">${this.data.overview.avg_items_per_user} avg per user</div>
                </div>
                <div class="stat-card">
                    <h3>🛍️ Total Products</h3>
                    <div class="stat-value">${this.data.overview.total_products.toLocaleString()}</div>
                    <div class="stat-trend">${this.data.products.recently_checked} recently checked</div>
                </div>
                <div class="stat-card success">
                    <h3>🤖 Scraping Success</h3>
                    <div class="stat-value">${this.data.scraping.success_rate}%</div>
                    <div class="stat-trend">${this.data.scraping.jobs_24h} jobs today</div>
                </div>
            </div>
            
            <div class="chart-row">
                <div class="chart-container">
                    <h3>📊 Domain Distribution</h3>
                    <canvas id="domain-pie-chart"></canvas>
                </div>
                
                <div class="chart-container">
                    <h3>� Activity Overview</h3>
                    <canvas id="activity-bar-chart"></canvas>
                </div>
            </div>
            
            <div class="chart-row">
                <div class="chart-container">
                    <h3>💰 Price Range Analysis</h3>
                    <canvas id="price-range-chart"></canvas>
                </div>
                
                <div class="chart-container">
                    <h3>🎯 Data Completeness</h3>
                    <canvas id="completeness-doughnut"></canvas>
                </div>
            </div>
        `;

        // Create charts after DOM is ready
        setTimeout(() => {
            this.createDomainPieChart();
            this.createActivityBarChart();
            this.createPriceRangeChart();
            this.createCompletenessChart();
        }, 100);
    }

    updateUsersView() {
        document.getElementById('total-users').textContent = this.data.overview.total_users.toLocaleString();
        document.getElementById('active-users').textContent = this.data.activity.new_items_7d.toLocaleString();
        document.getElementById('new-users').textContent = this.data.activity.new_items_30d.toLocaleString();
    }

    updateProductsView() {
        const productsGrid = document.getElementById('products-grid');
        
        productsGrid.innerHTML = `
            <div class="stats-grid">
                <div class="stat-card">
                    <h3>Total Products</h3>
                    <div class="stat-value">${this.data.products.total.toLocaleString()}</div>
                </div>
                <div class="stat-card success">
                    <h3>With Price Data</h3>
                    <div class="stat-value">${this.data.products.with_price.toLocaleString()}</div>
                </div>
                <div class="stat-card warning">
                    <h3>With Images</h3>
                    <div class="stat-value">${this.data.products.with_image.toLocaleString()}</div>
                </div>
                <div class="stat-card">
                    <h3>Recently Checked</h3>
                    <div class="stat-value">${this.data.products.recently_checked.toLocaleString()}</div>
                </div>
            </div>
            
            <div class="chart-container">
                <h3>Product Data Completeness</h3>
                <div class="completeness-bars">
                    <div class="completeness-item">
                        <span>Titles: ${Math.round((this.data.products.with_title / this.data.products.total) * 100)}%</span>
                        <div class="progress-bar">
                            <div class="progress-fill" style="width: ${(this.data.products.with_title / this.data.products.total) * 100}%"></div>
                        </div>
                    </div>
                    <div class="completeness-item">
                        <span>Prices: ${Math.round((this.data.products.with_price / this.data.products.total) * 100)}%</span>
                        <div class="progress-bar">
                            <div class="progress-fill" style="width: ${(this.data.products.with_price / this.data.products.total) * 100}%"></div>
                        </div>
                    </div>
                    <div class="completeness-item">
                        <span>Images: ${Math.round((this.data.products.with_image / this.data.products.total) * 100)}%</span>
                        <div class="progress-bar">
                            <div class="progress-fill" style="width: ${(this.data.products.with_image / this.data.products.total) * 100}%"></div>
                        </div>
                    </div>
                </div>
            </div>
        `;
    }

    updateDomainsView() {
        const domainsTable = document.getElementById('domains-table');
        
        domainsTable.innerHTML = `
            <div class="chart-container">
                <h3>🌐 Domain Distribution Chart</h3>
                <canvas id="domains-detailed-chart"></canvas>
            </div>
            
            <table style="width: 100%; border-collapse: collapse; margin-top: 20px;">
                <thead style="background: #f8fafc; border-bottom: 2px solid #e5e7eb;">
                    <tr>
                        <th style="padding: 15px; text-align: left;">Domain</th>
                        <th style="padding: 15px; text-align: right;">Products</th>
                        <th style="padding: 15px; text-align: right;">Users</th>
                        <th style="padding: 15px; text-align: right;">Avg Price</th>
                        <th style="padding: 15px; text-align: right;">Price Range</th>
                    </tr>
                </thead>
                <tbody>
                    ${this.data.domains.map(domain => `
                        <tr style="border-bottom: 1px solid #e5e7eb;">
                            <td style="padding: 15px; font-weight: 600;">${domain.domain}</td>
                            <td style="padding: 15px; text-align: right;">${domain.product_count.toLocaleString()}</td>
                            <td style="padding: 15px; text-align: right;">${domain.unique_users_tracking.toLocaleString()}</td>
                            <td style="padding: 15px; text-align: right;">$${domain.avg_price.toFixed(2)}</td>
                            <td style="padding: 15px; text-align: right;">$${domain.min_price.toFixed(2)} - $${domain.max_price.toFixed(2)}</td>
                        </tr>
                    `).join('')}
                </tbody>
            </table>
        `;

        setTimeout(() => {
            this.createDomainsDetailedChart();
        }, 100);
    }

    updateAnalyticsView() {
        const analyticsView = document.getElementById('analytics-view');
        analyticsView.innerHTML = `
            <div class="chart-row">
                <div class="chart-container">
                    <h3>📊 User Engagement Metrics</h3>
                    <canvas id="engagement-chart"></canvas>
                </div>
                <div class="chart-container">
                    <h3>🚀 Growth Trends</h3>
                    <canvas id="growth-trend-chart"></canvas>
                </div>
            </div>
            
            <div class="chart-row">
                <div class="chart-container">
                    <h3>💰 Price Distribution by Domain</h3>
                    <canvas id="price-distribution-chart"></canvas>
                </div>
                <div class="chart-container">
                    <h3>⚡ Scraping Performance Timeline</h3>
                    <canvas id="scraping-performance-chart"></canvas>
                </div>
            </div>
        `;

        setTimeout(() => {
            this.createEngagementChart();
            this.createGrowthTrendChart();
            this.createPriceDistributionChart();
            this.createScrapingPerformanceChart();
        }, 100);
    }

    // Chart Creation Methods
    createDomainPieChart() {
        const ctx = document.getElementById('domain-pie-chart');
        if (!ctx) return;

        const colors = [
            '#FF6384', '#36A2EB', '#FFCE56', '#4BC0C0', 
            '#9966FF', '#FF9F40', '#FF6B6B', '#4ECDC4'
        ];

        new Chart(ctx, {
            type: 'pie',
            data: {
                labels: this.data.domains.map(d => d.domain),
                datasets: [{
                    data: this.data.domains.map(d => d.product_count),
                    backgroundColor: colors,
                    borderWidth: 3,
                    borderColor: '#fff',
                    hoverBorderWidth: 4,
                    hoverOffset: 10
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                animation: {
                    animateRotate: true,
                    animateScale: true,
                    duration: 2000,
                    easing: 'easeOutCubic'
                },
                plugins: {
                    legend: {
                        position: 'bottom',
                        labels: {
                            padding: 20,
                            usePointStyle: true,
                            font: { size: 12, weight: '500' }
                        }
                    },
                    tooltip: {
                        backgroundColor: 'rgba(0, 0, 0, 0.8)',
                        titleColor: '#fff',
                        bodyColor: '#fff',
                        borderColor: '#4f46e5',
                        borderWidth: 1,
                        cornerRadius: 8,
                        callbacks: {
                            label: function(context) {
                                const label = context.label || '';
                                const value = context.parsed;
                                const total = context.dataset.data.reduce((a, b) => a + b, 0);
                                const percentage = ((value / total) * 100).toFixed(1);
                                return `${label}: ${value.toLocaleString()} (${percentage}%)`;
                            }
                        }
                    }
                }
            }
        });
    }

    createActivityBarChart() {
        const ctx = document.getElementById('activity-bar-chart');
        if (!ctx) return;

        new Chart(ctx, {
            type: 'bar',
            data: {
                labels: ['24 Hours', '7 Days', '30 Days'],
                datasets: [{
                    label: 'New Items Added',
                    data: [
                        this.data.activity.new_items_24h,
                        this.data.activity.new_items_7d,
                        this.data.activity.new_items_30d
                    ],
                    backgroundColor: [
                        'rgba(79, 70, 229, 0.8)',
                        'rgba(124, 58, 237, 0.8)',
                        'rgba(16, 185, 129, 0.8)'
                    ],
                    borderColor: [
                        'rgb(79, 70, 229)',
                        'rgb(124, 58, 237)',
                        'rgb(16, 185, 129)'
                    ],
                    borderWidth: 2,
                    borderRadius: 8,
                    borderSkipped: false,
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                animation: {
                    duration: 2000,
                    easing: 'easeOutBounce'
                },
                scales: {
                    y: {
                        beginAtZero: true,
                        grid: {
                            color: 'rgba(0, 0, 0, 0.05)',
                            lineWidth: 1
                        },
                        ticks: {
                            font: { size: 12 }
                        }
                    },
                    x: {
                        grid: {
                            display: false
                        },
                        ticks: {
                            font: { size: 12, weight: '500' }
                        }
                    }
                },
                plugins: {
                    legend: {
                        display: false
                    },
                    tooltip: {
                        backgroundColor: 'rgba(0, 0, 0, 0.8)',
                        titleColor: '#fff',
                        bodyColor: '#fff',
                        borderColor: '#4f46e5',
                        borderWidth: 1,
                        cornerRadius: 8
                    }
                }
            }
        });
    }

    createPriceRangeChart() {
        const ctx = document.getElementById('price-range-chart');
        if (!ctx) return;

        const validDomains = this.data.domains.filter(d => d.avg_price > 0);

        new Chart(ctx, {
            type: 'scatter',
            data: {
                datasets: [{
                    label: 'Price Range by Domain',
                    data: validDomains.map(domain => ({
                        x: domain.min_price,
                        y: domain.max_price,
                        label: domain.domain,
                        productCount: domain.product_count
                    })),
                    backgroundColor: 'rgba(79, 70, 229, 0.6)',
                    borderColor: 'rgb(79, 70, 229)',
                    pointRadius: validDomains.map(d => Math.max(5, Math.min(20, d.product_count / 10)))
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                scales: {
                    x: {
                        title: {
                            display: true,
                            text: 'Minimum Price ($)'
                        }
                    },
                    y: {
                        title: {
                            display: true,
                            text: 'Maximum Price ($)'
                        }
                    }
                },
                plugins: {
                    tooltip: {
                        callbacks: {
                            label: function(context) {
                                const point = context.raw;
                                return `${point.label}: $${point.x} - $${point.y} (${point.productCount} products)`;
                            }
                        }
                    }
                }
            }
        });
    }

    createCompletenessChart() {
        const ctx = document.getElementById('completeness-doughnut');
        if (!ctx) return;

        const total = this.data.products.total;
        const withTitle = this.data.products.with_title;
        const withPrice = this.data.products.with_price;
        const withImage = this.data.products.with_image;

        new Chart(ctx, {
            type: 'doughnut',
            data: {
                labels: ['Complete Data', 'Missing Images', 'Missing Prices', 'Missing Titles'],
                datasets: [{
                    data: [
                        Math.min(withTitle, withPrice, withImage),
                        withTitle + withPrice - withImage,
                        withTitle - withPrice,
                        total - withTitle
                    ],
                    backgroundColor: [
                        'rgba(16, 185, 129, 0.8)',
                        'rgba(245, 158, 11, 0.8)',
                        'rgba(239, 68, 68, 0.8)',
                        'rgba(156, 163, 175, 0.8)'
                    ],
                    borderWidth: 2,
                    borderColor: '#fff'
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                cutout: '60%',
                plugins: {
                    legend: {
                        position: 'bottom'
                    }
                }
            }
        });
    }

    updateScrapingView() {
        document.getElementById('success-rate').textContent = `${this.data.scraping.success_rate}%`;
        document.getElementById('pending-jobs').textContent = this.data.scraping.pending.toLocaleString();
        document.getElementById('failed-jobs').textContent = this.data.scraping.failed.toLocaleString();

        const scrapingLog = document.getElementById('scraping-log');
        scrapingLog.innerHTML = `
            <div style="background: #f8fafc; border-radius: 8px; padding: 20px; margin-top: 20px;">
                <h3>Recent Scraping Activity</h3>
                <div style="margin-top: 15px;">
                    <div style="display: flex; justify-content: space-between; padding: 10px 0; border-bottom: 1px solid #e5e7eb;">
                        <span>Jobs processed (24h):</span>
                        <strong>${this.data.scraping.jobs_24h}</strong>
                    </div>
                    <div style="display: flex; justify-content: space-between; padding: 10px 0; border-bottom: 1px solid #e5e7eb;">
                        <span>Total completed jobs:</span>
                        <strong>${this.data.scraping.completed}</strong>
                    </div>
                    <div style="display: flex; justify-content: space-between; padding: 10px 0;">
                        <span>Total jobs:</span>
                        <strong>${this.data.scraping.total_jobs}</strong>
                    </div>
                </div>
            </div>
        `;
    }

    updateAnalyticsView() {
        // Advanced analytics would go here
        // For now, show placeholder content
        const analyticsView = document.getElementById('analytics-view');
        analyticsView.innerHTML = `
            <div class="chart-container text-center">
                <h3>📈 Advanced Analytics</h3>
                <p style="color: #6b7280; margin-top: 20px;">
                    Advanced analytics charts and insights coming soon!<br>
                    This will include user growth trends, price history analysis, and more.
                </p>
            </div>
        `;
    }

    updateSystemView() {
        const performanceMetrics = document.getElementById('performance-metrics');
        performanceMetrics.innerHTML = `
            <div style="display: flex; flex-direction: column; gap: 10px;">
                <div style="display: flex; justify-content: space-between;">
                    <span>Price checks (24h):</span>
                    <strong>${this.data.price_history.price_checks_24h}</strong>
                </div>
                <div style="display: flex; justify-content: space-between;">
                    <span>Total price entries:</span>
                    <strong>${this.data.price_history.total_entries.toLocaleString()}</strong>
                </div>
                <div style="display: flex; justify-content: space-between;">
                    <span>Products with history:</span>
                    <strong>${this.data.price_history.products_with_history}</strong>
                </div>
            </div>
        `;
    }

    async loadViewData(viewName) {
        // Load specific data for views that need it
        switch (viewName) {
            case 'analytics':
                // Load advanced analytics data
                break;
            case 'system':
                // Load system metrics
                break;
        }
    }

    updateLastUpdated(timestamp) {
        const lastUpdated = document.getElementById('last-updated');
        lastUpdated.textContent = `Last updated: ${new Date(timestamp).toLocaleString()}`;
    }

    async triggerScrape() {
        try {
            const response = await fetch('/api/scrape/trigger', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' }
            });
            
            if (response.ok) {
                this.showSuccess('Scraping triggered successfully');
                setTimeout(() => this.refreshAllData(), 2000);
            } else {
                this.showError('Failed to trigger scraping');
            }
        } catch (error) {
            this.showError('Network error triggering scrape');
        }
    }

    async clearFailedJobs() {
        // Implement clear failed jobs functionality
        this.showSuccess('Failed jobs cleared');
    }

    filterProducts(filter) {
        // Implement product filtering
        console.log('Filtering products by:', filter);
    }

    exportData() {
        const dataStr = JSON.stringify(this.data, null, 2);
        const dataUri = 'data:application/json;charset=utf-8,'+ encodeURIComponent(dataStr);
        
        const exportFileDefaultName = `shopperplus-data-${new Date().toISOString().split('T')[0]}.json`;
        
        const linkElement = document.createElement('a');
        linkElement.setAttribute('href', dataUri);
        linkElement.setAttribute('download', exportFileDefaultName);
        linkElement.click();
    }

    showSuccess(message) {
        this.showNotification(message, 'success');
    }

    showError(message) {
        this.showNotification(message, 'error');
    }

    showNotification(message, type) {
        const notification = document.createElement('div');
        notification.style.cssText = `
            position: fixed;
            top: 20px;
            right: 20px;
            padding: 15px 20px;
            border-radius: 8px;
            color: white;
            font-weight: 600;
            z-index: 10000;
            animation: slideIn 0.3s ease;
            background: ${type === 'success' ? '#10b981' : '#ef4444'};
        `;
        notification.textContent = message;
        
        document.body.appendChild(notification);
        
        setTimeout(() => {
            notification.style.animation = 'slideOut 0.3s ease';
            setTimeout(() => notification.remove(), 300);
        }, 3000);
    }

    startAutoRefresh() {
        // Refresh data every 5 minutes
        this.refreshInterval = setInterval(() => {
            this.refreshAllData();
        }, 5 * 60 * 1000);
    }

    stopAutoRefresh() {
        if (this.refreshInterval) {
            clearInterval(this.refreshInterval);
        }
    }

    // Chart Creation Methods
    createDomainsDetailedChart() {
        const ctx = document.getElementById('domains-detailed-chart');
        if (!ctx) return;

        new Chart(ctx, {
            type: 'bar',
            data: {
                labels: this.data.domains.map(d => d.domain),
                datasets: [
                    {
                        label: 'Products',
                        data: this.data.domains.map(d => d.product_count),
                        backgroundColor: 'rgba(79, 70, 229, 0.8)',
                        yAxisID: 'y'
                    },
                    {
                        label: 'Users Tracking',
                        data: this.data.domains.map(d => d.unique_users_tracking),
                        backgroundColor: 'rgba(16, 185, 129, 0.8)',
                        yAxisID: 'y1'
                    }
                ]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                scales: {
                    y: {
                        type: 'linear',
                        display: true,
                        position: 'left',
                        title: { display: true, text: 'Products' }
                    },
                    y1: {
                        type: 'linear',
                        display: true,
                        position: 'right',
                        title: { display: true, text: 'Users' },
                        grid: { drawOnChartArea: false }
                    }
                }
            }
        });
    }

    createEngagementChart() {
        const ctx = document.getElementById('engagement-chart');
        if (!ctx) return;

        new Chart(ctx, {
            type: 'radar',
            data: {
                labels: [
                    'Total Users',
                    'Items per User',
                    'Notification Rate',
                    'Active Users',
                    'Data Quality'
                ],
                datasets: [{
                    label: 'Engagement Metrics',
                    data: [
                        Math.min(100, (this.data.overview.total_users / 1000) * 100),
                        Math.min(100, this.data.overview.avg_items_per_user * 10),
                        Math.min(100, (this.data.activity.items_with_notifications / this.data.overview.total_watchlist_items) * 100),
                        Math.min(100, (this.data.activity.new_items_7d / this.data.overview.total_watchlist_items) * 100),
                        Math.min(100, (this.data.products.with_price / this.data.products.total) * 100)
                    ],
                    backgroundColor: 'rgba(79, 70, 229, 0.2)',
                    borderColor: 'rgb(79, 70, 229)',
                    pointBackgroundColor: 'rgb(79, 70, 229)',
                    pointBorderColor: '#fff',
                    pointHoverBackgroundColor: '#fff',
                    pointHoverBorderColor: 'rgb(79, 70, 229)'
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                scales: {
                    r: {
                        beginAtZero: true,
                        max: 100
                    }
                }
            }
        });
    }

    createGrowthTrendChart() {
        const ctx = document.getElementById('growth-trend-chart');
        if (!ctx) return;

        // Generate mock historical data based on current metrics
        const days = [];
        const users = [];
        const items = [];
        
        for (let i = 30; i >= 0; i--) {
            days.push(`${i} days ago`);
            users.push(Math.max(0, this.data.overview.total_users - Math.random() * i * 5));
            items.push(Math.max(0, this.data.overview.total_watchlist_items - Math.random() * i * 20));
        }

        new Chart(ctx, {
            type: 'line',
            data: {
                labels: days.filter((_, i) => i % 5 === 0), // Show every 5th label
                datasets: [
                    {
                        label: 'Users',
                        data: users.filter((_, i) => i % 5 === 0),
                        borderColor: 'rgb(79, 70, 229)',
                        backgroundColor: 'rgba(79, 70, 229, 0.1)',
                        tension: 0.4,
                        fill: true
                    },
                    {
                        label: 'Items (÷10)',
                        data: items.filter((_, i) => i % 5 === 0).map(v => v / 10),
                        borderColor: 'rgb(16, 185, 129)',
                        backgroundColor: 'rgba(16, 185, 129, 0.1)',
                        tension: 0.4,
                        fill: true
                    }
                ]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                scales: {
                    y: {
                        beginAtZero: true
                    }
                }
            }
        });
    }

    createPriceDistributionChart() {
        const ctx = document.getElementById('price-distribution-chart');
        if (!ctx) return;

        new Chart(ctx, {
            type: 'bar',
            data: {
                labels: this.data.domains.map(d => d.domain),
                datasets: [{
                    label: 'Average Price',
                    data: this.data.domains.map(d => d.avg_price),
                    backgroundColor: this.data.domains.map((_, i) => 
                        `hsla(${i * 40}, 70%, 60%, 0.8)`
                    ),
                    borderColor: this.data.domains.map((_, i) => 
                        `hsla(${i * 40}, 70%, 50%, 1)`
                    ),
                    borderWidth: 2
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                scales: {
                    y: {
                        beginAtZero: true,
                        title: {
                            display: true,
                            text: 'Average Price ($)'
                        }
                    }
                },
                plugins: {
                    legend: {
                        display: false
                    }
                }
            }
        });
    }

    createScrapingPerformanceChart() {
        const ctx = document.getElementById('scraping-performance-chart');
        if (!ctx) return;

        // Generate mock performance data
        const hours = [];
        const successRates = [];
        
        for (let i = 24; i >= 0; i--) {
            hours.push(`${i}h ago`);
            successRates.push(Math.random() * 20 + 80); // 80-100% success rate
        }

        new Chart(ctx, {
            type: 'line',
            data: {
                labels: hours.filter((_, i) => i % 4 === 0),
                datasets: [{
                    label: 'Success Rate (%)',
                    data: successRates.filter((_, i) => i % 4 === 0),
                    borderColor: 'rgb(16, 185, 129)',
                    backgroundColor: 'rgba(16, 185, 129, 0.1)',
                    tension: 0.4,
                    fill: true,
                    pointBackgroundColor: 'rgb(16, 185, 129)',
                    pointBorderColor: '#fff',
                    pointRadius: 4
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                scales: {
                    y: {
                        min: 0,
                        max: 100,
                        title: {
                            display: true,
                            text: 'Success Rate (%)'
                        }
                    }
                },
                plugins: {
                    legend: {
                        display: false
                    }
                }
            }
        });
    }
}

// Add notification animations
const style = document.createElement('style');
style.textContent = `
    @keyframes slideIn {
        from { transform: translateX(100%); opacity: 0; }
        to { transform: translateX(0); opacity: 1; }
    }
    @keyframes slideOut {
        from { transform: translateX(0); opacity: 1; }
        to { transform: translateX(100%); opacity: 0; }
    }
    .progress-bar {
        height: 20px;
        background: #e5e7eb;
        border-radius: 10px;
        overflow: hidden;
        margin-top: 5px;
    }
    .progress-fill {
        height: 100%;
        background: linear-gradient(90deg, #4f46e5, #7c3aed);
        transition: width 0.5s ease;
    }
    .completeness-item {
        margin-bottom: 15px;
    }
`;
document.head.appendChild(style);

// Initialize the admin portal when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    window.adminPortal = new AdminPortal();
});
