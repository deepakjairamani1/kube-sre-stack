# Load Testing & SLO Validation

Validates that PiggyMetrics meets its SLO targets under realistic production load.

## Tests

| Test | Duration | VUs | What it validates |
|------|----------|-----|-------------------|
| `gateway-load-test.js` | 8 min | 20 → 150 | Availability 99.9%, P99 < 500ms |
| `auth-spike-test.js` | 4 min | 10 → 100 rps | Auth resilience under 10x spike |
| `soak-test.js` | 30 min | 50 steady | No memory leaks or latency drift |

## Quick Start

```bash
# Install k6
brew install k6

# Run all standard tests (local)
make all

# Run against specific environment
make test-dev
make test-staging

# Run soak test (before major releases)
make soak
```

## SLO Thresholds (Tests fail if breached)

| SLO | Target | Measured by |
|-----|--------|-------------|
| Availability | 99.9% | HTTP 2xx response rate |
| Latency P99 | < 500ms | 99th percentile response time |
| Latency P95 | < 200ms | 95th percentile response time |
| Auth success rate | > 99% | Token endpoint success under spike |

## When to Run

- **Pre-merge**: Gateway test on every PR (via CI)
- **Pre-release**: Full suite (gateway + auth + soak) before prod deploy
- **Post-deploy**: Canary test against new version (`make test-prod-canary`)
- **Weekly**: Soak test to catch gradual degradation

## Results

Tests output JSON results to `results/` directory:
```json
{
  "slo_validation": {
    "availability": { "target": "99.9%", "actual": "99.95%", "pass": true },
    "latency_p99": { "target": "< 500ms", "actual": "312ms", "pass": true }
  },
  "overall_pass": true
}
```

## Integration with CI/CD

Load tests gate deployments:
1. PR merged → ArgoCD deploys to dev
2. Load test runs against dev → must pass
3. Only if pass → promote to prod via image tag update

This ensures no deployment degrades performance below SLO targets.
