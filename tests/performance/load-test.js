import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate } from 'k6/metrics';

// Custom metrics
export let errorRate = new Rate('errors');

// Test configuration
export let options = {
  // Load test scenarios
  scenarios: {
    // Baseline load test
    baseline_load: {
      executor: 'constant-vus',
      vus: 10,
      duration: '5m',
      tags: { test_type: 'baseline' },
    },
    
    // Spike test
    spike_test: {
      executor: 'ramping-vus',
      startVUs: 10,
      stages: [
        { duration: '1m', target: 50 },
        { duration: '2m', target: 100 },
        { duration: '1m', target: 200 }, // Spike
        { duration: '2m', target: 100 },
        { duration: '1m', target: 10 },
      ],
      tags: { test_type: 'spike' },
    },
    
    // Stress test
    stress_test: {
      executor: 'ramping-vus',
      startVUs: 10,
      stages: [
        { duration: '2m', target: 50 },
        { duration: '5m', target: 100 },
        { duration: '5m', target: 200 },
        { duration: '5m', target: 300 },
        { duration: '2m', target: 0 },
      ],
      tags: { test_type: 'stress' },
    },
  },
  
  // Thresholds
  thresholds: {
    http_req_duration: ['p(95)<2000'], // 95% of requests must complete below 2s
    http_req_failed: ['rate<0.01'],    // Error rate must be below 1%
    errors: ['rate<0.05'],             // Custom error rate below 5%
  },
};

// Configuration
const BASE_URL = __ENV.BASE_URL || 'http://localhost:8080';
const THINK_TIME = 1; // seconds between requests

// Test data
const products = [
  'OLJCESPC7Z', // Product IDs from the demo app
  '66VCHSJNUP',
  '1YMWWN1N4O',
  'L9ECAV7KIM',
  '2ZYFJ3GM2N',
];

const users = [
  'user1@example.com',
  'user2@example.com', 
  'user3@example.com',
  'user4@example.com',
  'user5@example.com',
];

// Helper functions
function getRandomProduct() {
  return products[Math.floor(Math.random() * products.length)];
}

function getRandomUser() {
  return users[Math.floor(Math.random() * users.length)];
}

function generateSessionId() {
  return 'session-' + Math.random().toString(36).substr(2, 9);
}

// Main test function
export default function () {
  const sessionId = generateSessionId();
  const userId = getRandomUser();
  
  // Set session cookie
  const jar = http.cookieJar();
  jar.set(BASE_URL, 'session-id', sessionId);
  
  // Test scenario: Complete user journey
  userJourney(sessionId, userId);
  
  sleep(THINK_TIME);
}

function userJourney(sessionId, userId) {
  // 1. Load homepage
  let response = http.get(`${BASE_URL}/`, {
    headers: {
      'User-Agent': 'K6 Load Test',
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    },
    tags: { endpoint: 'homepage' },
  });
  
  check(response, {
    'Homepage loaded successfully': (r) => r.status === 200,
    'Homepage contains products': (r) => r.body.includes('product') || r.body.includes('shop'),
  }) || errorRate.add(1);
  
  sleep(1);
  
  // 2. Browse products
  response = http.get(`${BASE_URL}/products`, {
    tags: { endpoint: 'products' },
  });
  
  check(response, {
    'Products page loaded': (r) => r.status === 200,
    'Products data present': (r) => r.body.length > 0,
  }) || errorRate.add(1);
  
  sleep(1);
  
  // 3. View specific product
  const productId = getRandomProduct();
  response = http.get(`${BASE_URL}/product/${productId}`, {
    tags: { endpoint: 'product_detail' },
  });
  
  check(response, {
    'Product detail loaded': (r) => r.status === 200,
  }) || errorRate.add(1);
  
  sleep(2);
  
  // 4. Add to cart
  response = http.post(`${BASE_URL}/cart`, {
    product_id: productId,
    quantity: Math.floor(Math.random() * 3) + 1,
  }, {
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    tags: { endpoint: 'add_to_cart' },
  });
  
  check(response, {
    'Add to cart successful': (r) => r.status === 200 || r.status === 302,
  }) || errorRate.add(1);
  
  sleep(1);
  
  // 5. View cart
  response = http.get(`${BASE_URL}/cart`, {
    tags: { endpoint: 'view_cart' },
  });
  
  check(response, {
    'Cart page loaded': (r) => r.status === 200,
  }) || errorRate.add(1);
  
  sleep(1);
  
  // 6. Simulate checkout process (don't complete to avoid creating orders)
  response = http.get(`${BASE_URL}/checkout`, {
    tags: { endpoint: 'checkout' },
  });
  
  check(response, {
    'Checkout page accessible': (r) => r.status === 200,
  }) || errorRate.add(1);
  
  sleep(2);
  
  // 7. Test API endpoints
  testApiEndpoints();
}

function testApiEndpoints() {
  // Test health endpoint
  let response = http.get(`${BASE_URL}/health`, {
    tags: { endpoint: 'health_api' },
  });
  
  check(response, {
    'Health endpoint responds': (r) => r.status === 200,
  }) || errorRate.add(1);
  
  // Test products API
  response = http.get(`${BASE_URL}/api/products`, {
    tags: { endpoint: 'products_api' },
  });
  
  check(response, {
    'Products API responds': (r) => r.status === 200,
  }) || errorRate.add(1);
  
  // Test cart API
  response = http.get(`${BASE_URL}/api/cart`, {
    tags: { endpoint: 'cart_api' },
  });
  
  check(response, {
    'Cart API responds': (r) => r.status === 200 || r.status === 404, // 404 is acceptable for empty cart
  }) || errorRate.add(1);
}

