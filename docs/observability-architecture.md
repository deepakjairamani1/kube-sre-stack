# Observability Architecture

## Overview

This project implements **Observability-as-Code** — every metric, dashboard, alert rule, and scrape target is defined in Git and deployed via ArgoCD.

```
┌─────────────────────────────────────────────────────────────────┐
│                    OBSERVABILITY STACK                           │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                    GRAFANA                                │   │
│  │  ┌────────────┐ ┌──────────────┐ ┌───────────────────┐  │   │
│  │  │ App Golden │ │ Infra Health │ │   SLO Dashboard   │  │   │
│  │  │  Signals   │ │ (Mongo/RMQ)  │ │ (Error Budgets)   │  │   │
│  │  └────────────┘ └──────────────┘ └───────────────────┘  │   │
│  └─────────────────────────────────────────────────────────┘   │
│                              ▲                                   │
│                              │ PromQL                            │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                   PROMETHEUS                              │   │
│  │                                                           │   │
│  │  Recording Rules ──→ Pre-computed SLIs                    │   │
│  │  Alert Rules ─────→ Multi-window burn rate                │   │
│  │  ServiceMonitors ─→ Scrape targets (auto-discovery)       │   │
│  │  PodMonitors ─────→ StatefulSet + sidecar scraping        │   │
│  └─────────────────────────────────────────────────────────┘   │
│                              ▲                                   │
│                              │ /metrics                          │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌────────────────┐    │
│  │ Gateway  │ │ Account  │ │   Auth   │ │  Statistics    │    │
│  │ /actuator│ │ /actuator│ │ /actuator│ │  /actuator     │    │
│  │/prometheus│/prometheus│ │/prometheus│ │ /prometheus    │    │
│  └──────────┘ └──────────┘ └──────────┘ └────────────────┘    │
│                                                                 │
│  ┌──────────┐ ┌──────────┐ ┌──────────────────────────────┐   │
│  │ MongoDB  │ │ RabbitMQ │ │    Nginx Ingress Controller  │   │
│  │ Exporter │ │ /metrics │ │         /metrics             │   │
│  └──────────┘ └──────────┘ └──────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

## Components

| Component | Purpose | Path |
|-----------|---------|------|
| ServiceMonitors | Tell Prometheus what to scrape | `k8s/observability/service-monitors/` |
| PodMonitors | Scrape StatefulSets and sidecars | `k8s/observability/pod-monitors/` |
| Recording Rules | Pre-compute expensive queries | `k8s/observability/recording-rules/` |
| Alert Rules | SLO burn-rate + golden signal alerts | `k8s/alerting/rules/` |
| AlertManager | Route alerts to Slack/PagerDuty | `k8s/alertmanager/` |
| Grafana Dashboards | Visual monitoring (JSON-as-code) | `k8s/observability/grafana-dashboards/` |
| Dashboard Provisioning | Auto-load dashboards via sidecar | `k8s/observability/grafana-provisioning/` |

## Metrics Flow

1. **ServiceMonitor** discovers pods via label selector
2. **Prometheus** scrapes `/actuator/prometheus` every 15-30s
3. **Recording Rules** pre-compute SLIs (availability, latency percentiles)
4. **Alert Rules** evaluate burn rates against pre-computed metrics
5. **AlertManager** routes to Slack/PagerDuty based on severity
6. **Grafana Dashboards** query pre-computed recording rules (instant load)

## Adding a New Service

To add observability for a new service:

```bash
# 1. Ensure your service exposes /metrics or /actuator/prometheus
# 2. Add a ServiceMonitor:
cat <<EOF | kubectl apply -f -
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: my-service
  namespace: piggymetrics
  labels:
    release: kube-prometheus-stack
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: my-service
  endpoints:
    - port: http
      path: /actuator/prometheus
      interval: 15s
EOF

# 3. Verify scraping:
kubectl port-forward svc/prometheus 9090 -n observability
# Open http://localhost:9090/targets — your service should appear

# 4. Add recording rules if needed (for SLO tracking)
# 5. Add dashboard panels
# 6. Commit to Git → ArgoCD syncs automatically
```

## Key Design Decisions

- **Recording rules over raw queries**: Dashboards use `service:http_requests:rate5m` instead of recalculating `rate(http_requests_total[5m])` every time
- **15s scrape for user-facing, 30s for background**: Balances detection speed vs storage cost
- **Sidecar provisioning for dashboards**: No manual Grafana UI changes — everything survives pod restarts
- **Drop high-cardinality metrics**: `jvm_buffer_*` dropped via metricRelabelings to control storage
