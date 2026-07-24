#!/bin/bash
# auto-scale-on-latency.sh
#
# Queries Prometheus for P99 latency per service.
# If latency exceeds threshold, scales up the deployment.
# If latency returns to normal, does NOT scale down (HPA handles that).
#
# This catches cases where HPA (CPU/memory-based) is too slow:
#   - I/O-bound services: CPU stays low but latency spikes
#   - Connection pool exhaustion: need more pods to get more connections
#   - Cold start issues: more replicas = less impact per pod restart
#
# Runs every 2 minutes via CronJob.

set -euo pipefail

NAMESPACE="${NAMESPACE:-piggymetrics}"
PROMETHEUS_URL="${PROMETHEUS_URL:-http://prometheus.observability.svc.cluster.local:9090}"
LATENCY_THRESHOLD_MS="${LATENCY_THRESHOLD_MS:-2000}"  # 2 seconds
SCALE_UP_FACTOR="${SCALE_UP_FACTOR:-2}"               # Double replicas
MAX_REPLICAS="${MAX_REPLICAS:-10}"
SLACK_WEBHOOK="${SLACK_WEBHOOK_URL:-}"
DRY_RUN="${DRY_RUN:-false}"

# Services to monitor (deployment-name:port pairs)
SERVICES="gateway:4000 account-service:6000 auth-service:5000"

log() {
  echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] $1"
}

notify_slack() {
  local message="$1"
  if [[ -n "$SLACK_WEBHOOK" ]]; then
    curl -s -X POST "$SLACK_WEBHOOK" \
      -H 'Content-type: application/json' \
      -d "{\"text\": \"$message\"}" > /dev/null 2>&1
  fi
}

query_prometheus() {
  local query="$1"
  local result
  result=$(curl -s --connect-timeout 5 \
    "${PROMETHEUS_URL}/api/v1/query" \
    --data-urlencode "query=${query}" | \
    python3 -c "import sys,json; data=json.load(sys.stdin); print(data['data']['result'][0]['value'][1] if data['data']['result'] else '0')" 2>/dev/null || echo "0")
  echo "$result"
}

for svc_entry in $SERVICES; do
  service=$(echo "$svc_entry" | cut -d: -f1)

  # Query P99 latency for this service (in seconds)
  p99_query="histogram_quantile(0.99, sum(rate(http_request_duration_seconds_bucket{namespace=\"${NAMESPACE}\", service=\"${service}\"}[5m])) by (le))"
  p99_seconds=$(query_prometheus "$p99_query")
  p99_ms=$(echo "$p99_seconds * 1000" | bc 2>/dev/null || echo "0")
  p99_ms_int=${p99_ms%.*}

  if [[ -z "$p99_ms_int" ]] || [[ "$p99_ms_int" == "0" ]]; then
    log "  ℹ️  $service: No data available (service may not have traffic)"
    continue
  fi

  log "  $service: P99 latency = ${p99_ms_int}ms (threshold: ${LATENCY_THRESHOLD_MS}ms)"

  if [[ "$p99_ms_int" -gt "$LATENCY_THRESHOLD_MS" ]]; then
    # Get current replica count
    current_replicas=$(kubectl get deployment "$service" -n "$NAMESPACE" -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
    target_replicas=$((current_replicas * SCALE_UP_FACTOR))

    # Cap at max
    if [[ "$target_replicas" -gt "$MAX_REPLICAS" ]]; then
      target_replicas=$MAX_REPLICAS
    fi

    # Don't scale if already at target
    if [[ "$current_replicas" -ge "$target_replicas" ]]; then
      log "  ⚠️  $service: Already at $current_replicas replicas (max: $MAX_REPLICAS)"
      continue
    fi

    log "  🚀 SCALING UP: $service from $current_replicas → $target_replicas replicas (P99: ${p99_ms_int}ms)"

    if [[ "$DRY_RUN" == "false" ]]; then
      kubectl scale deployment "$service" -n "$NAMESPACE" --replicas="$target_replicas"
      notify_slack "🚀 *Auto-Scale (Latency)*: Scaled \`$service\` from $current_replicas → $target_replicas replicas.\n\nReason: P99 latency ${p99_ms_int}ms > threshold ${LATENCY_THRESHOLD_MS}ms\nNamespace: \`$NAMESPACE\`"
    else
      log "  → DRY RUN: Would scale $service to $target_replicas replicas"
    fi
  fi
done

log "✅ Latency-based scaling check complete"
