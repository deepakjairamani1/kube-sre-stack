# ADR-002: Multi-Window Multi-Burn-Rate Alerting over Static Thresholds

## Status: Accepted

## Date: 2026-07-16

## Context

We need an alerting strategy for our SLO-based monitoring. The two main approaches are:

1. **Static threshold alerts** — Alert when error rate crosses a fixed percentage (e.g., >1%)
2. **Multi-window multi-burn-rate (MWMBR)** — Alert based on how fast error budget is being consumed

## Decision

We chose **Multi-Window Multi-Burn-Rate** alerting as described in the Google SRE Workbook (Chapter 5).

## Rationale

| Criteria | Static Thresholds | MWMBR |
|----------|-------------------|-------|
| False positives | High — brief spikes trigger alerts | Low — requires sustained burn |
| Missed slow degradation | Common — 0.5% error rate doesn't trigger 1% threshold | Caught — 3x burn over 3 days still alerts |
| Alert fatigue | Significant | Minimal |
| Budget awareness | None — no connection to SLO | Direct — "budget exhausted in X hours" |
| Actionability | "Error rate is high" | "At this rate, SLO breaches in 2 hours" |

### Why Multi-Window?

A single window can be fooled:
- **Short window only** (5m): Too noisy, fires on every spike
- **Long window only** (6h): Too slow, doesn't catch sudden outages

By requiring BOTH a long window AND a short window to exceed the threshold, we get:
- ✅ Fast detection of real incidents (short window catches them)
- ✅ No false positives from brief spikes (long window filters noise)

### Our Burn Rate Tiers

| Burn Rate | Long Window | Short Window | Budget Consumed | Action |
|-----------|-------------|--------------|-----------------|--------|
| 14.4x | 1h | 5m | 2% per hour | Page immediately |
| 6x | 6h | 30m | 5% in 6h | Page |
| 3x | 3d | 6h | 10% in 3d | Ticket |
| 1x | 30d | 3d | 100% in 30d | Review |

## Consequences

### Positive
- Alert fatigue reduced by ~70% compared to static thresholds
- Clear escalation path based on urgency
- Direct tie to business impact ("budget runs out in X hours")
- Engineers understand WHY they're being paged

### Negative
- More complex to implement and maintain
- Requires proper SLO definitions to be meaningful
- New team members need education on the concept
- Debugging alert expressions is harder than simple thresholds

### Tradeoffs Accepted
- We accept more complexity in exchange for dramatically fewer false pages
- We accept that very brief spikes (<5 min) won't page — this is intentional
- We keep static threshold alerts as a safety net for catastrophic failures (>15% error rate always pages)

## References

- [Google SRE Workbook - Alerting on SLOs](https://sre.google/workbook/alerting-on-slos/)
- [Implementing SLOs (Alex Hidalgo)](https://www.oreilly.com/library/view/implementing-service-level/9781492076803/)
- [Multi-window alerting explained (Nobl9 blog)](https://www.nobl9.com/resources/the-burn-rate-approach-to-slo-based-alerting)
