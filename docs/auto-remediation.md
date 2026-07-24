# Auto-Remediation Architecture

## Overview

Automated incident response that handles common failures without human intervention, reducing MTTR from ~45 minutes to ~5 minutes for known failure patterns.

```
┌──────────────────────────────────────────────────────────────┐
│                  AUTO-REMEDIATION SYSTEM                       │
│                                                              │
│  ┌────────────────┐    ┌─────────────────┐    ┌──────────┐  │
│  │   DETECT       │───▶│    DECIDE        │───▶│   ACT    │  │
│  │                │    │                  │    │          │  │
│  │ • CronJob poll │    │ • Threshold      │    │ • Delete │  │
│  │ • Prometheus   │    │   check          │    │   pod    │  │
│  │   metrics      │    │ • Escalation     │    │ • Scale  │  │
│  │ • Pod status   │    │   logic          │    │   up     │  │
│  │                │    │ • Max attempts    │    │ • Clean  │  │
│  └────────────────┘    └─────────────────┘    │   up     │  │
│                                                │ • Notify │  │
│                              ┌─────────┐       └──────────┘  │
│                              │ ESCALATE│                      │
│                              │         │                      │
│                              │ Slack + │                      │
│                              │ human   │                      │
│                              └─────────┘                      │
└──────────────────────────────────────────────────────────────┘
```

## Remediation Actions

| Trigger | Action | Escalation | CronJob |
|---------|--------|------------|---------|
| CrashLoopBackOff (< 10 restarts) | Delete pod (K8s recreates) | — | Every 5 min |
| CrashLoopBackOff (≥ 10 restarts) | Slack alert for human | Manual investigation | Every 5 min |
| P99 latency > 2 seconds | Scale deployment 2x | — | Every 2 min |
| Disk pressure (evicted pods) | Clean evicted + completed pods | — | Every 15 min |
| Old ReplicaSets (0 replicas) | Delete stale ReplicaSets | — | Every 15 min |

## Safety Guardrails

1. **MAX_REPLICAS cap** — Scaling never exceeds configured maximum (prevents runaway costs)
2. **Escalation threshold** — After N failures, stops auto-remediating and pages a human
3. **DRY_RUN mode** — All scripts support dry-run for safe testing
4. **Namespace-scoped RBAC** — CronJobs can only affect their own namespace
5. **ConcurrencyPolicy: Forbid** — Prevents parallel remediation (avoids race conditions)
6. **Slack notifications** — Every action is logged and reported (full audit trail)
7. **activeDeadlineSeconds** — Jobs timeout if they run too long (prevents stuck jobs)

## How This Reduces MTTR

### Before (Manual Response)
```
Alert fires → Engineer wakes up → Opens laptop → Checks dashboards →
Identifies issue → Runs kubectl → Verifies fix → Goes back to sleep
Total: 15-45 minutes
```

### After (Auto-Remediation)
```
Alert fires → CronJob detects → Remediates → Slack confirms →
Engineer reviews in morning
Total: 2-5 minutes (for known patterns)
```

### What's NOT automated (requires human judgment)
- Data corruption issues
- Multi-service cascading failures
- Security incidents
- Capacity planning decisions
- Unknown/novel failure modes

## Directory Structure

```
k8s/auto-remediation/
├── scripts/
│   ├── auto-restart-crashloop.sh     # Pod restart logic
│   ├── auto-scale-on-latency.sh      # Prometheus-driven scaling
│   └── auto-cleanup-disk-pressure.sh # Garbage collection
├── cronjobs/
│   ├── crashloop-handler.yaml        # Every 5 min
│   └── latency-scaler.yaml           # Every 2 min
└── rbac/
    └── service-account-and-role.yaml  # Least-privilege access
```

## Adding a New Remediation

1. Write a script in `scripts/` (follow existing pattern: detect → decide → act → notify)
2. Create a CronJob in `cronjobs/` (set appropriate schedule)
3. Update RBAC if new permissions needed
4. Test with `DRY_RUN=true` first
5. Add to this documentation
6. Commit → ArgoCD deploys

## Metrics Exposed

The remediation system generates events that can be tracked:
- `auto_remediation_actions_total{type="restart|scale|cleanup"}` — Counter per action type
- `auto_remediation_escalations_total` — How often humans are paged
- Track via pod logs → Loki → Grafana dashboard
