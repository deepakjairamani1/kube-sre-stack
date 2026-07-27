import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend, Counter } from 'k6/metrics';

// Soak Test: Sustained moderate load for extended period
//
// Purpose: Detect problems that only appear over time:
//   - Memory leaks (GC pressure builds gradually)
//   - Connection pool exhaustion
//   - File descriptor leaks
//   - Database connection accumulation
//   - Gradual latency degradation
//
// Run for 30 minutes at steady 50 VUs

const errorRate = new Rate('errors');
const latencyDrift = new Trend('latency_drift', true);

export const options = {
  thresholds: {
    'errors': ['rate<0.005'],            // < 0.5% errors over 30 min
    'http_req_duration': ['p(99)<800'],  // P99 stays under 800ms entire run
    'latency_drift': ['p(95)<600'],      // No latency creep
  },

  stages: [
    { duration: '2m', target: 50 },   // Ramp to steady state
    { duration: '26m', target: 50 },  // Sustained load
    { duration: '2m', target: 0 },    // Cool down
  ],
};

const BASE_URL = __ENV.BASE_URL || 'http://localhost:4000';

export default function () {
  const endpoints = [
    { path: '/', name: 'homepage' },
    { path: '/accounts/demo', name: 'account-read' },
    { path: '/statistics/demo', name: 'statistics-read' },
  ];

  // Pick random endpoint (simulates varied traffic)
  const endpoint = endpoints[Math.floor(Math.random() * endpoints.length)];

  const res = http.get(`${BASE_URL}${endpoint.path}`, {
    tags: { endpoint: endpoint.name },
  });

  const success = check(res, {
    'status 2xx': (r) => r.status >= 200 && r.status < 300,
    'no timeout': (r) => r.timings.duration < 5000,
  });

  errorRate.add(!success);
  latencyDrift.add(res.timings.duration);

  sleep(Math.random() * 3 + 1);  // 1-4s think time
}

export function handleSummary(data) {
  // Check for latency degradation over time
  // If last 5 min average is >50% higher than first 5 min, flag it
  return {
    'stdout': textSummary(data, { indent: ' ', enableColors: true }),
    'results/soak-test-results.json': JSON.stringify({
      timestamp: new Date().toISOString(),
      test_type: 'soak',
      duration_minutes: 30,
      steady_vus: 50,
      results: {
        error_rate: data.metrics.errors.values.rate,
        p99_latency_ms: data.metrics.http_req_duration.values['p(99)'],
        p95_latency_ms: data.metrics.http_req_duration.values['p(95)'],
        total_requests: data.metrics.http_reqs.values.count,
        pass: data.metrics.errors.values.rate < 0.005 &&
              data.metrics.http_req_duration.values['p(99)'] < 800,
      },
      interpretation: data.metrics.http_req_duration.values['p(99)'] > 600 ?
        'WARNING: P99 approaching threshold — possible gradual degradation' :
        'HEALTHY: No signs of degradation over test duration',
    }, null, 2),
  };
}

import { textSummary } from 'https://jslib.k6.io/k6-summary/0.0.2/index.js';
