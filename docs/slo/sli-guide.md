# SLI (Service Level Indicators) — A Comprehensive Guide

> **Audience:** SREs, Platform Engineers, and Developers working with kube-sre-stack  
> **Last Updated:** 2026-07-23

---

## Table of Contents

1. [What is an SLI?](#what-is-an-sli)
2. [Why SLIs Matter](#why-slis-matter)
3. [The 4 Golden Signals as SLIs](#the-4-golden-signals-as-slis)
4. [Types of SLIs](#types-of-slis)
5. [How to Measure SLIs](#how-to-measure-slis)
6. [SLI Specification vs Implementation](#sli-specification-vs-implementation)
7. [Real-World Examples](#real-world-examples-for-kube-sre-stack)
8. [Prometheus/PromQL Examples](#prometheuspromql-examples)
9. [Best Practices](#best-practices)
10. [Common Mistakes](#common-mistakes)

---

## What is an SLI?

### Plain English

An **SLI (Service Level Indicator)** is a carefully chosen metric that tells you how well your service is performing **from the user's perspective**.

Think of it as a **thermometer for your service's health** — it doesn't tell you *why* something is wrong, but it tells you *that* something is wrong (or right).

### Analogy: The Restaurant

Imagine you run a restaurant:

```
+-----------------------------------------------------------+
|                    RESTAURANT ANALOGY                       |
+-----------------------------------------------------------+
|                                                           |
|  SLI = "What percentage of meals were served             |
|          within 15 minutes of ordering?"                  |
|                                                           |
|  SLO = "We promise 95% of meals will be served           |
|          within 15 minutes"                               |
|                                                           |
|  SLA = "If we break that promise, your next              |
|          meal is free"                                    |
|                                                           |
+-----------------------------------------------------------+
```

- The **SLI** is the measurement (e.g., "today, 92% of meals were served in 15 minutes")
- The **SLO** is the target you set internally (e.g., "we aim for 95%")
- The **SLA** is the contract with your customers (e.g., "if we drop below 90%, we refund")

### Formal Definition

An SLI is a **ratio** expressed as:

```
SLI = (Good Events / Total Events) × 100%
```

Where:
- **Good Events** = requests/operations that met the quality threshold
- **Total Events** = all requests/operations in the measurement window

This always produces a value between **0% and 100%**, making it easy to set targets and reason about.

---

## Why SLIs Matter

### From a Business Perspective

| Without SLIs | With SLIs |
|---|---|
| "Users are complaining about slowness" | "P99 latency increased from 200ms to 1.2s in the last hour" |
| "I think the site is down sometimes" | "Availability dropped to 99.2% this week (budget: 99.9%)" |
| "We should probably fix that service" | "We've burned 80% of our error budget — we must act now" |
| Reactive firefighting | Proactive, data-driven decisions |

### From an Engineering Perspective

1. **Objective decision-making** — Should we ship a new feature or fix reliability? SLIs give you the answer.
2. **Error budgets** — SLIs feed into error budgets that tell you how much risk you can tolerate.
3. **Alert on what matters** — Instead of alerting on CPU > 80%, alert when users are actually affected.
4. **Common language** — Product, engineering, and leadership can all understand "99.5% availability."

```
  ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
  │   SLI       │────▶│   SLO       │────▶│   Error     │
  │ (Measure)   │     │ (Target)    │     │   Budget    │
  └─────────────┘     └─────────────┘     └─────────────┘
        │                                        │
        │              ┌─────────────┐           │
        └─────────────▶│  Alerting   │◀──────────┘
                       │  & Actions  │
                       └─────────────┘
```

---

## The 4 Golden Signals as SLIs

Google's SRE book defines **four golden signals** that every service should monitor. Each maps naturally to an SLI:

```
┌────────────────────────────────────────────────────────────┐
│              THE 4 GOLDEN SIGNALS                           │
├────────────────────────────────────────────────────────────┤
│                                                            │
│   ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐ │
│   │ LATENCY  │  │ TRAFFIC  │  │  ERRORS  │  │SATURATION│ │
│   │          │  │          │  │          │  │          │  │
│   │ How long │  │ How much │  │ How many │  │ How full │  │
│   │ it takes │  │ demand   │  │ failures │  │ it is    │  │
│   └──────────┘  └──────────┘  └──────────┘  └──────────┘ │
│                                                            │
└────────────────────────────────────────────────────────────┘
```

### 1. Latency

**What:** How long it takes to serve a request.

**Why it matters:** Even if your service is "up," if it takes 30 seconds to respond, users will leave.

**Key insight:** Always separate successful request latency from failed request latency. A fast 500 error is not "good latency."

**Formula:**

```
Latency SLI = (Requests completed in < threshold) / (Total requests) × 100%
```

**Example:** "The proportion of HTTP requests that complete in less than 300ms"

### 2. Traffic

**What:** How much demand is being placed on your system.

**Why it matters:** Helps you understand normal patterns and detect anomalies (sudden spikes or drops).

**Formula:**

```
Traffic SLI = Requests per second (or transactions per second)
```

**Note:** Traffic is often used as a *context signal* rather than an SLI with a target. However, it can be expressed as:

```
Throughput SLI = (Requests successfully processed) / (Requests received) × 100%
```

### 3. Errors

**What:** The rate of requests that fail.

**Why it matters:** Direct measure of user-visible failures.

**Formula:**

```
Error SLI = (Successful requests) / (Total requests) × 100%

# Equivalently:
Error Rate = (Failed requests) / (Total requests) × 100%
Error SLI = 100% - Error Rate
```

**Types of errors to consider:**
- **Explicit errors** — HTTP 5xx responses, gRPC error codes
- **Implicit errors** — HTTP 200 with wrong content, timeout without error code
- **Policy violations** — Response that violates business rules

### 4. Saturation

**What:** How "full" your service is — how close it is to capacity limits.

**Why it matters:** Most services degrade gracefully and then suddenly fall off a cliff.

**Formula:**

```
Saturation SLI = (Current resource usage) / (Resource capacity) × 100%
```

**Key resources to measure:**
- CPU utilization
- Memory usage
- Disk I/O
- Network bandwidth
- Connection pool usage
- Queue depth

### Summary Table

| Signal | Question | SLI Formula | Unit |
|--------|----------|-------------|------|
| Latency | "Is it fast enough?" | Requests < threshold / Total requests | % |
| Traffic | "How much load?" | Requests per second | req/s |
| Errors | "Is it working?" | Successful requests / Total requests | % |
| Saturation | "Is it at capacity?" | Current usage / Total capacity | % |

---

## Types of SLIs

Not all services are the same. Choose SLI types based on what your users care about:

### Overview Table

| SLI Type | Definition | Best For | Example |
|----------|-----------|----------|---------|
| **Availability** | Was the service reachable and able to process requests? | All user-facing services | 99.9% of requests got a non-5xx response |
| **Latency** | How quickly did the service respond? | APIs, web apps, real-time systems | 95% of requests completed in < 200ms |
| **Throughput** | How many requests can the system handle? | Batch processing, data pipelines | Processed 10,000 events/sec |
| **Correctness** | Did the service return the right answer? | Financial systems, data processing | 99.99% of calculations returned correct results |
| **Freshness** | Is the data up-to-date? | Caches, search indices, dashboards | 99% of queries return data < 1 minute old |
| **Durability** | Is stored data safe from loss? | Storage systems, databases | 99.999% of stored objects are retrievable |

### Deep Dive: Each Type

#### Availability SLI

```
Availability = (Total requests - Server errors) / Total requests × 100%
```

- Measures whether the service **can** respond
- Excludes client errors (4xx) — those are the user's fault
- Most fundamental SLI — if you only pick one, pick this

#### Latency SLI

```
Latency SLI = (Requests faster than threshold) / (Total requests) × 100%
```

- Use **multiple thresholds** for a complete picture:
  - P50 (median) — "typical" user experience
  - P90 — "most" users' experience
  - P99 — "worst-case" user experience
- Always exclude failed requests (a fast error is not "good")

#### Throughput SLI

```
Throughput SLI = (Successfully processed items) / (Items submitted) × 100%
```

- Important for batch/async systems
- Measures capacity, not speed

#### Correctness SLI

```
Correctness = (Requests with correct response) / (Total requests) × 100%
```

- Hardest to measure — requires knowing what "correct" means
- Techniques: checksums, comparison testing, golden dataset validation
- Critical for: payment processing, search relevance, ML inference

#### Freshness SLI

```
Freshness = (Queries returning data newer than threshold) / (Total queries) × 100%
```

- Important for read-replicas, caches, search indices
- Example: "99% of search results reflect changes made < 5 minutes ago"

#### Durability SLI

```
Durability = (Objects successfully retrieved) / (Objects stored) × 100%
```

- Measured over long time periods (monthly, yearly)
- Usually expressed with many 9s (99.999999999% for S3-like systems)
- Verified through periodic audits, not real-time measurement

---

## How to Measure SLIs

There are three primary approaches to measuring SLIs, each with tradeoffs:

### Measurement Points

```
┌──────────┐         ┌──────────────┐         ┌──────────────┐
│  Client  │────────▶│  Load        │────────▶│  Application │
│  (User)  │◀────────│  Balancer    │◀────────│  Server      │
└──────────┘         └──────────────┘         └──────────────┘
     │                      │                        │
     ▼                      ▼                        ▼
 Client-side           Infrastructure            Server-side
 Measurement           Measurement              Measurement
 (RUM, SDK)            (LB logs, mesh)          (App metrics)
```

### Comparison Table

| Approach | Accuracy | Coverage | Complexity | Best For |
|----------|----------|----------|------------|----------|
| **Server-side** | Medium | Backend only | Low | Internal services, APIs |
| **Infrastructure** (LB/mesh) | Medium-High | Request path | Medium | Services behind a proxy |
| **Client-side** (RUM) | Highest | Full user experience | High | User-facing web/mobile apps |
| **Synthetic monitoring** | Low (probes only) | Happy paths | Medium | Availability checks, baselines |

### Server-Side Measurement

**How:** Application exports metrics directly (e.g., via Prometheus client libraries)

**Pros:**
- Easy to implement
- Rich context (can tag by endpoint, user tier, etc.)
- Low overhead

**Cons:**
- Misses network latency between client and server
- Doesn't capture load balancer errors
- Can't measure "total unavailability" (if server is down, it can't report)

**Example (Go):**
```go
httpDuration := prometheus.NewHistogramVec(
    prometheus.HistogramOpts{
        Name:    "http_request_duration_seconds",
        Help:    "Duration of HTTP requests",
        Buckets: []float64{0.05, 0.1, 0.25, 0.5, 1.0, 2.5},
    },
    []string{"handler", "method", "status_code"},
)
```

### Client-Side Measurement (Real User Monitoring)

**How:** JavaScript SDK in browser, mobile SDK in apps, or instrumented clients

**Pros:**
- Captures the true user experience (includes DNS, TCP, TLS, network)
- Detects issues invisible to the server (CDN problems, ISP issues)

**Cons:**
- Noisy (user's slow WiFi affects measurements)
- Sampling bias (only measures users who loaded your JS)
- Higher implementation effort

### Synthetic Monitoring

**How:** Automated probes that simulate user requests at regular intervals

**Pros:**
- Consistent baseline (no noise from real user variability)
- Works even when there's no real traffic (nights, weekends)
- Can test specific user journeys

**Cons:**
- Only tests what you programmed it to test
- Limited coverage (can't find issues in paths you didn't probe)
- May not represent real user conditions

**When to use each:**

```
┌─────────────────────────────────────────────────────────┐
│  Use Server-Side when:                                  │
│  • You control the application code                     │
│  • Internal service-to-service communication            │
│  • You need low-overhead, high-cardinality metrics      │
├─────────────────────────────────────────────────────────┤
│  Use Client-Side when:                                  │
│  • User-facing web or mobile application                │
│  • You need to measure full page load experience        │
│  • Network path issues are a concern                    │
├─────────────────────────────────────────────────────────┤
│  Use Synthetic when:                                    │
│  • You need availability monitoring 24/7                │
│  • Low-traffic services that need baseline data         │
│  • Verifying SLAs from external vantage points          │
└─────────────────────────────────────────────────────────┘
```

---

## SLI Specification vs Implementation

This is a critical distinction that many teams miss. Separating **what** you want to measure from **how** you measure it gives you flexibility.

### SLI Specification (The "What")

A high-level description of what you want to measure, independent of any specific tool or system.

**Example:**
> "The proportion of valid HTTP requests that are served successfully"

Key properties:
- Technology-agnostic
- Focused on user experience
- Stable over time (doesn't change when you swap monitoring tools)

### SLI Implementation (The "How")

The concrete way you measure the specification using specific tools, metrics, and queries.

**Example:**
> "The count of HTTP 200-499 responses divided by total HTTP responses, measured at the Istio ingress gateway, computed over a 5-minute rolling window using Prometheus"

Key properties:
- Technology-specific
- May change as infrastructure evolves
- Multiple implementations can satisfy the same specification

### Why This Separation Matters

```
┌─────────────────────────────────────────────────────────────┐
│ SLI SPECIFICATION                                           │
│ "Proportion of requests served faster than 300ms"           │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│ IMPLEMENTATION A          │  IMPLEMENTATION B               │
│ (Current)                 │  (After migration)              │
│                           │                                 │
│ Source: nginx access logs │  Source: Envoy access logs      │
│ Tool: Prometheus          │  Tool: Prometheus               │
│ Metric: nginx_http_       │  Metric: envoy_cluster_         │
│   request_duration_       │    upstream_rq_time_bucket      │
│   seconds_bucket          │                                 │
│                           │                                 │
└─────────────────────────────────────────────────────────────┘
```

When you migrate from nginx to Envoy, your **SLI specification stays the same** — only the implementation changes. This means:
- SLO targets don't need re-negotiation
- Historical comparisons remain valid
- Stakeholders aren't confused by metric name changes

### Template

| Field | Specification | Implementation |
|-------|---------------|----------------|
| **Description** | What are we measuring? | How exactly do we measure it? |
| **Perspective** | User-centric | System-centric |
| **Stability** | Rarely changes | Changes with infrastructure |
| **Example** | "Requests served successfully" | `sum(rate(http_requests_total{code!~"5.."}[5m])) / sum(rate(http_requests_total[5m]))` |

---

## Real-World Examples for kube-sre-stack

Here are practical SLI definitions for components commonly found in a Kubernetes-based microservices platform.

### API Gateway SLIs

The API gateway (e.g., Nginx Ingress, Istio Gateway, or Traefik) is the front door to your platform.

```
┌─────────┐      ┌──────────────┐      ┌───────────────┐
│  Users  │─────▶│ API Gateway  │─────▶│ Microservices │
└─────────┘      │ (Ingress)    │      └───────────────┘
                 └──────────────┘
                       │
                 Measure SLIs here
                 (closest to user)
```

| SLI | Specification | Target | Measurement Point |
|-----|---------------|--------|-------------------|
| Availability | Proportion of non-5xx responses to total requests | 99.9% | Ingress controller metrics |
| Latency (P50) | Proportion of requests faster than 100ms | 95% | Ingress controller metrics |
| Latency (P99) | Proportion of requests faster than 500ms | 99% | Ingress controller metrics |
| Throughput | Requests successfully processed per second | ≥ 1000 req/s | Ingress controller metrics |

**Key considerations:**
- Measure at the ingress level, not at individual services
- Exclude health check endpoints (`/healthz`, `/readyz`) from SLI calculations
- Separate by customer tier if you have different SLOs for free vs. paid users
- Exclude 4xx errors — those are client mistakes, not service failures

### Database SLIs

Databases (PostgreSQL, MySQL, Redis) are critical dependencies.

```
┌───────────────┐      ┌──────────────┐      ┌─────────┐
│ Application   │─────▶│  Connection  │─────▶│   DB    │
│ Pods          │      │  Pool        │      │ Primary │
└───────────────┘      └──────────────┘      └─────────┘
                                                   │
                                              ┌─────────┐
                                              │   DB    │
                                              │ Replica │
                                              └─────────┘
```

| SLI | Specification | Target | Measurement |
|-----|---------------|--------|-------------|
| Availability | Proportion of successful DB connections | 99.95% | Connection pool success rate |
| Query Latency | Proportion of queries completing in < 100ms | 95% | Query duration histogram |
| Replication Lag | Proportion of time replica is < 1s behind primary | 99.9% | `pg_replication_lag` or equivalent |
| Connection Saturation | Proportion of time connection pool is < 80% full | 99% | Pool usage / pool max |

**Key considerations:**
- Measure from the **application's perspective** (connection pool), not just the DB server
- Track slow queries separately from normal queries
- Replication lag is a **freshness SLI** for read replicas
- Connection pool exhaustion is a leading indicator of outages

### Message Queue SLIs

Message queues (Kafka, RabbitMQ, NATS) are the backbone of async communication.

```
┌──────────┐      ┌─────────────┐      ┌──────────┐
│ Producer │─────▶│   Queue     │─────▶│ Consumer │
│ Service  │      │ (Kafka/     │      │ Service  │
└──────────┘      │  RabbitMQ)  │      └──────────┘
                  └─────────────┘
                        │
                  Measure:
                  - Publish success rate
                  - Consumer lag
                  - End-to-end latency
```

| SLI | Specification | Target | Measurement |
|-----|---------------|--------|-------------|
| Publish Availability | Proportion of messages successfully published | 99.95% | Producer success/total ratio |
| Consumer Lag | Proportion of time consumer lag is < 1000 messages | 99% | Consumer group lag metrics |
| End-to-End Latency | Proportion of messages consumed within 5s of production | 95% | Timestamp comparison |
| Message Durability | Proportion of published messages that are consumable | 99.999% | Audit/reconciliation |

**Key considerations:**
- Consumer lag is a **freshness SLI** — how stale is the data?
- Distinguish between "queue is slow" and "consumer is slow"
- Dead letter queues (DLQ) represent **correctness failures**
- Measure end-to-end, not just individual hops

---

## Prometheus/PromQL Examples

Real, copy-pasteable PromQL queries for each SLI type. These assume standard metric naming conventions from common Kubernetes exporters.

### Availability SLI

**Specification:** "Proportion of HTTP requests that do not result in a server error"

```promql
# Availability over the last 30 days (for SLO tracking)
sum(rate(http_requests_total{code!~"5.."}[30d]))
/
sum(rate(http_requests_total[30d]))
```

```promql
# Availability over a 5-minute window (for alerting)
sum(rate(http_requests_total{code!~"5.."}[5m]))
/
sum(rate(http_requests_total[5m]))
```

```promql
# Per-service availability (useful for dashboards)
sum by (service) (rate(http_requests_total{code!~"5.."}[5m]))
/
sum by (service) (rate(http_requests_total[5m]))
```

### Latency SLI

**Specification:** "Proportion of requests served faster than 300ms"

```promql
# Using histogram_quantile for P99 latency
histogram_quantile(0.99,
  sum by (le) (rate(http_request_duration_seconds_bucket[5m]))
)
```

```promql
# Proportion of requests under 300ms (SLI as a ratio)
# This uses the histogram bucket for <= 0.3 seconds
sum(rate(http_request_duration_seconds_bucket{le="0.3"}[5m]))
/
sum(rate(http_request_duration_seconds_count[5m]))
```

```promql
# Multi-threshold latency SLI (P50 < 100ms AND P99 < 1s)
# P50
histogram_quantile(0.50,
  sum by (le) (rate(http_request_duration_seconds_bucket[5m]))
)

# P99
histogram_quantile(0.99,
  sum by (le) (rate(http_request_duration_seconds_bucket[5m]))
)
```

```promql
# Latency SLI excluding errors (important!)
sum(rate(http_request_duration_seconds_bucket{le="0.3", code!~"5.."}[5m]))
/
sum(rate(http_request_duration_seconds_count{code!~"5.."}[5m]))
```

### Throughput SLI

**Specification:** "Requests processed per second"

```promql
# Current throughput (requests per second)
sum(rate(http_requests_total[5m]))
```

```promql
# Throughput by service and method
sum by (service, method) (rate(http_requests_total[5m]))
```

```promql
# Throughput SLI as success ratio under load
# "Of all requests received, what proportion were successfully handled?"
sum(rate(http_requests_total{code=~"2.."}[5m]))
/
sum(rate(http_requests_total[5m]))
```

### Saturation SLI

**Specification:** "Proportion of time resources are below critical thresholds"

```promql
# CPU saturation (proportion of pods above 80% CPU)
count(
  (rate(container_cpu_usage_seconds_total{namespace="production"}[5m])
  /
  kube_pod_container_resource_limits{resource="cpu", namespace="production"})
  > 0.8
)
/
count(kube_pod_container_resource_limits{resource="cpu", namespace="production"})
```

```promql
# Memory saturation
container_memory_working_set_bytes{namespace="production"}
/
kube_pod_container_resource_limits{resource="memory", namespace="production"}
```

```promql
# Connection pool saturation (example with HikariCP)
hikaricp_connections_active
/
hikaricp_connections_max
```

### Database SLIs

```promql
# PostgreSQL query latency (using pg_stat_statements)
rate(pg_stat_statements_total_time_seconds[5m])
/
rate(pg_stat_statements_calls_total[5m])
```

```promql
# PostgreSQL replication lag (freshness SLI)
pg_replication_lag_seconds
```

```promql
# Redis availability (command success rate)
sum(rate(redis_commands_processed_total[5m]))
/
(sum(rate(redis_commands_processed_total[5m])) + sum(rate(redis_rejected_connections_total[5m])))
```

### Message Queue SLIs

```promql
# Kafka consumer lag (freshness SLI)
kafka_consumergroup_lag_sum{consumergroup="my-consumer-group"}
```

```promql
# Kafka consumer lag as a ratio SLI
# "Proportion of time consumer lag is below 1000"
(kafka_consumergroup_lag_sum{consumergroup="my-group"} < 1000) or vector(0)
```

```promql
# RabbitMQ message publish success rate
sum(rate(rabbitmq_channel_messages_published_total[5m]))
/
(sum(rate(rabbitmq_channel_messages_published_total[5m]))
 + sum(rate(rabbitmq_channel_messages_returned_total[5m])))
```

### Kubernetes Platform SLIs

```promql
# Pod availability (proportion of desired pods that are running)
sum by (namespace, deployment) (kube_deployment_status_replicas_available)
/
sum by (namespace, deployment) (kube_deployment_spec_replicas)
```

```promql
# Pod startup latency (time from scheduled to running)
histogram_quantile(0.99,
  sum by (le) (rate(kubelet_pod_start_duration_seconds_bucket[1h]))
)
```

```promql
# API server availability
sum(rate(apiserver_request_total{code!~"5.."}[5m]))
/
sum(rate(apiserver_request_total[5m]))
```

```promql
# API server latency P99
histogram_quantile(0.99,
  sum by (le, resource, verb) (
    rate(apiserver_request_duration_seconds_bucket{verb!="WATCH"}[5m])
  )
)
```

### Composite SLI Example

Sometimes you need to combine multiple signals into one SLI:

```promql
# Combined "request quality" SLI
# A request is "good" if it: succeeded (non-5xx) AND was fast (< 300ms)
sum(rate(http_request_duration_seconds_bucket{le="0.3", code!~"5.."}[5m]))
/
sum(rate(http_request_duration_seconds_count[5m]))
```

---

## Best Practices

### Do ✅

| Practice | Why |
|----------|-----|
| **Measure from the user's perspective** | A healthy server that users can't reach is still broken |
| **Use ratios (good/total)** | Makes it easy to set targets and compare across services |
| **Start simple** | 1-2 well-chosen SLIs beat 20 poorly maintained ones |
| **Separate SLI spec from implementation** | Survive infrastructure changes without re-negotiating SLOs |
| **Exclude irrelevant traffic** | Health checks, internal probes, and bots skew your measurements |
| **Use histograms for latency** | Averages lie. Percentiles tell the truth |
| **Document your SLIs** | Future-you and your teammates will thank you |
| **Review SLIs quarterly** | Services evolve; SLIs should too |
| **Align SLIs with user journeys** | Measure what users actually experience end-to-end |
| **Use consistent time windows** | Compare apples to apples (e.g., always use 28-day rolling) |

### Don't ❌

| Anti-Pattern | Why It's Wrong |
|-------------|----------------|
| **Using averages for latency** | Average of [1ms, 1ms, 1ms, 1000ms] = 250ms — hides the suffering |
| **Measuring internal metrics as SLIs** | CPU usage is not an SLI — user impact is |
| **Too many SLIs** | If everything is important, nothing is. Aim for 3-5 per service |
| **SLIs without SLOs** | A measurement without a target is just noise |
| **Including synthetic/health check traffic** | Inflates your numbers artificially |
| **Ignoring error types** | Not all 5xx errors are equal (retry-able vs. data loss) |
| **Setting SLIs once and forgetting** | User expectations and system behavior change |
| **Measuring only availability** | A service can be "up" but unusably slow |

### Choosing the Right SLIs: Decision Framework

```
┌─────────────────────────────────────────────────────┐
│            "What do my users care about?"            │
└───────────────────────┬─────────────────────────────┘
                        │
            ┌───────────┼───────────┐
            ▼           ▼           ▼
     ┌────────────┐ ┌────────┐ ┌──────────┐
     │ "Can I     │ │ "Is it │ │ "Is it   │
     │  reach it?"│ │  fast?"│ │  correct?"│
     └─────┬──────┘ └───┬────┘ └────┬─────┘
           ▼             ▼           ▼
     Availability    Latency    Correctness
           │             │           │
           ▼             ▼           ▼
     ┌──────────────────────────────────────┐
     │  Secondary concerns:                  │
     │  • Freshness (cached/async systems)   │
     │  • Durability (storage systems)       │
     │  • Throughput (batch systems)         │
     └──────────────────────────────────────┘
```

---

## Common Mistakes

### 1. Measuring What's Easy Instead of What Matters

**Wrong:** "We'll use CPU utilization as our SLI because it's already in our dashboard."

**Right:** "We'll measure the proportion of API calls that complete successfully and quickly."

CPU is an implementation detail. Users don't care about your CPU — they care about their requests.

### 2. The "Everything is Fine" Problem

**Scenario:** Your SLI shows 99.99% availability, but users are complaining.

**Root cause:** You're measuring at the wrong point. Your server responds fast with cached 200s, but the data is 3 hours stale.

**Fix:** Add a **freshness SLI** alongside availability.

### 3. Averaging Across Heterogeneous Traffic

**Wrong:**
```promql
# This averages tiny health checks with expensive report generation
avg(rate(http_request_duration_seconds_sum[5m]))
```

**Right:**
```promql
# Separate by endpoint type
histogram_quantile(0.99,
  sum by (le) (rate(http_request_duration_seconds_bucket{handler!~"/health.*"}[5m]))
)
```

### 4. Not Accounting for "Silent Failures"

Some failures don't produce errors:
- API returns HTTP 200 with empty body
- Search returns results but they're from a stale index
- Payment succeeds but charges the wrong amount

**Fix:** Implement correctness probes that validate response content, not just status codes.

### 5. Using Instantaneous Values Instead of Ratios Over Time

**Wrong:**
```promql
# Point-in-time snapshot — misleading
http_requests_total{code="500"} > 0  # "We have errors!"
```

**Right:**
```promql
# Rate over time — meaningful
sum(rate(http_requests_total{code=~"5.."}[5m]))
/
sum(rate(http_requests_total[5m]))
> 0.001  # Error rate exceeds 0.1%
```

### 6. Confusing SLI With Alerting Threshold

```
SLI ≠ Alert

SLI: "99.3% of requests are successful" (a measurement)
Alert: "Error budget burn rate exceeds 10x" (a trigger)
```

Your SLI is a continuous measurement. Alerts fire based on **how fast you're burning error budget**, not on the raw SLI value.

### 7. Not Segmenting by User Impact

**Scenario:** Your overall availability is 99.95%, but:
- Free tier users: 99.99% (low traffic, simple endpoints)
- Enterprise users: 99.5% (high traffic, complex queries)

The overall number hides that your most valuable customers are suffering.

**Fix:** Segment SLIs by customer tier, endpoint criticality, or geographic region.

### 8. Setting Aspirational Targets Without Data

**Wrong:** "Let's set our availability SLO to 99.99% because that sounds good."

**Right process:**
1. Measure your current SLI for 2-4 weeks
2. Understand your baseline (e.g., you're currently at 99.7%)
3. Set a realistic target slightly above baseline (e.g., 99.8%)
4. Improve iteratively

### 9. Ignoring Dependencies

Your service's SLI is bounded by your dependencies:

```
If your database has 99.9% availability
AND your cache has 99.9% availability
AND your auth service has 99.9% availability

Your service CANNOT exceed ~99.7% availability
(assuming serial dependencies)

Formula: 0.999 × 0.999 × 0.999 = 0.997
```

**Fix:** Map critical dependencies and ensure your SLO accounts for their reliability.

### 10. Not Communicating SLI Changes

When you change how an SLI is measured (new metric source, different threshold, etc.):
- Document the change and reason
- Note the effective date
- Expect a discontinuity in graphs
- Re-baseline your error budget

---

## Summary Cheat Sheet

```
┌─────────────────────────────────────────────────────────────┐
│                   SLI CHEAT SHEET                            │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Formula:    SLI = Good Events / Total Events               │
│  Range:      Always 0% to 100%                              │
│  Goal:       Measure USER experience, not system internals  │
│                                                             │
│  Start with:                                                │
│    1. Availability (can users reach it?)                    │
│    2. Latency (is it fast enough?)                          │
│    3. Correctness (is it right?)                            │
│                                                             │
│  Measure at:                                                │
│    • Closest point to the user                              │
│    • Multiple points for validation                         │
│                                                             │
│  Remember:                                                  │
│    • Fewer SLIs, better maintained > many SLIs, neglected   │
│    • SLI ≠ SLO ≠ Alert                                     │
│    • Measure first, set targets based on data               │
│    • Review and evolve quarterly                            │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## Further Reading

- [Google SRE Book — Chapter 4: Service Level Objectives](https://sre.google/sre-book/service-level-objectives/)
- [Google SRE Workbook — Chapter 2: Implementing SLOs](https://sre.google/workbook/implementing-slos/)
- [The Art of SLOs (Google Cloud)](https://cloud.google.com/blog/products/management-tools/practical-guide-to-setting-slos)
- [OpenSLO Specification](https://openslo.com/)
- [Prometheus Histogram Best Practices](https://prometheus.io/docs/practices/histograms/)
