# SLA Guide — Service Level Agreements

> A comprehensive guide to understanding, writing, and managing Service Level Agreements (SLAs) for platform and application teams.

---

## Table of Contents

1. [What is an SLA?](#what-is-an-sla)
2. [SLA vs SLO vs SLI](#sla-vs-slo-vs-sli)
3. [Why SLAs Matter](#why-slas-matter)
4. [Components of an SLA](#components-of-an-sla)
5. [The SLO-SLA Gap](#the-slo-sla-gap)
6. [Types of SLAs](#types-of-slas)
7. [Consequences and Remedies](#consequences-and-remedies)
8. [Real-World SLA Examples](#real-world-sla-examples)
9. [How to Write an SLA](#how-to-write-an-sla)
10. [SLA Monitoring and Reporting](#sla-monitoring-and-reporting)
11. [Exclusions and Maintenance Windows](#exclusions-and-maintenance-windows)
12. [SLA Review Process](#sla-review-process)
13. [Common Mistakes](#common-mistakes)
14. [Complete SLA Template](#complete-sla-template)

---

## What is an SLA?

An **SLA (Service Level Agreement)** is a formal, often legally binding contract between a service provider and a customer that defines the expected level of service. It spells out exactly what the customer can expect, and what happens if the provider fails to deliver.

Think of it this way:

- An **SLO** (Service Level Objective) is an *internal goal* — "We aim for 99.95% availability."
- An **SLA** is an *external promise* — "We guarantee 99.9% availability, or we pay you back."

**In plain English:** An SLA is a written promise to your customers about how reliable your service will be, backed by financial or contractual consequences if you break that promise.

### Key characteristics of an SLA

- **Formal and documented** — Written into contracts, not verbal agreements
- **Measurable** — Uses specific metrics with clear definitions
- **Time-bound** — Measured over defined periods (monthly, quarterly)
- **Consequential** — Includes penalties or remedies for non-compliance
- **Mutual** — Both parties agree to the terms

```
┌─────────────────────────────────────────────────────────────┐
│                    Reliability Stack                         │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│   SLI (Indicator)  →  What you measure                     │
│         ↓                                                   │
│   SLO (Objective)  →  What you aim for (internal target)   │
│         ↓                                                   │
│   SLA (Agreement)  →  What you promise (external contract) │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## SLA vs SLO vs SLI

Understanding the relationship between these three concepts is critical:

| Aspect | SLI (Indicator) | SLO (Objective) | SLA (Agreement) |
|--------|-----------------|-----------------|-----------------|
| **What it is** | A metric/measurement | An internal target | An external contract |
| **Who sets it** | Engineering team | Engineering + Product | Business + Legal + Engineering |
| **Audience** | Engineers | Internal teams | Customers, partners, executives |
| **Example** | Request latency p99 = 180ms | p99 latency < 200ms | 99.9% of requests under 300ms |
| **Consequence of miss** | Alerts, investigation | Error budget depletion, feature freeze | Financial penalties, legal liability |
| **Flexibility** | Can change frequently | Reviewed quarterly | Contract renegotiation required |
| **Documentation** | Monitoring configs | Internal runbooks | Legal contracts |
| **Strictness** | Raw data | Stricter than SLA | Less strict than SLO |

### The hierarchy in practice

```
SLI: "Our p99 latency was 145ms last month"
         │
         ▼
SLO: "We target p99 latency < 200ms" (internal goal, stricter)
         │
         ▼
SLA: "We guarantee p99 latency < 300ms" (external promise, with buffer)
```

### Why the distinction matters

- **SLIs** tell you the truth about your system right now
- **SLOs** tell you whether you're on track to keep your promises
- **SLAs** tell your customers what they can legally expect from you

If you only have SLAs without SLOs, you'll constantly be fighting fires at the contract boundary. SLOs give you early warning before an SLA breach occurs.

---

## Why SLAs Matter

### Business perspective

- **Revenue protection** — Customers choose providers based on SLA guarantees
- **Competitive advantage** — Stronger SLAs can justify premium pricing
- **Customer retention** — Clear expectations reduce churn from unmet assumptions
- **Sales enablement** — Sales teams need concrete reliability numbers to close deals

### Legal perspective

- **Liability boundaries** — SLAs define the maximum extent of your obligations
- **Dispute resolution** — Clear metrics prevent "he said, she said" arguments
- **Regulatory compliance** — Some industries (finance, healthcare) require formal SLAs
- **Contract enforceability** — Vague promises are legally weaker than specific commitments

### Trust perspective

- **Transparency** — Publishing SLAs shows confidence in your platform
- **Accountability** — Penalties demonstrate you have skin in the game
- **Predictability** — Customers can plan their own architectures around your guarantees
- **Partnership** — SLAs turn a vendor relationship into a mutual commitment

### What happens without SLAs

| Scenario | Without SLA | With SLA |
|----------|-------------|----------|
| Service goes down for 2 hours | Customer angry, no recourse | Customer receives service credit automatically |
| Customer expects 99.99% but gets 99.9% | Frustrated complaints | Clear understanding of what was promised |
| Vendor blames "force majeure" for everything | No way to dispute | Exclusions are explicitly defined |
| Customer builds mission-critical system on your API | Implicit trust, high risk | Informed decision based on guarantees |

---

## Components of an SLA

Every well-constructed SLA contains these components:

### 1. Service description

What exactly is covered by this SLA?

```yaml
service:
  name: "Payment Processing API"
  version: "v2"
  endpoints:
    - POST /api/v2/payments
    - GET /api/v2/payments/{id}
    - POST /api/v2/refunds
  environments:
    - production
  excluded:
    - staging
    - sandbox
    - deprecated v1 endpoints
```

### 2. Metrics (what you measure)

| Metric | Definition | How measured |
|--------|-----------|--------------|
| **Availability** | % of time service responds successfully | `(total_minutes - downtime_minutes) / total_minutes × 100` |
| **Latency** | Time to respond to requests | p50, p95, p99 measured at load balancer |
| **Error rate** | % of requests returning errors | `5xx_responses / total_responses × 100` |
| **Throughput** | Requests handled per second | Measured at API gateway |
| **Durability** | Data retention guarantee | % of objects stored without loss per year |

### 3. Targets

```
┌──────────────────────────────────────────────────────┐
│  Tier      │  Availability  │  Latency (p99)  │  Errors  │
├──────────────────────────────────────────────────────┤
│  Premium   │  99.99%        │  < 100ms        │  < 0.01% │
│  Standard  │  99.95%        │  < 200ms        │  < 0.05% │
│  Basic     │  99.9%         │  < 500ms        │  < 0.1%  │
└──────────────────────────────────────────────────────┘
```

### 4. Measurement window

- **Monthly** — Most common for availability SLAs
- **Quarterly** — Used for aggregate performance metrics
- **Annual** — Used for durability guarantees (e.g., S3's 99.999999999%)
- **Rolling** — e.g., "any 30-day rolling window"

### 5. Exclusions

Things that do NOT count against your SLA:

- Scheduled maintenance (with advance notice)
- Force majeure (natural disasters, war, government actions)
- Customer-caused issues (misconfiguration, exceeding rate limits)
- Third-party failures outside your control
- Alpha/beta features explicitly marked as non-SLA

### 6. Penalties and credits

What happens when you miss:

| Availability achieved | Service credit (% of monthly bill) |
|----------------------|-------------------------------------|
| 99.0% – 99.9% | 10% |
| 95.0% – 99.0% | 25% |
| < 95.0% | 50% |

### 7. Reporting and notification

- How customers are notified of incidents
- Where to find real-time status (status page)
- Monthly/quarterly SLA compliance reports
- Process for customers to file SLA claims

---

## The SLO-SLA Gap

### Why your SLO should be stricter than your SLA

The **SLO-SLA gap** is your safety buffer. It gives you room to detect and fix problems before they become contractual breaches.

```
    100%  ┬─────────────────────────────────────────
          │
   99.99% ┤  ← SLO target (what you aim for internally)
          │     │
          │     │  ← "Error budget" for SLO
          │     │
   99.95% ┤─────┘
          │
          │     ← BUFFER ZONE (SLO-SLA gap)
          │       This is your safety margin
          │
    99.9% ┤  ← SLA commitment (what you promise externally)
          │     │
          │     │  ← BREACH ZONE (financial penalties)
          │     │
    99.0% ┤─────┘
          │
          ┴─────────────────────────────────────────
```

### Recommended gaps

| SLA commitment | Recommended SLO | Gap | Rationale |
|---------------|----------------|-----|-----------|
| 99.9% (43.8 min/month downtime) | 99.95% (21.9 min/month) | 0.05% | Standard services |
| 99.95% (21.9 min/month) | 99.99% (4.4 min/month) | 0.04% | Critical services |
| 99.99% (4.4 min/month) | 99.995% (2.2 min/month) | 0.005% | Premium tier |

### What the gap gives you

1. **Early warning** — SLO alerts fire before SLA breach occurs
2. **Time to react** — Engineers can fix issues before customers feel pain
3. **Error budget** — Teams can spend budget on deployments and experiments
4. **Confidence** — You can promise customers what you know you can deliver
5. **Negotiation room** — If SLO tightens over time, you can offer better SLAs

### Anti-pattern: SLA = SLO

If your SLA equals your SLO, you have **zero buffer**:

- Every SLO miss is immediately a contract breach
- Engineers are constantly in fire-fighting mode
- No room for planned maintenance or experiments
- Customer trust erodes because breaches are frequent

---

## Types of SLAs

### 1. Customer-facing SLA

**Audience:** External paying customers

**Characteristics:**
- Legally binding contract
- Financial penalties (service credits)
- Published publicly or included in contract
- Reviewed by legal team
- Hardest to change

**Example:**
> "We guarantee 99.95% monthly uptime for our API. If we fail, affected customers receive service credits per our credit schedule."

### 2. Internal SLA

**Audience:** Internal teams (e.g., platform team → product teams)

**Characteristics:**
- Not legally binding but operationally critical
- Consequences are organizational (escalation, priority shifts)
- Easier to adjust based on capacity
- Builds trust between teams

**Example:**
> "The platform team guarantees Kubernetes cluster availability of 99.99% to all product teams. Breaches trigger a post-incident review and capacity planning reassessment."

### 3. Vendor/third-party SLA

**Audience:** You as the customer of another provider

**Characteristics:**
- Defines what you can expect from dependencies
- Informs your own SLA calculations
- Important for architecture decisions
- Credits flow upstream

**Example:**
> "AWS guarantees EC2 99.99% availability in multi-AZ deployments. Our architecture must account for the 0.01% where AWS may be unavailable."

### Comparison

| Aspect | Customer-facing | Internal | Vendor |
|--------|----------------|----------|--------|
| Legal binding | Yes | No | Yes (their terms) |
| Financial penalties | Service credits | Priority/resources | Credits from vendor |
| Who writes it | Your legal + eng | Platform team | Vendor |
| Change frequency | Annually | Quarterly | At vendor's discretion |
| Enforcement | Contract law | Team agreements | Vendor's claims process |


---

## Consequences and Remedies

### Service credits

The most common SLA remedy. Credits are applied to future invoices, not paid as cash.

**Typical credit structure:**

| Uptime achieved | Monthly credit % | Example (on $10,000/mo bill) |
|----------------|------------------|-------------------------------|
| 99.9% – 99.95% | 10% | $1,000 credit |
| 99.0% – 99.9% | 25% | $2,500 credit |
| 95.0% – 99.0% | 50% | $5,000 credit |
| < 95.0% | 100% | $10,000 credit |

**Key rules for service credits:**

- Credits are typically capped at 100% of the affected month's bill (never more)
- Customer must usually file a claim within 30 days
- Credits apply only to the affected service, not the entire account
- Credits cannot be converted to cash or transferred

### Penalty structures

Beyond credits, SLAs may include:

| Penalty type | Description | When used |
|-------------|-------------|-----------|
| **Service credits** | Discount on next invoice | Standard cloud/SaaS |
| **Financial penalties** | Cash payment to customer | Enterprise contracts |
| **Accelerated payment** | Fees become due immediately | Long-term contracts |
| **Extended terms** | Free service extension | Subscription services |
| **Escalation rights** | Customer gets dedicated support | Managed services |

### Termination clauses

Customers may have the right to terminate the contract if:

- SLA is breached for **3 consecutive months**
- A single incident exceeds **24 hours of downtime**
- Availability drops below **95% in any month**
- Provider fails to deliver a **root cause analysis** within agreed timeframe

**Example termination clause:**

```
If Provider fails to meet the Availability SLA for three (3) consecutive 
calendar months, Customer may terminate this Agreement upon thirty (30) 
days written notice without penalty, and shall receive a pro-rata refund 
of any prepaid fees for the unused portion of the term.
```

### Escalation matrix

```
┌──────────────────────────────────────────────────────────────────────┐
│  SLA Breach Severity    │  Response           │  Escalation          │
├──────────────────────────────────────────────────────────────────────┤
│  Within 0.05% of SLA   │  Engineering alert   │  Team lead notified  │
│  SLA breached (< 30m)  │  Incident declared   │  VP Engineering      │
│  SLA breached (> 1hr)  │  Major incident      │  CTO + Customer Mgr  │
│  SLA breached (> 4hr)  │  Critical incident   │  CEO + Legal         │
└──────────────────────────────────────────────────────────────────────┘
```

---

## Real-World SLA Examples

### Example 1: Cloud provider SLA (AWS EC2 style)

This mimics how major cloud providers structure their SLAs:

```markdown
## Compute Service SLA

**Effective date:** January 1, 2025
**Service:** Virtual Machine Instances (multi-AZ deployment)

### Monthly Uptime Commitment

| Deployment type | Monthly uptime % |
|----------------|------------------|
| Multi-AZ | 99.99% |
| Single-AZ | 99.95% |
| Single instance | 99.5% |

### Definitions

- **Monthly Uptime %**: 100% minus the Unavailability Rate
- **Unavailability**: When all running instances in a region have no 
  external connectivity for more than 5 consecutive minutes
- **Excluded**: Maintenance announced 7 days in advance, customer 
  misconfigurations, instance types marked "preview"

### Service credit schedule

| Monthly uptime % | Credit % |
|-----------------|----------|
| 99.0% – 99.99% | 10% |
| 95.0% – 99.0% | 30% |
| < 95.0% | 100% |

### How to file a claim

1. Submit ticket within 30 days of incident
2. Include affected instance IDs and timestamps
3. Provider validates against internal monitoring
4. Credits applied within 60 days if claim is valid
```

**Key takeaway:** Cloud providers define "unavailability" very narrowly (complete loss of connectivity to ALL instances), making actual breaches rare.

### Example 2: Internal platform SLA for developer teams

```markdown
## Kubernetes Platform SLA — Internal

**Provider:** Platform Engineering Team
**Consumer:** All product development teams
**Effective:** Q1 2025

### Scope

- Production Kubernetes clusters (all regions)
- Ingress controllers and load balancers
- Container registry
- CI/CD pipeline infrastructure

### Commitments

| Service | Availability target | Measurement |
|---------|-------------------|-------------|
| K8s API server | 99.99% | Synthetic probe every 10s |
| Pod scheduling | 99.95% | Pod pending < 30s for 95th percentile |
| Ingress routing | 99.99% | Health check from external monitor |
| Container registry | 99.95% | Pull latency < 5s at p99 |
| CI/CD pipelines | 99.9% | Pipeline start within 60s of trigger |

### Measurement window

- Monthly, calculated from the 1st to last day of calendar month
- Reported on the 5th business day of the following month

### Exclusions

- Scheduled maintenance (announced 48h in advance via #platform-announcements)
- Cluster upgrades (announced 1 week in advance)
- Tenant misconfigurations (resource limits, bad health checks)
- Workloads exceeding declared resource quotas

### Consequences of breach

| Breach type | Consequence |
|-------------|-------------|
| Single month miss | Post-incident review published within 5 days |
| Two consecutive months | Capacity planning review, additional resources allocated |
| Three consecutive months | Escalation to VP Engineering, remediation plan required |

### Support response times

| Severity | Response time | Resolution target |
|----------|--------------|-------------------|
| P1 (service down) | 5 minutes | 1 hour |
| P2 (degraded) | 15 minutes | 4 hours |
| P3 (minor issue) | 1 hour | 1 business day |
| P4 (request) | 4 hours | 5 business days |
```

### Example 3: API SLA for external consumers

```markdown
## Payment Gateway API SLA

**Provider:** Acme Payments Inc.
**Customer:** API consumers on Professional and Enterprise plans
**Version:** 3.0
**Effective:** March 1, 2025

### Covered endpoints

- `POST /v3/charges` — Process a payment
- `POST /v3/refunds` — Issue a refund
- `GET /v3/charges/{id}` — Retrieve charge status
- `POST /v3/customers` — Create a customer record

### Service levels

| Metric | Professional plan | Enterprise plan |
|--------|------------------|-----------------|
| Availability | 99.95% | 99.99% |
| Latency (p99) | < 500ms | < 200ms |
| Error rate (5xx) | < 0.1% | < 0.01% |
| Rate limit | 1,000 req/s | 10,000 req/s |
| Support response (P1) | 30 minutes | 5 minutes |

### Definitions

- **Availability** = `1 - (error_minutes / total_minutes)` where an 
  "error minute" is any minute with > 5% server errors
- **Latency** = Time from request received at API gateway to response 
  sent, measured at our edge
- **Error rate** = Server-side errors (5xx) divided by total valid requests

### Credit schedule

| Monthly availability | Credit (% of monthly API fees) |
|---------------------|-------------------------------|
| 99.9% – 99.95% | 10% |
| 99.0% – 99.9% | 25% |
| 95.0% – 99.0% | 50% |
| < 95.0% | 100% |

### Exclusions

- Requests exceeding your plan's rate limit
- Requests with malformed payloads (4xx errors)
- Sandbox/test environment
- Deprecated API versions (v1, v2) — best-effort only
- Issues caused by customer webhook endpoints being unreachable

### Claim process

1. File claim via dashboard within 30 calendar days
2. Include: affected endpoint, timestamps (UTC), request IDs
3. We validate against our server-side logs
4. Credits applied to next billing cycle
```


---

## How to Write an SLA

### Step-by-step process

```
┌──────────────────────────────────────────────────────────┐
│  Step 1: Identify your service and its boundaries        │
│              ↓                                            │
│  Step 2: Define measurable SLIs                          │
│              ↓                                            │
│  Step 3: Set internal SLOs (with historical data)        │
│              ↓                                            │
│  Step 4: Determine SLA targets (SLO minus buffer)        │
│              ↓                                            │
│  Step 5: Define exclusions and measurement method        │
│              ↓                                            │
│  Step 6: Establish penalty/credit structure               │
│              ↓                                            │
│  Step 7: Legal review and stakeholder sign-off           │
│              ↓                                            │
│  Step 8: Implement monitoring and reporting              │
│              ↓                                            │
│  Step 9: Publish and communicate to customers            │
└──────────────────────────────────────────────────────────┘
```

### Guidelines for each step

**Step 1: Service boundaries**
- Be specific about what's covered (endpoints, environments, regions)
- Explicitly state what's NOT covered
- Define the customer segments this applies to

**Step 2: Choose SLIs**
- Pick metrics that reflect user experience
- Ensure they can be measured reliably and independently
- Prefer server-side measurements (you control the data)

**Step 3: Set SLOs from data**
- Review 3-6 months of historical performance
- Set SLO at a level you've consistently achieved
- Don't set aspirational targets — use actual capability

**Step 4: Apply the SLO-SLA buffer**
- SLA = SLO minus a safety margin (typically 0.05% – 0.5%)
- The less mature your operations, the larger the buffer should be
- Consider your dependency chain — their SLAs cap yours

**Step 5: Define exclusions clearly**
- Be specific (not "scheduled maintenance" but "maintenance announced 72h in advance via email")
- Limit exclusion categories — too many erodes trust
- Include force majeure but define it narrowly

**Step 6: Make penalties meaningful**
- Credits should be meaningful enough to demonstrate accountability
- But not so large they threaten business viability
- Typical cap: 100% of the affected service's monthly fee

**Step 7: Legal review**
- Ensure terms are enforceable in your jurisdiction
- Define dispute resolution process
- Include limitation of liability clause
- Specify governing law

**Step 8: Implement monitoring**
- Monitoring must be in place BEFORE the SLA takes effect
- Use independent measurement where possible
- Automate SLA compliance reporting

**Step 9: Publish and communicate**
- Make the SLA easily accessible (not buried in legal docs)
- Train support and sales teams on the SLA
- Publish a status page that reflects SLA metrics

### SLA structure template

A well-organized SLA document should follow this structure:

```
1. Overview
   - Service description
   - Effective date and term
   - Parties involved

2. Definitions
   - Technical terms (availability, downtime, error minute)
   - Business terms (service credit, claim)

3. Service levels
   - Metrics and targets (table format)
   - Measurement methodology
   - Measurement window

4. Exclusions
   - Scheduled maintenance
   - Force majeure
   - Customer-caused issues
   - Out-of-scope services

5. Remedies
   - Service credit schedule
   - Credit caps
   - Claim process and deadlines

6. Obligations
   - Provider obligations
   - Customer obligations (e.g., file claims timely)

7. Reporting
   - How compliance is reported
   - Where to find real-time status

8. Review and amendments
   - How often the SLA is reviewed
   - How changes are communicated
   - Notice period for changes

9. Termination
   - Conditions for early termination
   - Effect on prepaid fees
```

---

## SLA Monitoring and Reporting

### What to monitor

| What | How | Tool examples |
|------|-----|---------------|
| Availability | Synthetic uptime probes | Prometheus BlackBox Exporter, Pingdom, Datadog |
| Latency | Request duration histograms | Prometheus + Grafana, Honeycomb |
| Error rate | 5xx response ratio | Prometheus `rate(http_requests_total{code=~"5.."}[5m])` |
| SLA compliance | Remaining error budget | Sloth, Google SLO Generator, custom dashboards |
| Incident duration | Time from detection to resolution | PagerDuty, Opsgenie |

### Prometheus-based SLA tracking

```yaml
# SLA compliance recording rule
groups:
  - name: sla_compliance
    interval: 1m
    rules:
      # Monthly availability calculation
      - record: sla:availability:ratio_monthly
        expr: |
          1 - (
            sum(rate(http_requests_total{code=~"5..", job="payment-api"}[30d]))
            /
            sum(rate(http_requests_total{job="payment-api"}[30d]))
          )

      # SLA breach alert
      - alert: SLABreachImminent
        expr: sla:availability:ratio_monthly < 0.9995
        for: 5m
        labels:
          severity: critical
          sla: "true"
        annotations:
          summary: "SLA breach imminent for payment-api"
          description: |
            Current monthly availability is {{ $value | humanizePercentage }}.
            SLA commitment is 99.9%. Immediate action required.

      # Error budget consumption alert
      - alert: ErrorBudgetNearlyExhausted
        expr: |
          (
            1 - sla:availability:ratio_monthly
          ) / (1 - 0.999) > 0.8
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "80% of monthly error budget consumed"
```

### Grafana dashboard structure

A good SLA dashboard includes:

1. **Current month availability** — Big number, color-coded (green/yellow/red)
2. **Error budget remaining** — Percentage and absolute time remaining
3. **Error budget burn rate** — Are we consuming budget faster than expected?
4. **Time series** — Availability over time with SLA threshold line
5. **Incident log** — List of SLA-impacting incidents this period
6. **Forecast** — At current burn rate, will we breach this month?

```
┌─────────────────────────────────────────────────────────────────┐
│  SLA Compliance Dashboard — Payment API — July 2025             │
├────────────────┬────────────────┬───────────────────────────────┤
│                │                │                               │
│  Availability  │  Error Budget  │  Burn Rate                    │
│    99.97%      │    72%         │  ████████░░ Normal            │
│   [GREEN]      │  [YELLOW]      │                               │
│                │                │                               │
├────────────────┴────────────────┴───────────────────────────────┤
│                                                                 │
│  Availability over time (30d)                                   │
│  100% ─────────────────╮    ╭──────────────────────────         │
│  99.9%─ ─ ─ ─ ─ ─ ─ ─ ┤────┤─ ─ ─ ─ ─ SLA ─ ─ ─ ─ ─        │
│  99.0% ────────────────┘    └──────────────────────────         │
│       Jul 1          Jul 12          Jul 23                     │
│                                                                 │
├─────────────────────────────────────────────────────────────────┤
│  Incidents this month:                                          │
│  • Jul 12 03:15-03:42 UTC — Database failover (27 min)         │
│  • Jul 18 14:02-14:08 UTC — Deploy rollback (6 min)            │
│  Total downtime: 33 minutes / Budget: 43.8 minutes             │
└─────────────────────────────────────────────────────────────────┘
```

### Reporting cadence

| Report | Frequency | Audience | Content |
|--------|-----------|----------|---------|
| Real-time status | Continuous | Public | Current status, active incidents |
| Weekly SLA summary | Weekly | Engineering | Burn rate, upcoming risks |
| Monthly SLA report | Monthly | Leadership, customers | Compliance %, incidents, credits issued |
| Quarterly SLA review | Quarterly | Executive + Legal | Trends, SLA adequacy, proposed changes |

---

## Exclusions and Maintenance Windows

### Standard exclusion categories

#### 1. Scheduled maintenance

```yaml
maintenance_policy:
  notice_period: 72 hours minimum
  notification_channels:
    - email to account contacts
    - status page announcement
    - in-app banner (24h before)
  maximum_duration: 4 hours per window
  frequency: No more than 2 windows per month
  preferred_times:
    - "Tuesday 02:00-06:00 UTC"
    - "Thursday 02:00-06:00 UTC"
  sla_impact: Excluded from availability calculation
```

**Important:** If maintenance overruns the announced window, the overage DOES count against the SLA.

#### 2. Force majeure

Events genuinely beyond either party's control:

- Natural disasters (earthquakes, floods, hurricanes)
- Government actions (sanctions, regulations, court orders)
- War, terrorism, civil unrest
- Pandemic-related government mandates
- Internet backbone outages (verified by third-party sources)

**NOT force majeure:**
- Cloud provider outages (that's a dependency you chose)
- DDoS attacks (that's an operational risk you should mitigate)
- Software bugs (that's your responsibility)
- Staffing shortages (that's a business planning issue)

#### 3. Customer-caused issues

| Exclusion | Example |
|-----------|---------|
| Rate limit exceeded | Customer sends 10x their plan limit |
| Malformed requests | Invalid API payloads returning 4xx |
| Configuration errors | Customer misconfigures DNS/webhooks |
| Unauthorized access attempts | Brute force attacks from customer IP |
| Failure to apply recommended updates | Running deprecated client SDK |

#### 4. Explicitly excluded services

- Beta/preview features
- Deprecated API versions
- Non-production environments
- Free tier services
- Services explicitly marked "best effort"

### Maintenance window best practices

| Practice | Recommendation |
|----------|---------------|
| Advance notice | 72 hours minimum, 7 days preferred |
| Duration | Cap at 4 hours, target under 1 hour |
| Frequency | Maximum 2 per month |
| Timing | Low-traffic hours for your customer base |
| Communication | Multiple channels (email, status page, in-app) |
| Overrun policy | Time beyond announced window counts against SLA |
| Emergency maintenance | Allowed with shortened notice, but still tracked |

---

## SLA Review Process

### Why SLAs need regular review

- Service architecture evolves (microservices, new dependencies)
- Customer expectations change
- Competitive landscape shifts
- Historical data reveals whether targets are appropriate
- Business costs of penalties may need adjustment

### Review cadence

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│  Quarterly: Light review                                        │
│  ├── Are we consistently meeting our SLA?                       │
│  ├── Are SLO-SLA gaps appropriate?                              │
│  └── Any emerging risks?                                        │
│                                                                 │
│  Annually: Deep review                                          │
│  ├── Should targets change (tighter or looser)?                 │
│  ├── Are exclusions still appropriate?                          │
│  ├── Do penalty structures need adjustment?                     │
│  ├── Has the competitive landscape changed?                     │
│  └── Are new services in scope?                                 │
│                                                                 │
│  Triggered: Ad-hoc review                                       │
│  ├── After a major incident                                     │
│  ├── After architecture changes                                 │
│  ├── When adding new service tiers                              │
│  └── When customer complaints indicate misalignment             │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Review checklist

- [ ] Review past 6 months of SLA compliance data
- [ ] Identify any months where SLA was at risk (even if not breached)
- [ ] Review customer complaints related to reliability
- [ ] Assess whether error budget burn rate is healthy
- [ ] Check if dependency SLAs have changed
- [ ] Verify monitoring is still accurately measuring SLIs
- [ ] Compare with competitor SLAs
- [ ] Validate that exclusions are not being overused
- [ ] Confirm penalty structures are still appropriate
- [ ] Update documentation if anything changes

### Stakeholders in the review

| Stakeholder | Role in review |
|-------------|---------------|
| Engineering | Assess technical feasibility of targets |
| Product | Align SLA with customer needs and product roadmap |
| Legal | Ensure contract terms are enforceable |
| Finance | Validate cost impact of penalties |
| Sales | Provide competitive intelligence |
| Customer Success | Share customer feedback on reliability |

### Change management

When SLA changes are needed:

1. **Tightening SLA** (promising more) — Can be done at any time, customers benefit
2. **Loosening SLA** (promising less) — Requires advance notice (typically 90 days)
3. **Adding exclusions** — Treat as loosening; requires notice
4. **Reducing credits** — Requires contract renegotiation for existing customers

Typical notice period for adverse changes: **90 days minimum**


---

## Common Mistakes

### 1. Over-promising

**The mistake:** Setting SLA targets based on aspirations rather than demonstrated capability.

```
❌ "We'll guarantee 99.99% because that sounds impressive"
✅ "Our trailing 6-month average is 99.97%, so we'll commit to 99.95%"
```

**Why it's dangerous:**
- Constant SLA breaches erode trust faster than a modest SLA builds it
- Financial liability from credits can become significant
- Teams burn out from perpetual firefighting

**The fix:** Base SLA targets on historical data minus a buffer. Never promise better than your P25 (25th percentile month).

### 2. No measurement infrastructure

**The mistake:** Committing to an SLA before having reliable measurement in place.

```
❌ "We promise 99.95% availability" (but we only check every 5 minutes)
✅ "We measure availability via synthetic probes every 10 seconds from 
    3 independent regions, calculated as..."
```

**Why it's dangerous:**
- Customers and provider may have different numbers
- Disputes become unresolvable
- You can't improve what you can't measure

**The fix:** Implement monitoring FIRST. Run it for at least one month. Then set your SLA.

### 3. Vague language

**The mistake:** Using imprecise definitions that leave room for interpretation.

| ❌ Vague | ✅ Precise |
|---------|-----------|
| "High availability" | "99.95% monthly availability" |
| "Fast response times" | "p99 latency < 200ms" |
| "Reasonable downtime" | "Maximum 4-hour maintenance window, 72h notice" |
| "Best-effort support" | "P1 response within 15 minutes, 24/7" |
| "May experience degradation" | "Throughput may reduce by up to 50% during maintenance" |

**Why it's dangerous:**
- Each party interprets terms in their own favor
- Legal disputes are expensive and damaging
- Customer trust erodes when expectations don't match delivery

**The fix:** Every term in your SLA should be measurable, specific, and unambiguous.

### 4. Ignoring dependencies

**The mistake:** Promising availability higher than your dependencies can support.

```
Your SLA: 99.99% (4.4 min downtime/month)
Your cloud provider SLA: 99.95% (21.9 min downtime/month)

❌ This is mathematically impossible to guarantee!
```

**The fix:** Your SLA can never be stronger than your weakest critical dependency's SLA (unless you have redundancy across providers).

**Dependency calculation:**
```
Combined availability = Provider_A × Provider_B × Provider_C
                      = 0.9999 × 0.9995 × 0.999
                      = 0.9984 (maximum achievable)
```

### 5. No claim process

**The mistake:** Promising credits but making them impossible to claim.

**Why it's dangerous:**
- Customers feel cheated even when SLA is breached
- Regulatory risk in some jurisdictions
- Damages relationship more than the outage itself

**The fix:**
- Make the claim process simple (form on dashboard, not a legal letter)
- Consider automatic credits for obvious breaches
- Set a reasonable deadline (30 days, not 48 hours)

### 6. SLA covers the wrong thing

**The mistake:** Measuring infrastructure uptime when customers care about transaction success.

```
❌ "Servers were up 99.99% of the time" 
   (but the payment endpoint was returning errors)

✅ "99.95% of payment requests completed successfully within 500ms"
```

**The fix:** Define SLIs from the customer's perspective. What does "working" mean to THEM?

### 7. One-size-fits-all

**The mistake:** Same SLA for all customers regardless of their plan or needs.

**The fix:** Tier your SLAs:

| Tier | Availability | Support | Price |
|------|-------------|---------|-------|
| Basic | 99.9% | Business hours | $ |
| Professional | 99.95% | 24/7, 30min P1 | $$ |
| Enterprise | 99.99% | 24/7, 5min P1, dedicated TAM | $$$ |

### 8. No internal SLO backing the SLA

**The mistake:** Having an SLA without a corresponding, stricter internal SLO.

**Why it's dangerous:**
- No early warning before breach
- No error budget for planned work
- Every degradation is immediately a crisis

**The fix:** Always pair: `SLO (stricter) → SLA (what you promise)`

### Summary of mistakes

```
┌──────────────────────────────────────────────────────────────┐
│  Mistake              │  Risk                │  Prevention    │
├──────────────────────────────────────────────────────────────┤
│  Over-promising       │  Constant breaches   │  Use real data │
│  No measurement       │  Disputes            │  Monitor first │
│  Vague language       │  Misalignment        │  Be specific   │
│  Ignore dependencies  │  Impossible targets  │  Do the math   │
│  No claim process     │  Customer anger      │  Make it easy  │
│  Wrong metrics        │  False confidence    │  User's view   │
│  One size fits all    │  Under/over-serve    │  Tier it       │
│  No SLO behind SLA   │  No early warning    │  SLO > SLA     │
└──────────────────────────────────────────────────────────────┘
```

---

## Complete SLA Template

Use this template as a starting point for your own SLA documents:

```markdown
# Service Level Agreement

## 1. Overview

**Service name:** [Your Service Name]
**Provider:** [Your Company]
**Customer:** [Customer Name or "All customers on [Plan] tier"]
**Effective date:** [Start Date]
**Term:** [Duration, e.g., "12 months, auto-renewing"]
**Version:** [Document version]
**Last updated:** [Date]

## 2. Definitions

| Term | Definition |
|------|-----------|
| **Availability** | The percentage of time the Service is operational and accessible, calculated as `((Total_Minutes - Downtime_Minutes) / Total_Minutes) × 100` |
| **Downtime** | Any period of 1 minute or more where the Service returns errors for more than 5% of requests |
| **Error** | Any HTTP response with status code 500-599 from the Service |
| **Measurement period** | One calendar month, from 00:00:00 UTC on the first day to 23:59:59 UTC on the last day |
| **Service credit** | A percentage of the Customer's monthly fee for the affected Service, applied to a future invoice |
| **Claim** | A formal request by Customer for Service Credits due to an SLA breach |
| **Scheduled maintenance** | Pre-announced maintenance windows communicated at least [72 hours] in advance |

## 3. Service levels

### 3.1 Availability

| Service tier | Monthly availability target |
|-------------|---------------------------|
| [Tier 1] | [99.99%] |
| [Tier 2] | [99.95%] |
| [Tier 3] | [99.9%] |

### 3.2 Performance

| Metric | Target | Measurement point |
|--------|--------|-------------------|
| Response time (p50) | < [100ms] | [API gateway] |
| Response time (p99) | < [500ms] | [API gateway] |
| Error rate | < [0.1%] | [Server-side logs] |
| Throughput | [X] requests/second | [Load balancer] |

### 3.3 Support response times

| Severity | Description | Response time | Resolution target |
|----------|-------------|---------------|-------------------|
| P1 - Critical | Service completely unavailable | [15 minutes] | [1 hour] |
| P2 - High | Service significantly degraded | [30 minutes] | [4 hours] |
| P3 - Medium | Minor functionality impacted | [4 hours] | [1 business day] |
| P4 - Low | Cosmetic or informational | [1 business day] | [5 business days] |

## 4. Measurement methodology

### 4.1 How availability is measured

- Synthetic monitoring probes execute every [10 seconds] from [3 regions]
- A probe failure is recorded when the response code is 5xx or timeout exceeds [5 seconds]
- A "downtime minute" is any 1-minute interval where more than [5%] of probes fail
- Monthly availability = `(total_minutes - downtime_minutes) / total_minutes × 100`

### 4.2 Data source

- Primary: [Provider's monitoring system]
- Secondary: [Third-party monitoring service] (used for dispute resolution)

## 5. Exclusions

The following do NOT count as Downtime for SLA purposes:

1. **Scheduled maintenance** — Communicated at least [72 hours] in advance via [email and status page]
2. **Force majeure** — Natural disasters, war, government actions, pandemic mandates, internet backbone failures verified by third-party sources
3. **Customer-caused issues** — Including but not limited to:
   - Exceeding rate limits
   - Malformed API requests
   - Customer infrastructure failures
   - Failure to implement recommended configurations
4. **Third-party services** — Outages of services not operated by Provider
5. **Preview/beta features** — Services explicitly marked as non-production
6. **Attacks** — DDoS or other security attacks where Provider's mitigation performed as designed

## 6. Service credits

### 6.1 Credit schedule

| Monthly availability achieved | Service credit (% of monthly fee) |
|------------------------------|-----------------------------------|
| [99.0%] – [SLA target] | [10%] |
| [95.0%] – [99.0%] | [25%] |
| [90.0%] – [95.0%] | [50%] |
| Below [90.0%] | [100%] |

### 6.2 Credit limitations

- Maximum credit in any month: [100%] of that month's fee for the affected Service
- Credits are not convertible to cash
- Credits cannot be transferred to other accounts
- Credits expire [12 months] after issuance if unused
- Credits are Customer's sole and exclusive remedy for SLA breaches

### 6.3 Claim process

1. Customer must submit a claim within [30 calendar days] of the incident
2. Claims must include:
   - Affected service and endpoints
   - Date and time of the incident (UTC)
   - Request IDs or transaction IDs (if available)
   - Description of the impact
3. Provider will respond within [5 business days]
4. If validated, credits are applied within [2 billing cycles]

## 7. Provider obligations

- Maintain monitoring infrastructure to measure SLA compliance
- Publish real-time service status at [status page URL]
- Notify Customer of incidents affecting their service within [15 minutes] of detection
- Provide post-incident reports for P1/P2 incidents within [5 business days]
- Publish monthly SLA compliance reports by the [5th business day] of the following month

## 8. Customer obligations

- Submit claims within the required timeframe
- Maintain current contact information for incident notifications
- Follow Provider's recommended configurations and best practices
- Not exceed contracted rate limits or resource allocations
- Report suspected issues promptly via designated support channels

## 9. Reporting

| Report | Frequency | Delivery method |
|--------|-----------|-----------------|
| Real-time status | Continuous | [Status page URL] |
| Incident notifications | As they occur | [Email, webhook] |
| Monthly SLA report | Monthly | [Dashboard, email] |
| Quarterly business review | Quarterly | [Meeting + document] |

## 10. Termination rights

Customer may terminate this Agreement without penalty if:

- Provider breaches the Availability SLA for [3] consecutive months
- A single incident causes more than [24 hours] of continuous Downtime
- Provider fails to deliver post-incident report within [10 business days] for P1 incidents

Upon termination, Customer shall receive a pro-rata refund of prepaid fees for the unused term.

## 11. Amendments

- Provider may improve SLA terms (tighter targets, higher credits) at any time
- Adverse changes require [90 days] written notice to Customer
- Customer may object to adverse changes within [30 days]; if unresolved, Customer may terminate without penalty

## 12. Governing law

This SLA is governed by the laws of [Jurisdiction]. Disputes shall be resolved through [arbitration/mediation/courts] in [Location].

---

**Signatures:**

Provider: _________________________ Date: _________

Customer: _________________________ Date: _________
```

---

## Further reading

- [Google SRE Book — Service Level Objectives](https://sre.google/sre-book/service-level-objectives/)
- [AWS Service Level Agreements](https://aws.amazon.com/legal/service-level-agreements/)
- [The Art of SLOs (Google Cloud)](https://sre.google/resources/practices-and-processes/art-of-slos/)
- [Implementing SLOs](https://www.oreilly.com/library/view/implementing-service-level/9781492076803/)

---

*Last updated: 2025-07-23*
*Maintained by: SRE Team*
*Location: `docs/slo/sla-guide.md`*
