# SLO Guide — kube-sre-stack

> A practical guide to Service Level Objectives for the SRE team.
> Covers theory, implementation, alerting, and decision-making.

---

## Table of Contents

1. [What is an SLO?](#what-is-an-slo)
2. [Why SLOs Matter](#why-slos-matter)
3. [Anatomy of an SLO](#anatomy-of-an-slo)
4. [How to Set SLO Targets](#how-to-set-slo-targets)
5. [Error Budgets](#error-budgets)
6. [SLO Windows](#slo-windows)
7. [Multi-Window Multi-Burn-Rate (MWMBR) Alerting](#multi-window-multi-burn-rate-mwmbr-alerting)
8. [Real-World SLO Examples for kube-sre-stack](#real-world-slo-examples-for-kube-sre-stack)
9. [SLO-Based Decision Making](#slo-based-decision-making)
10. [Prometheus Recording Rules & Alert Rules](#prometheus-recording-rules--alert-rules)
11. [Grafana SLO Dashboard Design](#grafana-slo-dashboard-design)
12. [Common Mistakes and Anti-Patterns](#common-mistakes-and-anti-patterns)

---

## What is an SLO?

An **SLO (Service Level Objective)** is a target value or range for a service level that is measured by a Service Level Indicator (SLI). In plain English:

> "We promise that our API will successfully respond to 99.9% of all requests measured over a 30-day rolling window."

That sentence *is* an SLO.

### The SLI → SLO → SLA Chain

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│   SLI (Service Level Indicator)                         │
│   ─────────────────────────────                         │
│   A quantitative measure of some aspect of the service. │
│   Example: "The ratio of successful HTTP requests       │
│             to total HTTP requests."                    │
│                                                         │
│         ▼                                               │
│                                                         │
│   SLO (Service Level Objective)                         │
│   ─────────────────────────────                         │
│   A target for an SLI over a time window.               │
│   Example: "99.9% of requests succeed over 30 days."   │
│                                                         │
│         ▼                                               │
│                                                         │
│   SLA (Service Level Agreement)                         │
│   ─────────────────────────────                         │
│   A contract with consequences if the SLO is missed.    │
│   Example: "If availability < 99.9%, customer gets      │
│             10% credit."                                │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### Key Principles

- **SLIs are the measurement** — what you observe (latency, error rate, throughput).
- **SLOs are the goal** — what "good enough" looks like for users.
- **SLAs are the contract** — what happens (financially, legally) if you fail.

Most internal services have SLOs but no formal SLA. The SLO is your internal reliability contract with your users (other teams, customers, etc.).

---

## Why SLOs Matter

### Balancing Reliability vs. Velocity

Without SLOs, teams face a tug-of-war:

```
  Developers want to ship fast ──────────────────► SREs want stability
          "Move fast"                              "Don't break things"
```

SLOs resolve this by making reliability a **measurable, shared goal**:

- If the error budget is healthy → ship features, take risks.
- If the error budget is burning → slow down, fix reliability.

### Cultural Impact

| Without SLOs | With SLOs |
|---|---|
| "Is the service reliable enough?" → subjective debate | "We have 45% error budget remaining" → data-driven |
| Reliability is someone else's problem | Reliability is a shared metric |
| Outages trigger blame | Outages consume budget — that's expected |
| Teams over-invest in reliability (gold-plating) | Teams invest the right amount |
| "We need five 9s" without understanding the cost | Each 9 has a quantified cost in engineering effort |

### The Fundamental Insight

> **100% is the wrong reliability target for virtually everything.**

Why? Because:
- Users don't notice the difference between 99.99% and 100%.
- The cost of each additional "9" grows exponentially.
- There are always other points of failure (ISP, DNS, client device).

SLOs give you permission to be imperfect — intentionally, measurably, and strategically.

---

## Anatomy of an SLO

Every SLO has three components:

```
┌────────────────────────────────────────────────┐
│                                                │
│   SLO  =  SLI  +  Target  +  Window           │
│                                                │
│   ┌─────────┐  ┌──────────┐  ┌─────────────┐  │
│   │  What   │  │ How much │  │  Over what  │  │
│   │  you    │  │  of it   │  │   period    │  │
│   │ measure │  │  is good │  │   of time   │  │
│   └─────────┘  └──────────┘  └─────────────┘  │
│                                                │
│   Example:                                     │
│   "The proportion of HTTP requests that        │
│    return 2xx (SLI) should be ≥ 99.9%          │
│    (Target) over a 30-day rolling window       │
│    (Window)."                                  │
│                                                │
└────────────────────────────────────────────────┘
```

### Component Breakdown

| Component | Description | Example |
|-----------|-------------|---------|
| **SLI** | The metric being measured | `successful_requests / total_requests` |
| **Target** | The threshold of acceptable performance | `>= 99.9%` |
| **Window** | The time period over which it is measured | `30-day rolling` |

### Types of SLIs

| SLI Type | What It Measures | Formula |
|----------|-----------------|---------|
| **Availability** | Did the request succeed? | `(total - errors) / total` |
| **Latency** | Was it fast enough? | `requests < threshold / total` |
| **Quality** | Was the response complete? | `full_responses / total_responses` |
| **Freshness** | Is data up to date? | `fresh_records / total_records` |
| **Throughput** | Can we handle the load? | `served_requests / offered_requests` |

---

## How to Set SLO Targets

### The Art of Choosing Targets

The right target depends on:

1. **User expectations** — What do your users actually need?
2. **Dependencies** — You can't be more reliable than your least reliable dependency.
3. **Cost** — Each additional "9" costs roughly 10x more engineering effort.
4. **Business impact** — What's the cost of downtime to the business?

### What Each Target Means in Practice

```
  99%    ──── "We're okay with 7+ hours of downtime per month"
               Good for: internal tools, batch jobs, dev environments

  99.9%  ──── "We can tolerate ~43 minutes of downtime per month"
               Good for: most production services, APIs

  99.95% ──── "Only ~22 minutes of downtime per month"
               Good for: critical customer-facing services

  99.99% ──── "Only ~4.3 minutes per month"
               Good for: payment systems, auth services, databases
```

### Decision Framework

Ask these questions:

1. **What happens if this service is down for 1 hour?**
   - Nobody notices → 99% is fine
   - Internal users are blocked → 99.9%
   - Customers lose money → 99.95%+
   - Safety/security impact → 99.99%+

2. **What are our dependencies' SLOs?**
   - If your database is 99.95%, your service can't promise 99.99%.
   - Rule of thumb: your SLO ≤ weakest dependency's SLO.

3. **Can we achieve this target with current architecture?**
   - Single replica? Probably can't exceed 99.9%.
   - Multi-AZ with failover? 99.95% - 99.99% is realistic.

### Starting Point Recommendation

> **Start with 99.9% for most services.** Tighten only if users demand it and you can afford the engineering investment.

---

## Error Budgets

### What Is an Error Budget?

An error budget is the **inverse of your SLO** — the amount of unreliability you're allowed.

```
  Error Budget = 1 - SLO Target

  If SLO = 99.9%, then Error Budget = 0.1%
  Over 30 days = 0.1% × 30 × 24 × 60 = 43.2 minutes of allowed downtime
```

### Error Budget Downtime Table

| SLO Target | Error Budget | Downtime/Month | Downtime/Quarter | Downtime/Year |
|------------|-------------|----------------|------------------|---------------|
| 99% | 1% | 7h 18m | 21h 54m | 3d 15h 36m |
| 99.5% | 0.5% | 3h 39m | 10h 57m | 1d 19h 48m |
| 99.9% | 0.1% | 43m 50s | 2h 11m 30s | 8h 45m 58s |
| 99.95% | 0.05% | 21m 55s | 1h 5m 45s | 4h 22m 59s |
| 99.99% | 0.01% | 4m 23s | 13m 9s | 52m 36s |
| 99.999% | 0.001% | 26s | 1m 19s | 5m 16s |

### How to Calculate Error Budget Consumption

```
Budget Consumed (%) = (Bad Minutes in Window / Total Allowed Bad Minutes) × 100

Example:
  - SLO: 99.9% over 30 days
  - Allowed bad minutes: 43.2
  - Actual bad minutes so far: 20
  - Budget consumed: (20 / 43.2) × 100 = 46.3%
  - Budget remaining: 53.7%
```

### What To Do When Budget Is Exhausted

When error budget reaches 0% (or approaches it):

| Budget Remaining | Action |
|-----------------|--------|
| > 50% | Ship features freely, experiment |
| 25% – 50% | Proceed with caution, prioritize reliability fixes |
| 10% – 25% | Freeze risky deployments, focus on stability |
| < 10% | **Deploy freeze.** All effort goes to reliability |
| 0% (exhausted) | Full freeze. Post-mortem required. Leadership review |

### Error Budget Policy (Template)

```
When error budget is exhausted:
1. Feature development pauses for the affected service.
2. The team focuses exclusively on reliability improvements.
3. A post-mortem review identifies top contributors to budget burn.
4. Normal development resumes only when budget recovers to 25%.
5. If budget is exhausted 2+ times in a quarter, architectural review is triggered.
```

---

## SLO Windows

### Rolling Window vs. Calendar Window

| Aspect | Rolling Window | Calendar Window |
|--------|---------------|-----------------|
| **Definition** | "The last N days from right now" | "This calendar month" |
| **Resets** | Never — slides continuously | Resets at month/quarter boundary |
| **Pros** | No "fresh start" gaming; always reflects recent reality | Aligns with business reporting cycles |
| **Cons** | A bad day haunts you for the full window | Teams can "burn budget" early and coast |
| **Best for** | Operational alerting, engineering decisions | Business reporting, SLA tracking |

### Visual Comparison

```
Rolling 30-day window (evaluated on July 23):
├──────────────────────────────────────────┤
June 23                                  July 23
         ◄─── always looking back 30 days ───►

Calendar month window:
├──────────────────────────────────────────┤
July 1                                   July 31
         ◄─── resets on Aug 1 ───►
```

### Choosing Window Length

| Window | Use Case |
|--------|----------|
| **7-day rolling** | Fast feedback for rapidly changing services. Good for alerting. |
| **30-day rolling** | Standard SLO window. Balances noise reduction with responsiveness. |
| **90-day rolling** | Strategic view. Useful for quarterly planning and SLA alignment. |

### Recommendation for kube-sre-stack

- **Alerting**: Use 7-day and 30-day rolling windows (multi-window alerting).
- **Reporting**: Use 30-day rolling as the primary SLO window.
- **Business reviews**: Use 90-day calendar quarters for trend analysis.


---

## Multi-Window Multi-Burn-Rate (MWMBR) Alerting

### The Problem with Naive SLO Alerting

If you alert when SLO < target, you get alerted **after** the budget is gone. Too late.
If you alert on instantaneous error rate, you get flooded with noise. Too noisy.

**MWMBR alerting** solves both problems by detecting when you're burning error budget **faster than sustainable**.

### What Is a Burn Rate?

Burn rate is how fast you're consuming error budget relative to the steady-state rate.

```
Burn Rate = Actual Error Rate / Maximum Allowed Error Rate

Maximum Allowed Error Rate = 1 - SLO Target
                           = 1 - 0.999
                           = 0.001 (for 99.9% SLO)

If actual error rate = 0.01 (1% errors):
  Burn Rate = 0.01 / 0.001 = 10x

Meaning: you're burning budget 10x faster than sustainable.
At this rate, your 30-day budget will be gone in 3 days.
```

### Burn Rate Reference

```
Burn Rate 1x  → Budget lasts exactly the full window (30 days)
Burn Rate 2x  → Budget gone in 15 days
Burn Rate 10x → Budget gone in 3 days
Burn Rate 14x → Budget gone in ~2 days
Burn Rate 36x → Budget gone in 20 hours
Burn Rate 720x→ Budget gone in 1 hour (total outage)
```

### Multi-Window: Why Two Windows?

A single burn-rate check can give false positives. We use **two windows** per alert:

- **Long window**: Confirms the burn is sustained (not a blip).
- **Short window**: Confirms the burn is still happening *right now*.

Both conditions must be true to fire the alert.

### The MWMBR Strategy

```
┌─────────────────────────────────────────────────────────────────────┐
│                   MWMBR Alert Configuration                          │
├──────────┬───────────┬──────────────┬──────────────┬────────────────┤
│ Severity │ Burn Rate │ Long Window  │ Short Window │ Budget Consumed│
├──────────┼───────────┼──────────────┼──────────────┼────────────────┤
│ Critical │    14.4x  │    1 hour    │   5 minutes  │   2% in 1h     │
│ Critical │     6x    │    6 hours   │  30 minutes  │   5% in 6h     │
│ Warning  │     3x    │   1 day      │   2 hours    │  10% in 1d     │
│ Warning  │     1x    │   3 days     │   6 hours    │  10% in 3d     │
└──────────┴───────────┴──────────────┴──────────────┴────────────────┘
```

### ASCII Diagram: Burn Rate Visualization

```
Error Budget Remaining (%)
100% ┤
     │╲
     │ ╲  ← Burn Rate 14.4x (Critical — budget gone in ~2 days)
 90% ┤  ╲
     │   ╲
 80% ┤    ╲
     │     ╲
 70% ┤      ╲
     │       ╲
 60% ┤        ╲
     │     ╲   ╲
 50% ┤      ╲   ╲← Burn Rate 6x (Critical — budget gone in ~5 days)
     │       ╲   ╲
 40% ┤        ╲   ╲
     │         ╲   ╲
 30% ┤      ────╲───╲──── Burn Rate 3x (Warning — budget gone in 10 days)
     │           ╲   ╲
 20% ┤            ╲   ╲
     │     ─────────────────── Burn Rate 1x (Ticket — budget gone in 30 days)
 10% ┤                    ╲
     │                     ╲
  0% ┤─────────────────────────────────────────────────
     └──┬──┬──┬──┬──┬──┬──┬──┬──┬──┬──┬──┬──┬──┬──┬──
        1  2  3  4  5  6  7  8  9 10    15    20    30  Days
```

### Fast Burn vs. Slow Burn

| Aspect | Fast Burn | Slow Burn |
|--------|-----------|-----------|
| **What** | High error rate for a short time | Low error rate sustained over days |
| **Example** | Total outage for 5 minutes | 0.5% error rate for a week |
| **Burn Rate** | 14x – 720x | 1x – 6x |
| **Detection** | 1h / 5min windows | 1d–3d / 2h–6h windows |
| **Severity** | Critical (page immediately) | Warning (ticket, next business day) |
| **Response** | Incident response, all hands | Investigate, plan fix |
| **Typical Cause** | Bad deploy, infrastructure failure | Memory leak, capacity degradation |

### Why This Works

```
Traditional alerting:                    MWMBR alerting:
─────────────────────                    ───────────────────
"Error rate > 1%"                        "Budget burning 14x faster than
 → Fires on every blip                   sustainable AND confirmed over
 → Alert fatigue                          1 hour AND still happening now"
 → No connection to user impact           → Low noise
                                          → Direct connection to SLO impact
                                          → Actionable severity levels
```


---

## Real-World SLO Examples for kube-sre-stack

### 1. API Availability SLO

```yaml
# SLO Definition
name: api-availability
service: kube-sre-stack-api
sli:
  type: availability
  description: "Proportion of HTTP requests that do not return 5xx"
  good_events: "HTTP requests with status < 500"
  total_events: "All HTTP requests (excluding health checks)"
  formula: |
    sum(rate(http_requests_total{job="kube-sre-api", code!~"5.."}[5m]))
    /
    sum(rate(http_requests_total{job="kube-sre-api"}[5m]))
target: 99.9%
window: 30-day rolling
error_budget: 43.2 minutes/month
owner: platform-team
escalation: "#sre-incidents"
```

**PromQL for this SLI:**

```promql
# Instant availability (last 5 minutes)
sum(rate(http_requests_total{job="kube-sre-api", code!~"5.."}[5m]))
/
sum(rate(http_requests_total{job="kube-sre-api"}[5m]))

# 30-day availability
sum(increase(http_requests_total{job="kube-sre-api", code!~"5.."}[30d]))
/
sum(increase(http_requests_total{job="kube-sre-api"}[30d]))
```

---

### 2. Latency SLO (p99 < 500ms)

```yaml
# SLO Definition
name: api-latency-p99
service: kube-sre-stack-api
sli:
  type: latency
  description: "Proportion of requests served in under 500ms"
  good_events: "HTTP requests with duration < 500ms"
  total_events: "All HTTP requests"
  formula: |
    sum(rate(http_request_duration_seconds_bucket{job="kube-sre-api", le="0.5"}[5m]))
    /
    sum(rate(http_request_duration_seconds_count{job="kube-sre-api"}[5m]))
target: 99.0%
window: 30-day rolling
error_budget: 7h 18m/month (1% of requests can be slow)
owner: platform-team
escalation: "#sre-incidents"
```

**PromQL for this SLI:**

```promql
# Proportion of requests under 500ms (instant)
sum(rate(http_request_duration_seconds_bucket{job="kube-sre-api", le="0.5"}[5m]))
/
sum(rate(http_request_duration_seconds_count{job="kube-sre-api"}[5m]))

# 30-day latency SLI
sum(increase(http_request_duration_seconds_bucket{job="kube-sre-api", le="0.5"}[30d]))
/
sum(increase(http_request_duration_seconds_count{job="kube-sre-api"}[30d]))
```

**Why p99 and not average?**

```
Latency distribution (typical API):

  Count
   │
   │█
   │██
   │███
   │████
   │█████
   │██████
   │████████
   │██████████
   │██████████████
   │█████████████████████                          ███  ← these are your p99
   └─────────────────────────────────────────────────────── Duration
   0ms   50ms  100ms  200ms  300ms  500ms  1s   2s   5s

Average latency = 120ms (looks great!)
p99 latency = 2.1s (users are suffering!)
```

---

### 3. Deployment Success Rate SLO

```yaml
# SLO Definition
name: deployment-success-rate
service: kube-sre-stack (platform)
sli:
  type: quality
  description: "Proportion of deployments that complete without rollback"
  good_events: "Deployments that complete successfully"
  total_events: "All deployment attempts"
  formula: |
    sum(deployment_status_total{status="success"})
    /
    sum(deployment_status_total)
target: 95%
window: 30-day rolling
error_budget: 5% of deploys can fail
  # If you deploy 20 times/month, 1 failure is within budget
owner: platform-team
escalation: "#deploy-failures"
```

**PromQL for this SLI:**

```promql
# Deployment success rate (last 30 days)
sum(increase(deployment_status_total{status="success"}[30d]))
/
sum(increase(deployment_status_total[30d]))
```

### Summary Table

| SLO | SLI | Target | Window | Error Budget |
|-----|-----|--------|--------|--------------|
| API Availability | Non-5xx responses / total | 99.9% | 30-day rolling | 43.2 min |
| API Latency | Requests < 500ms / total | 99.0% | 30-day rolling | 1% of requests |
| Deploy Success | Successful deploys / total | 95.0% | 30-day rolling | 5% of deploys |


---

## SLO-Based Decision Making

### The Error Budget Decision Framework

```
┌─────────────────────────────────────────────────────────────────────┐
│                                                                     │
│   Error Budget Remaining    →    Action                             │
│                                                                     │
│   ████████████████████ 75-100%   Ship freely. Experiment. Take      │
│                                  risks. This is innovation time.    │
│                                                                     │
│   ██████████████░░░░░░ 50-75%    Normal operations. Ship with       │
│                                  standard review processes.         │
│                                                                     │
│   ████████░░░░░░░░░░░░ 25-50%    Caution. Extra review on risky     │
│                                  changes. Prioritize reliability    │
│                                  work in sprint planning.           │
│                                                                     │
│   ████░░░░░░░░░░░░░░░░ 10-25%    Deploy freeze for risky changes.   │
│                                  Only ship reliability fixes and    │
│                                  critical bug fixes.                │
│                                                                     │
│   █░░░░░░░░░░░░░░░░░░░  0-10%    Full freeze. All hands on          │
│                                  reliability. Incident review.      │
│                                  Leadership escalation.             │
│                                                                     │
│   ░░░░░░░░░░░░░░░░░░░░   0%     Budget exhausted. Stop everything. │
│                                  Post-mortem. Architectural review. │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### When to Freeze Deployments

Trigger a deploy freeze when:

- Error budget remaining < 25% **AND** trending downward.
- A single incident consumed > 30% of the monthly budget.
- Two or more SLOs are simultaneously in the "caution" zone.

**What "freeze" means:**

- No feature deployments to the affected service.
- Config changes require SRE approval.
- Reliability fixes and rollbacks are still allowed (and encouraged).
- Freeze lifts when budget recovers to 25%+ or root cause is resolved.

### When to Invest in Reliability

Use error budget trends to justify reliability investment:

| Signal | Investment |
|--------|-----------|
| Budget exhausted 2+ months in a row | Major architectural work needed |
| Budget consistently < 50% | Add redundancy, improve observability |
| Single component dominates budget burn | Targeted hardening of that component |
| Budget healthy for 6+ months | Over-invested? Loosen SLO or reduce infra |

### SLO-Driven Prioritization

```
Sprint Planning with SLOs:

1. Check error budget status for each service.
2. Services with budget < 50%:
   - At least 30% of sprint capacity goes to reliability.
3. Services with budget < 25%:
   - 100% of sprint capacity goes to reliability.
4. Services with budget > 75%:
   - Full speed on features. Experiment freely.
5. Review at every sprint retrospective.
```

### Trade-off Conversations

SLOs enable concrete trade-off discussions:

- **PM**: "Can we ship this risky migration next week?"
- **SRE**: "Our budget is at 35%. If the migration causes 15 minutes of downtime, we'll be at 1%. I recommend waiting until budget recovers, or doing it in smaller phases."

This replaces subjective "it feels risky" with quantified risk.


---

## Prometheus Recording Rules & Alert Rules

### Recording Rules

Recording rules pre-compute expensive SLI queries so dashboards and alerts are fast.

```yaml
# File: prometheus/rules/slo-recording-rules.yaml
groups:
  - name: slo.rules
    interval: 30s
    rules:
      # ─── API Availability SLI ───────────────────────────────────────
      # Error ratio over multiple windows for MWMBR alerting
      - record: slo:http_request_error_ratio:rate5m
        expr: |
          sum(rate(http_requests_total{job="kube-sre-api", code=~"5.."}[5m]))
          /
          sum(rate(http_requests_total{job="kube-sre-api"}[5m]))

      - record: slo:http_request_error_ratio:rate30m
        expr: |
          sum(rate(http_requests_total{job="kube-sre-api", code=~"5.."}[30m]))
          /
          sum(rate(http_requests_total{job="kube-sre-api"}[30m]))

      - record: slo:http_request_error_ratio:rate1h
        expr: |
          sum(rate(http_requests_total{job="kube-sre-api", code=~"5.."}[1h]))
          /
          sum(rate(http_requests_total{job="kube-sre-api"}[1h]))

      - record: slo:http_request_error_ratio:rate6h
        expr: |
          sum(rate(http_requests_total{job="kube-sre-api", code=~"5.."}[6h]))
          /
          sum(rate(http_requests_total{job="kube-sre-api"}[6h]))

      - record: slo:http_request_error_ratio:rate1d
        expr: |
          sum(rate(http_requests_total{job="kube-sre-api", code=~"5.."}[1d]))
          /
          sum(rate(http_requests_total{job="kube-sre-api"}[1d]))

      - record: slo:http_request_error_ratio:rate3d
        expr: |
          sum(rate(http_requests_total{job="kube-sre-api", code=~"5.."}[3d]))
          /
          sum(rate(http_requests_total{job="kube-sre-api"}[3d]))

      # ─── 30-Day Availability (for dashboards) ──────────────────────
      - record: slo:http_request_availability:ratio30d
        expr: |
          1 - (
            sum(increase(http_requests_total{job="kube-sre-api", code=~"5.."}[30d]))
            /
            sum(increase(http_requests_total{job="kube-sre-api"}[30d]))
          )

      # ─── Error Budget Remaining ────────────────────────────────────
      - record: slo:error_budget_remaining:ratio
        expr: |
          1 - (
            (1 - slo:http_request_availability:ratio30d)
            /
            (1 - 0.999)
          )
        labels:
          slo: "api-availability"
          target: "99.9"

      # ─── Latency SLI ───────────────────────────────────────────────
      - record: slo:http_request_latency_good:rate5m
        expr: |
          sum(rate(http_request_duration_seconds_bucket{job="kube-sre-api", le="0.5"}[5m]))
          /
          sum(rate(http_request_duration_seconds_count{job="kube-sre-api"}[5m]))

      - record: slo:http_request_latency_good:rate1h
        expr: |
          sum(rate(http_request_duration_seconds_bucket{job="kube-sre-api", le="0.5"}[1h]))
          /
          sum(rate(http_request_duration_seconds_count{job="kube-sre-api"}[1h]))

      - record: slo:http_request_latency_good:rate30d
        expr: |
          sum(increase(http_request_duration_seconds_bucket{job="kube-sre-api", le="0.5"}[30d]))
          /
          sum(increase(http_request_duration_seconds_count{job="kube-sre-api"}[30d]))
```

### Alert Rules (MWMBR)

```yaml
# File: prometheus/rules/slo-alert-rules.yaml
groups:
  - name: slo.alerts
    rules:
      # ─── API Availability: Fast Burn (Critical) ─────────────────────
      - alert: SLOAvailabilityFastBurn
        expr: |
          (
            slo:http_request_error_ratio:rate1h > (14.4 * 0.001)
            and
            slo:http_request_error_ratio:rate5m > (14.4 * 0.001)
          )
        for: 2m
        labels:
          severity: critical
          slo: api-availability
          team: platform
        annotations:
          summary: "API availability SLO: fast error budget burn detected"
          description: |
            Error rate is {{ $value | humanizePercentage }} over 1h.
            At this burn rate (14.4x), the 30-day error budget will be
            exhausted in approximately 2 days.
          runbook_url: "https://wiki.internal/runbooks/slo-availability-fast-burn"
          dashboard_url: "https://grafana.internal/d/slo-overview"

      # ─── API Availability: Moderate Burn (Critical) ─────────────────
      - alert: SLOAvailabilityModerateBurn
        expr: |
          (
            slo:http_request_error_ratio:rate6h > (6 * 0.001)
            and
            slo:http_request_error_ratio:rate30m > (6 * 0.001)
          )
        for: 5m
        labels:
          severity: critical
          slo: api-availability
          team: platform
        annotations:
          summary: "API availability SLO: sustained error budget burn"
          description: |
            Error rate is {{ $value | humanizePercentage }} over 6h.
            At this burn rate (6x), the 30-day error budget will be
            exhausted in approximately 5 days.
          runbook_url: "https://wiki.internal/runbooks/slo-availability-moderate-burn"

      # ─── API Availability: Slow Burn (Warning) ──────────────────────
      - alert: SLOAvailabilitySlowBurn
        expr: |
          (
            slo:http_request_error_ratio:rate1d > (3 * 0.001)
            and
            slo:http_request_error_ratio:rate6h > (3 * 0.001)
          )
        for: 15m
        labels:
          severity: warning
          slo: api-availability
          team: platform
        annotations:
          summary: "API availability SLO: slow budget erosion detected"
          description: |
            Error rate is elevated over the past day.
            At this burn rate (3x), the error budget will be exhausted
            in approximately 10 days.
          runbook_url: "https://wiki.internal/runbooks/slo-availability-slow-burn"

      # ─── API Availability: Very Slow Burn (Ticket) ──────────────────
      - alert: SLOAvailabilityBudgetDrain
        expr: |
          (
            slo:http_request_error_ratio:rate3d > (1 * 0.001)
            and
            slo:http_request_error_ratio:rate6h > (1 * 0.001)
          )
        for: 30m
        labels:
          severity: info
          slo: api-availability
          team: platform
        annotations:
          summary: "API availability SLO: budget is draining at 1x rate"
          description: |
            At the current error rate, the entire month's error budget
            will be consumed by end of window. Investigation needed.

      # ─── Latency SLO: Fast Burn ────────────────────────────────────
      - alert: SLOLatencyFastBurn
        expr: |
          (
            (1 - slo:http_request_latency_good:rate1h) > (14.4 * 0.01)
            and
            (1 - slo:http_request_latency_good:rate5m) > (14.4 * 0.01)
          )
        for: 2m
        labels:
          severity: critical
          slo: api-latency
          team: platform
        annotations:
          summary: "API latency SLO: fast burn — too many slow requests"
          description: |
            More than {{ $value | humanizePercentage }} of requests are
            exceeding 500ms over the past hour. Burn rate: 14.4x.

      # ─── Error Budget Exhaustion ────────────────────────────────────
      - alert: SLOErrorBudgetExhausted
        expr: slo:error_budget_remaining:ratio <= 0
        for: 5m
        labels:
          severity: critical
          slo: api-availability
          team: platform
        annotations:
          summary: "Error budget for {{ $labels.slo }} is exhausted"
          description: |
            The 30-day error budget for {{ $labels.slo }} has been
            fully consumed. Deploy freeze should be enacted immediately.
            Target: {{ $labels.target }}%
```

### Key PromQL Patterns

```promql
# ─── Burn rate calculation ───────────────────────────────────────────
# burn_rate = error_ratio_in_window / budget_per_unit_time
# For 99.9% SLO, budget = 0.001

# Is 1h burn rate above 14.4x threshold?
slo:http_request_error_ratio:rate1h > (14.4 * 0.001)

# ─── Error budget remaining as percentage ────────────────────────────
# budget_remaining = 1 - (errors_so_far / total_allowed_errors)
1 - (
  (1 - slo:http_request_availability:ratio30d)  # actual error ratio
  /
  (1 - 0.999)                                    # allowed error ratio
)

# ─── Time until budget exhaustion (hours) ────────────────────────────
# If current burn rate is sustained:
(slo:error_budget_remaining:ratio * 30 * 24)
/
(slo:http_request_error_ratio:rate1h / 0.001)
```


---

## Grafana SLO Dashboard Design

### Recommended Dashboard Layout

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    SLO Overview Dashboard                                 │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  Row 1: Executive Summary (Stat Panels)                                  │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐   │
│  │ Availability │ │   Latency    │ │ Error Budget │ │  Budget Burn │   │
│  │   99.94%     │ │  p99: 312ms  │ │  Remaining   │ │    Rate      │   │
│  │  ✅ Target:  │ │  ✅ Target:  │ │    67.2%     │ │    1.2x      │   │
│  │    99.9%     │ │    500ms     │ │   ██████░░░  │ │  (healthy)   │   │
│  └──────────────┘ └──────────────┘ └──────────────┘ └──────────────┘   │
│                                                                          │
│  Row 2: Error Budget Over Time (Time Series)                             │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │ 100%│─────╮                                                       │   │
│  │     │      ╲___                                                   │   │
│  │  67%│...........╲___─────────────────── Current: 67.2%            │   │
│  │     │                                                             │   │
│  │  25%│─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─  Deploy freeze threshold   │   │
│  │   0%│─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─  Budget exhausted          │   │
│  │     └──────────────────────────────────────────────── time        │   │
│  └──────────────────────────────────────────────────────────────────┘   │
│                                                                          │
│  Row 3: Burn Rate (Time Series + Thresholds)                             │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │ 14.4│─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─  Critical threshold        │   │
│  │   6 │─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─  Warning threshold         │   │
│  │   3 │─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─                            │   │
│  │   1 │────────────────────────────────── Sustainable rate          │   │
│  │     │    ╱╲        ╱╲                                             │   │
│  │     │───╱──╲──────╱──╲─────────────── Actual burn rate           │   │
│  │     └──────────────────────────────────────────────── time        │   │
│  └──────────────────────────────────────────────────────────────────┘   │
│                                                                          │
│  Row 4: SLI Detail (split by endpoint/method)                            │
│  ┌───────────────────────────────┐ ┌───────────────────────────────┐   │
│  │  Availability by Endpoint     │ │  Latency Distribution         │   │
│  │  /api/users ─── 99.99%        │ │  (Heatmap)                    │   │
│  │  /api/orders ── 99.87% ⚠️     │ │                               │   │
│  │  /api/auth ──── 99.95%        │ │  Shows latency over time      │   │
│  │  /api/search ── 99.91%        │ │  with hot spots highlighted   │   │
│  └───────────────────────────────┘ └───────────────────────────────┘   │
│                                                                          │
│  Row 5: Incident Correlation                                             │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │  Annotations showing: deploys, incidents, budget burn events      │   │
│  │  ↓deploy    ↓incident       ↓deploy                              │   │
│  │  ──────╱╲──────────────────────────────── error rate             │   │
│  └──────────────────────────────────────────────────────────────────┘   │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### Panel Specifications

| Panel | Type | Query | Purpose |
|-------|------|-------|---------|
| Current Availability | Stat | `slo:http_request_availability:ratio30d` | At-a-glance SLI status |
| Error Budget Remaining | Gauge | `slo:error_budget_remaining:ratio * 100` | How much budget is left |
| Budget Over Time | Time Series | `slo:error_budget_remaining:ratio` | Trend of budget consumption |
| Burn Rate | Time Series | `slo:http_request_error_ratio:rate1h / 0.001` | Current burn rate vs thresholds |
| SLI by Endpoint | Table | `sum by (path)(rate(...))` | Identify worst-performing endpoints |
| Latency Heatmap | Heatmap | `rate(http_request_duration_seconds_bucket[5m])` | Latency distribution over time |
| Recent Alerts | Alert List | Grouped by SLO label | Active/recent SLO violations |

### Dashboard Variables

```
Variables to include:
- $service: dropdown of service names (kube-sre-api, kube-sre-worker, etc.)
- $slo_target: the SLO target (0.999, 0.995, etc.)
- $window: SLO window (7d, 30d)
- $environment: prod, staging
```

### Thresholds and Colors

```
Error Budget Remaining:
  > 50%  → Green
  25-50% → Yellow
  10-25% → Orange
  < 10%  → Red

Burn Rate:
  < 1x   → Green (under budget)
  1-3x   → Yellow (elevated)
  3-6x   → Orange (warning)
  > 6x   → Red (critical)
```

---

## Common Mistakes and Anti-Patterns

### ❌ Anti-Pattern 1: Setting SLOs Too High

**Mistake:** "We should target 99.99% availability."

**Why it's wrong:**
- Leaves almost no error budget (4.3 minutes/month).
- A single deploy with a 2-minute blip consumes half the budget.
- Team becomes paralyzed — afraid to ship anything.

**Fix:** Start at 99.9%. Only tighten when users demonstrably need it AND you can sustain it.

---

### ❌ Anti-Pattern 2: Too Many SLOs

**Mistake:** Creating an SLO for every metric and every endpoint.

**Why it's wrong:**
- SLOs lose meaning when there are 50 of them.
- Teams can't focus on what matters.
- Alert fatigue from multiple overlapping SLO alerts.

**Fix:** 3-5 SLOs per service maximum. Focus on what users actually care about.

---

### ❌ Anti-Pattern 3: SLOs Without Error Budget Policy

**Mistake:** Setting SLOs but never acting when budget is consumed.

**Why it's wrong:**
- SLOs become vanity metrics with no teeth.
- Teams learn to ignore them.
- No mechanism to balance velocity and reliability.

**Fix:** Document and enforce an error budget policy. Get leadership buy-in.

---

### ❌ Anti-Pattern 4: Using Average Latency as SLI

**Mistake:** `avg(http_request_duration_seconds) < 200ms`

**Why it's wrong:**
```
Scenario: 95% of requests at 50ms, 5% at 4000ms
Average = 247ms (looks okay-ish)
But 5% of users wait 4+ seconds (terrible experience)
```

**Fix:** Use percentile-based SLIs (p99, p95) or proportion-based ("99% of requests < 500ms").

---

### ❌ Anti-Pattern 5: Alerting on SLO Breach (Not Burn Rate)

**Mistake:** `alert: SLO < 99.9%` — fires when SLO is already violated.

**Why it's wrong:**
- By the time it fires, the budget is already gone.
- You're alerting on the past, not predicting the future.
- No distinction between "we lost budget slowly over weeks" vs "catastrophic failure right now."

**Fix:** Use multi-window multi-burn-rate alerting (see MWMBR section above).

---

### ❌ Anti-Pattern 6: Excluding Errors from SLI

**Mistake:** Filtering out "expected" errors, maintenance windows, or specific endpoints.

**Why it's wrong:**
- Users don't care *why* the service was down — they just know it was down.
- Exclusions create perverse incentives to classify errors as "expected."
- SLI no longer reflects user experience.

**Fix:** Measure from the user's perspective. If the user got an error, it counts. Only exclude synthetic/health-check traffic.

---

### ❌ Anti-Pattern 7: Calendar Window Gaming

**Mistake:** Team burns 80% of budget in week 1, then coasts for 3 weeks.

**Why it's wrong:**
- Users had a terrible week 1 experience.
- No incentive to fix the issue quickly since budget "resets."

**Fix:** Use rolling windows for operational SLOs. Calendar windows only for business reporting.

---

### ❌ Anti-Pattern 8: Ignoring Dependencies

**Mistake:** Setting a 99.99% SLO when your database is 99.9%.

**Why it's wrong:**
- Mathematically impossible to exceed your dependencies' reliability.
- Creates frustration as team "fails" despite doing everything right.

**Fix:** Your SLO ≤ product of dependency SLOs. If DB is 99.9% and cache is 99.95%, your ceiling is ~99.85%.

---

### ❌ Anti-Pattern 9: SLOs That Never Fail

**Mistake:** Service consistently achieves 99.99% against a 99.9% SLO.

**Why it's wrong:**
- You're over-investing in reliability.
- Innovation velocity is being sacrificed for unnecessary stability.
- The SLO isn't driving any useful decisions.

**Fix:** Either tighten the SLO or reduce investment in reliability for this service (fewer replicas, simpler architecture). The error budget should be **used**, not hoarded.

---

### ❌ Anti-Pattern 10: No Runbooks for SLO Alerts

**Mistake:** SLO alert fires at 3 AM. On-call engineer has no idea what to do.

**Why it's wrong:**
- Alert without action guidance is just noise.
- Increased MTTR while engineer figures out response.

**Fix:** Every SLO alert must have:
- A `runbook_url` annotation linking to a response playbook.
- Clear escalation path.
- Pre-built dashboard link showing the relevant SLI.

---

## Summary Checklist

Before launching an SLO, confirm:

- [ ] SLI is defined from the user's perspective
- [ ] Target is achievable and meaningful (not aspirational)
- [ ] Window type and length are chosen deliberately
- [ ] Error budget policy is documented and agreed upon
- [ ] Recording rules are deployed to Prometheus
- [ ] MWMBR alert rules are configured with appropriate severity
- [ ] Every alert has a runbook URL and dashboard link
- [ ] Grafana dashboard shows budget remaining and burn rate
- [ ] Stakeholders (PM, Eng Lead, SRE) have reviewed and agreed
- [ ] Review cadence is set (monthly SLO review meeting)

---

## References

- [Google SRE Book — Chapter 4: Service Level Objectives](https://sre.google/sre-book/service-level-objectives/)
- [Google SRE Workbook — Chapter 2: Implementing SLOs](https://sre.google/workbook/implementing-slos/)
- [Alerting on SLOs (Google)](https://sre.google/workbook/alerting-on-slos/)
- [The Art of SLOs (Google Cloud)](https://cloud.google.com/blog/products/management-tools/practical-guide-to-setting-slos)

---

*Last updated: 2026-07-23 | Maintainer: SRE Team | kube-sre-stack*
