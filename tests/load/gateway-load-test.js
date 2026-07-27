import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend } from 'k6/metrics';

// Custom metrics for SLO validation
const errorRate = new Rate('slo_error_rate');
const latencyP99 = new Trend('slo_latency_p99', true);

// SLO Thresholds — test FAILS if these are breached
export const options = {
  thresholds: {
    // Availability SLO: 99.9% success rate
    'slo_error_rate': ['rate<0.001'],
    // Latency SLO: P99 < 500ms
    'http_req_duration': ['p(99)<500'],
    // P95 should be < 200ms
    'http_req_duration': ['p(95)<200', 'p(99)<500'],
  },

  // Load profile: ramp up → sustained → ramp down
  stages: [
    { duration: '1m', target: 20 },   // Warm up
    { duration: '3m', target: 50 },   // Normal load
    { duration: '2m', target: 100 },  // Peak load
    { duration: '1m', target: 150 },  // Stress test
    { duration: '1m', target: 0 },    // Cool down
  ],
};

const BASE_URL = __ENV.BASE_URL || 'http://localhost:4000';

export default function () {
  // Simulate real user flow
  const responses = http.batch([
    ['GET', `${BASE_URL}/`, null, { tags: { endpoint: 'homepage' } }],
    ['GET', `${BASE_URL}/accounts/demo`, null, { tags: { endpoint: 'demo-account' } }],
    ['GET', `${BASE_URL}/statistics/demo`, null, { tags: { endpoint: 'demo-stats' } }],
  ]);

  // Check each response
  responses.forEach((res) => {
    const success = check(res, {
      'status is 200': (r) => r.status === 200,
      'response time < 500ms': (r) => r.timings.duration < 500,
    });

    // Record for SLO metrics
    errorRate.add(!success);
    latencyP99.add(res.timings.duration);
  });

  // Think time between requests (realistic user behavior)
  sleep(Math.random() * 2 + 1);
}

// Summary output for CI integration
export function handleSummary(data) {
  const sloPass = data.metrics.slo_error_rate.values.rate < 0.001 &&
                  data.metrics.http_req_duration.values['p(99)'] < 500;

  return {
    'stdout': textSummary(data, { indent: ' ', enableColors: true }),
    'results/load-test-results.json': JSON.stringify({
      timestamp: new Date().toISOString(),
      slo_validation: {
        availability: {
          target: '99.9%',
          actual: `${((1 - data.metrics.slo_error_rate.values.rate) * 100).toFixed(3)}%`,
          pass: data.metrics.slo_error_rate.values.rate < 0.001,
        },
        latency_p99: {
          target: '< 500ms',
          actual: `${data.metrics.http_req_duration.values['p(99)'].toFixed(1)}ms`,
          pass: data.metrics.http_req_duration.values['p(99)'] < 500,
        },
        latency_p95: {
          target: '< 200ms',
          actual: `${data.metrics.http_req_duration.values['p(95)'].toFixed(1)}ms`,
          pass: data.metrics.http_req_duration.values['p(95)'] < 200,
        },
      },
      overall_pass: sloPass,
      total_requests: data.metrics.http_reqs.values.count,
      peak_rps: data.metrics.http_reqs.values.rate,
    }, null, 2),
  };
}

import { textSummary } from 'https://jslib.k6.io/k6-summary/0.0.2/index.js';
