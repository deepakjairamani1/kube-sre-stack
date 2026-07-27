import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate } from 'k6/metrics';

// Spike test: sudden traffic burst to auth service
// Validates that OAuth2 token endpoint handles sudden load
// Common scenario: marketing campaign launch, viral event

const authFailRate = new Rate('auth_failures');

export const options = {
  thresholds: {
    // Auth must stay available even under spike
    'auth_failures': ['rate<0.01'],  // <1% failure allowed
    'http_req_duration{endpoint:token}': ['p(95)<1000'],  // Token endpoint < 1s
  },

  scenarios: {
    // Normal baseline traffic
    baseline: {
      executor: 'constant-arrival-rate',
      rate: 10,
      timeUnit: '1s',
      duration: '2m',
      preAllocatedVUs: 20,
      maxVUs: 50,
    },
    // Sudden spike (3x normal)
    spike: {
      executor: 'ramping-arrival-rate',
      startRate: 10,
      timeUnit: '1s',
      stages: [
        { duration: '10s', target: 10 },   // Normal
        { duration: '5s', target: 100 },   // Sudden spike!
        { duration: '30s', target: 100 },  // Sustained spike
        { duration: '10s', target: 10 },   // Back to normal
        { duration: '1m', target: 10 },    // Recovery observation
      ],
      preAllocatedVUs: 100,
      maxVUs: 200,
      startTime: '2m',  // Start after baseline establishes
    },
  },
};

const BASE_URL = __ENV.BASE_URL || 'http://localhost:5000';

export default function () {
  // OAuth2 token request (most critical auth endpoint)
  const tokenPayload = {
    grant_type: 'client_credentials',
    scope: 'server',
  };

  const tokenRes = http.post(
    `${BASE_URL}/oauth/token`,
    tokenPayload,
    {
      headers: {
        'Authorization': 'Basic YWNjb3VudC1zZXJ2aWNlOmNoYW5nZWl0',  // base64(account-service:changeit)
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      tags: { endpoint: 'token' },
    }
  );

  const tokenSuccess = check(tokenRes, {
    'token status 200': (r) => r.status === 200,
    'token has access_token': (r) => {
      try { return JSON.parse(r.body).access_token !== undefined; }
      catch { return false; }
    },
    'token response < 1s': (r) => r.timings.duration < 1000,
  });

  authFailRate.add(!tokenSuccess);

  // Validate token endpoint
  if (tokenSuccess) {
    const token = JSON.parse(tokenRes.body).access_token;
    const validateRes = http.get(`${BASE_URL}/users/current`, {
      headers: { 'Authorization': `Bearer ${token}` },
      tags: { endpoint: 'validate' },
    });

    check(validateRes, {
      'validate returns user': (r) => r.status === 200 || r.status === 401,
    });
  }

  sleep(0.1);  // Minimal think time for spike test
}
