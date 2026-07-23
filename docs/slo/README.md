# Service Level Framework

> A practical guide to measuring, targeting, and committing to service reliability.

This directory contains everything you need to understand and implement Service Level
Indicators (SLIs), Objectives (SLOs), and Agreements (SLAs) for the kube-sre-stack platform.

---

## The Big Picture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                                                                         │
│   What you MEASURE        What you TARGET        What you PROMISE       │
│                                                                         │
│   ┌───────────┐          ┌───────────┐          ┌───────────┐          │
│   │           │          │           │          │           │          │
│   │    SLI    │────────▶ │    SLO    │────────▶ │    SLA    │          │
│   │           │          │           │          │           │          │
│   └───────────┘          └───────────┘          └───────────┘          │
│                                                                         │
│   "99.95% of requests    "We target 99.9%      "If we drop below       │
│    returned in <300ms"    availability"          99.5%, customers        │
│                                                  get credits"           │
│                                                                         │
│   ─────────────────────────────────────────────────────────────────     │
│   Technical metric    →   Internal goal     →   External contract       │
│   (engineering)           (team/org)            (business/legal)         │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Quick Summary

**SLI (Service Level Indicator)** — A quantitative measurement of some aspect of your
service's behavior. Think of it as the raw data: "What percentage of requests succeeded?"
or "What was the 99th percentile latency?" SLIs are the foundation — without good
measurements, everything else is guesswork.

**SLO (Service Level Objective)** — A target value (or range) for an SLI, measured over
a time window. It answers: "How reliable do we *want* to be?" SLOs create error budgets
that balance reliability with development velocity. When the budget runs low, you slow
down and fix things.

**SLA (Service Level Agreement)** — A formal contract between a service provider and its
customers that specifies consequences (usually financial) for failing to meet agreed-upon
service levels. SLAs should always be less strict than your internal SLOs, giving you a
safety buffer.

---

## How They Relate

```
                        ┌───────────┐
                        │    SLA    │  ← Contract (consequences if broken)
                        │  99.5%    │
                        └─────┬─────┘
                              │
                        ┌─────▼─────┐
                        │    SLO    │  ← Target (internal goal, tighter)
                        │  99.9%    │
                        └─────┬─────┘
                              │
                  ┌───────────▼───────────┐
                  │         SLI           │  ← Measurement (actual data)
                  │   current: 99.95%     │
                  └───────────────────────┘

              THE PYRAMID: Broad base of measurements,
              narrow peak of contractual commitments.
```

**The Driving Analogy:**

| Concept | Driving | Service Reliability |
|---------|---------|---------------------|
| **SLI** | Speedometer reading | Measured request success rate |
| **SLO** | Speed limit sign | Your internal reliability target |
| **SLA** | Traffic fine | Contractual penalty for violations |

Your speedometer (SLI) *measures* your speed. The speed limit (SLO) is the *target* you
try to stay within. The traffic fine (SLA) is the *consequence* if you blow past the limit
badly enough for it to matter legally.

Key insight: **Your SLO should always be stricter than your SLA.** If your SLA promises
99.5% and your SLO targets 99.9%, you have a 0.4% buffer before contractual penalties
kick in.

---

## Document Index

| Document | Description | Read when you need to... |
|----------|-------------|--------------------------|
| [SLI Guide](./sli-guide.md) | Understanding what to measure | Choose metrics, write PromQL queries, avoid measurement pitfalls |
| [SLO Guide](./slo-guide.md) | Setting reliability targets | Define targets, calculate error budgets, set up MWMBR alerts |
| [SLA Guide](./sla-guide.md) | Formalizing commitments | Write contracts, define penalties, structure SLA reviews |

---

## Getting Started

**Recommended reading order:**

```
 Step 1          Step 2          Step 3
┌─────────┐    ┌─────────┐    ┌─────────┐
│   SLI   │───▶│   SLO   │───▶│   SLA   │
│  Guide  │    │  Guide  │    │  Guide  │
└─────────┘    └─────────┘    └─────────┘
 "What do       "What's our    "What do we
  we measure?"   target?"       promise?"
```

1. **Start with [SLI Guide](./sli-guide.md)** — You can't set targets without knowing what
   to measure. Learn the 4 golden signals, SLI types, and how to write PromQL queries.

