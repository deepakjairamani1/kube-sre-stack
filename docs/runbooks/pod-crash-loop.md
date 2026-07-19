# Runbook: Pod CrashLooping

## Alert: `KubePodCrashLooping`

**Severity:** Warning  
**Impact:** Service degraded — pod restarting repeatedly  
**Response Time:** Within 15 minutes

---

## Triage (1 minute)

```bash
# Identify the crashing pod
kubectl get pods -A | grep -E "CrashLoopBackOff|Error"

# Check restart count and last state
kubectl describe pod <pod-name> -n <namespace> | grep -A 10 "Last State"
```

## Diagnose (5 minutes)

```bash
# Get logs from the PREVIOUS (crashed) container
kubectl logs <pod-name> -n <namespace> --previous --tail=100

# Check events for scheduling/resource issues
kubectl get events -n <namespace> --sort-by='.lastTimestamp' | grep <pod-name>

# Check resource pressure on the node
kubectl top node
kubectl top pods -n <namespace> --sort-by=memory
```

## Common Causes & Fixes

### 1. OOMKilled
```bash
# Confirm: check last termination reason
kubectl get pod <pod-name> -n <namespace> -o jsonpath='{.status.containerStatuses[0].lastState.terminated.reason}'

# Fix: increase memory limits
kubectl patch deployment <name> -n <namespace> --type='json' -p='[{"op":"replace","path":"/spec/template/spec/containers/0/resources/limits/memory","value":"1Gi"}]'
```

### 2. Application Error (bad config, missing dependency)
```bash
# Check logs for stack traces
kubectl logs <pod-name> -n <namespace> --previous | grep -i "error\|exception\|fatal"

# Check if config/secrets are mounted correctly
kubectl exec <pod-name> -n <namespace> -- env | grep -i config
```

### 3. Readiness Probe Failure
```bash
# Check probe config
kubectl get pod <pod-name> -n <namespace> -o jsonpath='{.spec.containers[0].readinessProbe}'

# Test the probe manually
kubectl exec <pod-name> -n <namespace> -- curl -s localhost:<port>/actuator/health
```

### 4. Dependency Not Ready
```bash
# Check if dependent services are up
kubectl get pods -n <namespace> -l app.kubernetes.io/part-of=piggymetrics

# Check service endpoints
kubectl get endpoints -n <namespace>
```

## Mitigation

```bash
# If bad deployment, rollback
kubectl rollout undo deployment/<name> -n <namespace>

# If resource issue, scale down other workloads or add capacity
kubectl scale deployment/<less-critical-service> -n <namespace> --replicas=1
```

## Post-Incident

- [ ] Root cause identified and documented
- [ ] Fix deployed (config change, code fix, or resource adjustment)
- [ ] Monitoring confirmed pod is stable (no restarts for 30+ min)
- [ ] Runbook updated if new failure mode discovered