// Setup function - runs once before the test
export function setup() {
  console.log('🚀 Starting performance test...');
  console.log(`Target URL: ${BASE_URL}`);
  console.log(`Test scenarios: ${Object.keys(options.scenarios).join(', ')}`);
  
  // Verify target is accessible
  let response = http.get(BASE_URL);
  if (response.status !== 200) {
    throw new Error(`Target ${BASE_URL} is not accessible. Status: ${response.status}`);
  }
  
  console.log('✅ Target verification successful');
  return { timestamp: new Date().toISOString() };
}

// Teardown function - runs once after the test
export function teardown(data) {
  console.log(`📊 Performance test completed at ${data.timestamp}`);
  console.log('Check the results for performance metrics and thresholds');
}

// Handle test summary
export function handleSummary(data) {
  return {
    'performance-results.json': JSON.stringify(data, null, 2),
    'performance-summary.html': generateHtmlReport(data),
  };
}

function generateHtmlReport(data) {
  const timestamp = new Date().toISOString();
  
  return `
<!DOCTYPE html>
<html>
<head>
    <title>Performance Test Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #f0f0f0; padding: 15px; border-radius: 5px; }
        .metric { margin: 10px 0; padding: 10px; border-left: 4px solid #007acc; background-color: #f9f9f9; }
        .passed { border-left-color: #28a745; }
        .failed { border-left-color: #dc3545; }
        .warning { border-left-color: #ffc107; }
        .chart { margin: 20px 0; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
    </style>
</head>
<body>
    <div class="header">
        <h1>⚡ Performance Test Report</h1>
        <p><strong>Test Date:</strong> ${timestamp}</p>
        <p><strong>Target:</strong> ${BASE_URL}</p>
        <p><strong>Duration:</strong> ${Math.round(data.state.testRunDurationMs / 1000)}s</p>
    </div>
    
    <h2>📊 Key Metrics</h2>
    <div class="metric ${data.metrics.http_req_duration.values.p95 < 2000 ? 'passed' : 'failed'}">
        <strong>Response Time (95th percentile):</strong> ${Math.round(data.metrics.http_req_duration.values.p95)}ms
        <br><em>Threshold: < 2000ms</em>
    </div>
    
    <div class="metric ${data.metrics.http_req_failed.values.rate < 0.01 ? 'passed' : 'failed'}">
        <strong>Error Rate:</strong> ${(data.metrics.http_req_failed.values.rate * 100).toFixed(2)}%
        <br><em>Threshold: < 1%</em>
    </div>
    
    <div class="metric">
        <strong>Total Requests:</strong> ${data.metrics.http_reqs.values.count}
    </div>
    
    <div class="metric">
        <strong>Requests/sec:</strong> ${data.metrics.http_reqs.values.rate.toFixed(2)}
    </div>
    
    <h2>📈 Detailed Metrics</h2>
    <table>
        <tr>
            <th>Metric</th>
            <th>Average</th>
            <th>Min</th>
            <th>Max</th>
            <th>90th Percentile</th>
            <th>95th Percentile</th>
        </tr>
        <tr>
            <td>HTTP Request Duration</td>
            <td>${Math.round(data.metrics.http_req_duration.values.avg)}ms</td>
            <td>${Math.round(data.metrics.http_req_duration.values.min)}ms</td>
            <td>${Math.round(data.metrics.http_req_duration.values.max)}ms</td>
            <td>${Math.round(data.metrics.http_req_duration.values.p90)}ms</td>
            <td>${Math.round(data.metrics.http_req_duration.values.p95)}ms</td>
        </tr>
        <tr>
            <td>HTTP Request Waiting</td>
            <td>${Math.round(data.metrics.http_req_waiting.values.avg)}ms</td>
            <td>${Math.round(data.metrics.http_req_waiting.values.min)}ms</td>
            <td>${Math.round(data.metrics.http_req_waiting.values.max)}ms</td>
            <td>${Math.round(data.metrics.http_req_waiting.values.p90)}ms</td>
            <td>${Math.round(data.metrics.http_req_waiting.values.p95)}ms</td>
        </tr>
    </table>
    
    <h2>🎯 Test Scenarios</h2>
    <ul>
        <li><strong>Baseline Load:</strong> 10 concurrent users for 5 minutes</li>
        <li><strong>Spike Test:</strong> Gradual increase to 200 users with spike simulation</li>
        <li><strong>Stress Test:</strong> Progressive load increase to 300 concurrent users</li>
    </ul>
    
    <h2>🔍 Endpoint Performance</h2>
    <p>Individual endpoint performance can be analyzed using the tags in the raw results.</p>
    
    <h2>💡 Recommendations</h2>
    <ul>
        <li>Monitor response times during peak hours</li>
        <li>Consider horizontal scaling if 95th percentile exceeds 2000ms</li>
        <li>Implement caching for frequently accessed endpoints</li>
        <li>Set up alerts for error rates above 1%</li>
    </ul>
</body>
</html>`;
}
