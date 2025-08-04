const axios = require('axios');
const cheerio = require('cheerio');

async function testScraper(url) {
  console.log(`Testing scraper with URL: ${url}`);
  
  try {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 30000); // 30 second timeout
    
    const userAgent = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
    
    console.log('Making HTTP request...');
    const response = await axios.get(url, {
      timeout: 15000,
      maxRedirects: 5,
      validateStatus: (status) => status < 400,
      signal: controller.signal,
      headers: {
        'User-Agent': userAgent,
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.5'
      }
    });
    
    clearTimeout(timeoutId);
    console.log(`HTTP request successful. Status: ${response.status}`);
    console.log(`Response size: ${response.data.length} characters`);
    
    const $ = cheerio.load(response.data);
    const title = $('title').text().trim();
    console.log(`Page title: ${title}`);
    
    return {
      success: true,
      title: title,
      statusCode: response.status,
      dataSize: response.data.length
    };
    
  } catch (error) {
    console.error(`Error occurred: ${error.message}`);
    if (error.code === 'ABORT_ERR') {
      console.error('Request timed out after 30 seconds');
    }
    return {
      success: false,
      error: error.message,
      code: error.code
    };
  }
}

// Test with different URLs
async function runTests() {
  console.log('=== Testing example.com ===');
  let result = await testScraper('https://example.com');
  console.log('Test result:', JSON.stringify(result, null, 2));
}

runTests().catch(error => {
  console.error('Tests failed:', error);
});
