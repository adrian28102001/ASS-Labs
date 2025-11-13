import http from 'k6/http';
import { check, sleep } from 'k6';
import { Counter, Trend, Rate } from 'k6/metrics';

// Custom metrics
const orderCreationTime = new Trend('order_creation_duration');
const productFetchTime = new Trend('product_fetch_duration');
const errorRate = new Rate('errors');
const orderCounter = new Counter('orders_created');
const gatewayLatency = new Trend('gateway_latency');

export const options = {
  stages: [
    { duration: '30s', target: 20 },   // Ramp up to 20 users
    { duration: '1m', target: 50 },    // Stay at 50 users
    { duration: '30s', target: 100 },  // Spike to 100 users
    { duration: '1m', target: 100 },   // Sustain 100 users
    { duration: '30s', target: 0 },    // Ramp down
  ],
  thresholds: {
    'http_req_duration': ['p(95)<600', 'p(99)<1200'],  // Slightly higher due to network hops
    'http_req_failed': ['rate<0.05'],  // Error rate < 5%
    'order_creation_duration': ['p(95)<900'],
    'product_fetch_duration': ['p(95)<400'],
    'gateway_latency': ['p(95)<50'],  // Gateway overhead
  },
};

const BASE_URL = 'http://localhost:5000';  // API Gateway

export function setup() {
  console.log('Setting up microservices test - logging in...');

  // Login through API Gateway to Identity Service
  const loginRes = http.post(`${BASE_URL}/api/auth/login`, JSON.stringify({
    email: 'customer@example.com',
    password: 'Customer123!'
  }), {
    headers: { 'Content-Type': 'application/json' },
  });

  if (loginRes.status !== 200) {
    console.error('Failed to login:', loginRes.status, loginRes.body);
    throw new Error('Authentication failed');
  }

  const token = loginRes.json('token');
  console.log('Setup complete - token obtained from Identity service');

  return { token };
}

export default function (data) {
  const headers = {
    'Authorization': `Bearer ${data.token}`,
    'Content-Type': 'application/json',
  };

  // Test 1: Get all products from Catalog Service via Gateway
  const gatewayStart = Date.now();
  let res = http.get(`${BASE_URL}/api/products`, { headers });
  gatewayLatency.add(Date.now() - gatewayStart - res.timings.duration);

  const productFetchSuccess = check(res, {
    'products status 200': (r) => r.status === 200,
    'products response time < 600ms': (r) => r.timings.duration < 600,
    'products returned data': (r) => r.body.length > 0,
  });

  productFetchTime.add(res.timings.duration);
  errorRate.add(!productFetchSuccess);

  sleep(1);

  // Test 2: Get categories from Catalog Service
  res = http.get(`${BASE_URL}/api/categories`, { headers });
  const categorySuccess = check(res, {
    'categories status 200': (r) => r.status === 200,
    'categories has data': (r) => r.body.length > 0,
  });

  errorRate.add(!categorySuccess);
  sleep(1);

  // Test 3: Create order in Orders Service (inter-service communication test)
  const productsRes = http.get(`${BASE_URL}/api/products`, { headers });

  if (productsRes.status === 200) {
    let products;
    try {
      products = productsRes.json();
    } catch (e) {
      console.error('Failed to parse products JSON');
      errorRate.add(true);
      return;
    }

    if (products && products.length > 0) {
      // In microservices, Orders service needs to validate products
      // This tests cross-service communication
      const orderPayload = JSON.stringify({
        items: [
          {
            productId: products[0].id,
            quantity: Math.floor(Math.random() * 3) + 1  // 1-3 items
          }
        ]
      });

      const orderStart = Date.now();
      res = http.post(`${BASE_URL}/api/orders`, orderPayload, { headers });
      const orderDuration = Date.now() - orderStart;

      const orderSuccess = check(res, {
        'order created': (r) => r.status === 200 || r.status === 201,
        'order has id': (r) => {
          try {
            const body = r.json();
            return body && body.id;
          } catch (e) {
            return false;
          }
        },
      });

      if (orderSuccess) {
        orderCounter.add(1);
        orderCreationTime.add(orderDuration);
      }

      errorRate.add(!orderSuccess);
    }
  }

  sleep(2);

  // Test 4: Get user orders from Orders Service
  res = http.get(`${BASE_URL}/api/orders`, { headers });
  const ordersSuccess = check(res, {
    'orders fetched': (r) => r.status === 200,
    'orders is array': (r) => {
      try {
        const body = r.json();
        return Array.isArray(body);
      } catch (e) {
        return false;
      }
    },
  });

  errorRate.add(!ordersSuccess);
  sleep(1);

  // Test 5: Get specific product (single record lookup through gateway)
  const singleProductRes = http.get(`${BASE_URL}/api/products`, { headers });
  if (singleProductRes.status === 200) {
    try {
      const products = singleProductRes.json();
      if (products && products.length > 0) {
        const productId = products[0].id;
        res = http.get(`${BASE_URL}/api/products/${productId}`, { headers });
        check(res, { 'single product fetched': (r) => r.status === 200 });
      }
    } catch (e) {
      // Ignore parse errors
    }
  }

  sleep(1);

  // Test 6: Mixed operations to simulate real-world load
  // Simulates user browsing multiple categories and products
  res = http.get(`${BASE_URL}/api/categories`, { headers });
  if (res.status === 200) {
    sleep(0.5);
    res = http.get(`${BASE_URL}/api/products`, { headers });
  }

  sleep(1);
}

export function teardown(data) {
  console.log('Microservices test completed - cleaning up...');
}
