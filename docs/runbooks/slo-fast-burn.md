# Runbook: SLO Fast Burn (14.4x Burn Rate)

## Alert: `SLOAvailabilityFastBurn`

**Severity:** Critical  
**Impact:** Error budget will be exhausted in ~2 hours at this rate  
**Response Time:** Immediately (within 5 minutes)

---

## What This Means

Your API availability SLO (99.9%) is burning error budget at 14.4x the sustainable rate. This means:
- In the last 1 hour AND the last 5 minutes, error rates are >1.44%
- If this continues, your entire monthly error budget (43.8 minutes of downtime) will be consumed in ~2 hours

---

## Triage Steps

### 1. Confirm the Issue (30 seconds)

```bash
# Check current error rate
kubectl exec -n observability prometheus-0 -- \
  promtool query instant http://localhost:9090 \
  'sum(rate(http_requests_total{code=~"5.."}[5m])) / sum(rate(http_requests_total[5m]))'

# Quick health check of all pods
kubectl get pods -A | grep -v Running | grep -v Completed
```

### 2. Identify the Source (2 minutes)

```bash
# Which service has the highest error rate?
kubectl exec -n observability prometheus-0 -- \
  promtool query instant http://localhost:9090 \
  'topk(5, sum by(service, namespace) (rate(http_requests_total{code=~"5.."}[5m])))'

# Recent deployments (most common cause)
kubectl get events -A --sort-by='.lastTimestamp' | grep -i "scaled\|rolling\|created" | tail -20

# ArgoCD sync history
kubectl get applications -n argocd -o wide
```

### 3. Check Recent Changes (2 minutes)

```bash
# Last ArgoCD syncs
kubectl get applications -n argocd -o jsonpath='{range .items[*]}{.metadata.name}: {.status.sync.revision}{"\n"}{end}'

# Recent config changes
kubectl get events -A --field-selector reason=Updated --sort-by='.lastTimestamp' | tail -10
```

### 4. Check Dependencies (1 minute)

```bash
# Database connectivity
kubectl exec -n <app-namespace> <pod-name> -- curl -s http://localhost:8080/health/db

# External service health
kubectl get servicemonitor -A
kubectl exec -n observability prometheus-0 -- \
  promtool query instant http://localhost:9090 'probe_success{job="blackbox"}'
```

---

## Mitigation Actions

### If caused by a bad deployment:

```bash
# Rollback ArgoCD application
kubectl patch application <app-name> -n argocd --type merge -p '{"spec":{"source":{"targetRevision":"<previous-sha>"}}}'

# Or rollback Kubernetes deployment directly
kubectl rollout undo deployment/<name> -n <namespace>

# Verify rollback
kubectl rollout status deployment/<name> -n <namespace>
```

### If caused by dependency failure:

```bash
# Enable circuit breaker (if using Istio/Envoy)
kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: circuit-breaker-<service>
spec:
  host: <service>
  trafficPolicy:
    outlierDetection:
      consecutive5xxErrors: 3
      interval: 30s
      baseEjectionTime: 60s
EOF
```

### If caused by traffic spike:

```bash
# Scale up immediately
kubectl scale deployment/<name> -n <namespace> --replicas=<higher-number>

# Or trigger HPA if configured
kubectl patch hpa <name> -n <namespace> --type merge -p '{"spec":{"maxReplicas":<higher-number>}}'
```

---

## Post-Incident

1. **Create incident ticket** with timeline of events
2. **Write blameless post-mortem** within 48 hours
3. **Update this runbook** if new failure mode discovered
4. **Review error budget** — consider deployment freeze if <25% remaining

---

## Escalation

| Time Since Alert | Action |
|-----------------|--------|
| 0-5 min | On-call acknowledges, begins triage |
| 5-15 min | Root cause identified OR escalate to secondary |
| 15-30 min | Mitigation applied OR escalate to engineering lead |
| 30+ min | Incident commander engaged, all-hands if needed |

---

## Related Alerts

- `SLOAvailabilityMediumBurn` — 6x rate, less urgent
- `SLOErrorBudgetNearlyExhausted` — <10% budget remaining
- `HighHTTPErrorRateCritical` — raw error rate threshold

---

## Dashboard

[SLO Overview Dashboard](https://grafana.example.com/d/slo-overview)