2. **Then read [SLO Guide](./slo-guide.md)** — Once you know your SLIs, set meaningful
   targets. Learn about error budgets, burn rates, and multi-window alerting.

3. **Finally, read [SLA Guide](./sla-guide.md)** — With SLOs running internally, you're
   ready to formalize external commitments. Learn about contracts, credits, and review
   processes.

---

## How This Applies to kube-sre-stack

The kube-sre-stack runs the **PiggyMetrics** microservices application on EKS. Here's how
the Service Level Framework maps to our actual infrastructure:

```
┌─────────────────────────────────────────────────────────────┐
│                    kube-sre-stack                            │
│                                                             │
│  Application Layer (PiggyMetrics)                           │
│  ├── gateway          → Availability & Latency SLIs        │
│  ├── account-service  → Correctness & Latency SLIs         │
│  ├── auth-service     → Availability & Latency SLIs        │
│  ├── statistics-svc   → Freshness & Throughput SLIs        │
│  └── notification-svc → Delivery Success SLIs              │
│                                                             │
│  Data Layer                                                 │
│  ├── mongodb          → Durability & Latency SLIs          │
│  └── rabbitmq         → Queue Depth & Delivery SLIs        │
│                                                             │
│  Platform Layer                                             │
│  ├── eks cluster      → API Server Availability SLI        │
│  ├── karpenter        → Scheduling Latency SLI             │
│  └── argocd           → Sync Success Rate SLI              │
│                                                             │
│  Observability Layer                                        │
│  ├── prometheus       → Scrape Success & Ingestion SLIs    │
│  ├── grafana          → Dashboard Availability SLI         │
│  └── alertmanager     → Notification Delivery SLI          │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Example SLO chain for the Gateway service:**

| Layer | SLI | SLO Target | SLA Commitment |
|-------|-----|------------|----------------|
| Gateway Availability | `successful_requests / total_requests` | 99.9% (30d rolling) | 99.5% |
| Gateway Latency | `requests < 300ms / total_requests` | 99.0% (30d rolling) | 95.0% |
| ArgoCD Deploys | `successful_syncs / total_syncs` | 95.0% (7d rolling) | — (internal only) |

**Where the pieces live in this repo:**

| Component | Path |
|-----------|------|
| Prometheus recording rules | `k8s/observability/recording-rules/` |
| Alerting rules (MWMBR) | `k8s/alerting/rules/` |
| Grafana dashboards | `k8s/observability/grafana-dashboards/` |
| AlertManager config | `k8s/alertmanager/alertmanager-config.yaml` |
| SLO burn-rate runbook | `docs/runbooks/slo-fast-burn.md` |
| MWMBR ADR | `docs/adr/002-mwmbr-alerting-strategy.md` |

---

## References

**Google SRE Books (free online):**

- [Chapter 4: Service Level Objectives](https://sre.google/sre-book/service-level-objectives/) — The foundational chapter on SLIs, SLOs, and SLAs
- [Chapter 5: Eliminating Toil](https://sre.google/sre-book/eliminating-toil/) — Context on why SLOs drive automation
- [The Art of SLOs (Workbook)](https://sre.google/workbook/implementing-slos/) — Step-by-step SLO implementation guide
- [Alerting on SLOs](https://sre.google/workbook/alerting-on-slos/) — Multi-window, multi-burn-rate alerting

**Additional Resources:**

- [Google Cloud: Defining SLOs](https://cloud.google.com/architecture/defining-SLOs) — Practical patterns
- [Prometheus Recording Rules](https://prometheus.io/docs/prometheus/latest/configuration/recording_rules/) — How to implement SLI recording rules
- [OpenSLO Specification](https://openslo.com/) — Vendor-neutral SLO-as-code standard
- [Sloth](https://github.com/slok/sloth) — Generate Prometheus SLO rules from simple specs
- [Pyrra](https://github.com/pyrra-dev/pyrra) — SLO monitoring and alerting for Prometheus

**Internal docs:**

- [Architecture Overview](../architecture.md)
- [Observability Architecture](../observability-architecture.md)
- [MWMBR Alerting Strategy (ADR-002)](../adr/002-mwmbr-alerting-strategy.md)
- [SLO Fast-Burn Runbook](../runbooks/slo-fast-burn.md)
