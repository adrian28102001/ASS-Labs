import http from 'k6/http';
import { check, sleep } from 'k6';
import { Counter, Trend, Rate } from 'k6/metrics';

// Custom metrics
const orderCreationTime = new Trend('order_creation_duration');
const productFetchTime = new Trend('product_fetch_duration');
const errorRate = new Rate('errors');
const orderCounter = new Counter('orders_created');

export const options = {
  stages: [
    { duration: '30s', target: 20 },   // Ramp up to 20 users
    { duration: '1m', target: 50 },    // Stay at 50 users
    { duration: '30s', target: 100 },  // Spike to 100 users
    { duration: '1m', target: 100 },   // Sustain 100 users
    { duration: '30s', target: 0 },    // Ramp down
  ],
  thresholds: {
    'http_req_duration': ['p(95)<500', 'p(99)<1000'],  // 95% < 500ms, 99% < 1000ms
    'http_req_failed': ['rate<0.05'],  // Error rate < 5%
    'order_creation_duration': ['p(95)<800'],
    'product_fetch_duration': ['p(95)<300'],
  },
};

const BASE_URL = 'http://localhost:5000';

export function setup() {
  console.log('Setting up test - logging in...');

  // Login to get JWT token
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
  console.log('Setup complete - token obtained');

  return { token };
}

export default function (data) {
  const headers = {
    'Authorization': `Bearer ${data.token}`,
    'Content-Type': 'application/json',
  };

  // Test 1: Get all products (READ heavy operation)
  let res = http.get(`${BASE_URL}/api/products`, { headers });
  const productFetchSuccess = check(res, {
    'products status 200': (r) => r.status === 200,
    'products response time < 500ms': (r) => r.timings.duration < 500,
    'products returned data': (r) => r.body.length > 0,
  });

  productFetchTime.add(res.timings.duration);
  errorRate.add(!productFetchSuccess);

  sleep(1);

  // Test 2: Get categories
  res = http.get(`${BASE_URL}/api/categories`, { headers });
  const categorySuccess = check(res, {
    'categories status 200': (r) => r.status === 200,
    'categories has data': (r) => r.body.length > 0,
  });

  errorRate.add(!categorySuccess);
  sleep(1);

  // Test 3: Create order (WRITE operation - more demanding)
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

  // Test 4: Get user orders (READ - with JOIN operations)
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

  // Test 5: Get specific product (single record lookup)
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
}

export function teardown(data) {
  console.log('Test completed - cleaning up...');
}
