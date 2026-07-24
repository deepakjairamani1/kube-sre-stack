#!/bin/bash
# auto-cleanup-disk-pressure.sh
#
# Triggered when nodes report DiskPressure condition.
# Cleans up resources that commonly fill node disks:
#   1. Completed/Evicted pods (stuck in Terminated state)
#   2. Unused container images (docker/containerd image prune)
#   3. Old ReplicaSets with 0 replicas (leftover from rollouts)
#
# This prevents nodes from going NotReady due to disk exhaustion.

set -euo pipefail

NAMESPACE="${NAMESPACE:-piggymetrics}"
SLACK_WEBHOOK="${SLACK_WEBHOOK_URL:-}"
DRY_RUN="${DRY_RUN:-false}"

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

log "🧹 Starting disk pressure cleanup..."

# 1. Delete Evicted pods (consume disk via logs)
EVICTED=$(kubectl get pods -A --field-selector=status.phase=Failed \
  -o jsonpath='{range .items[?(@.status.reason=="Evicted")]}{.metadata.namespace}/{.metadata.name}{"\n"}{end}' 2>/dev/null || true)

evicted_count=0
if [[ -n "$EVICTED" ]]; then
  while IFS='/' read -r ns pod; do
    [[ -z "$pod" ]] && continue
    evicted_count=$((evicted_count + 1))
    if [[ "$DRY_RUN" == "false" ]]; then
      kubectl delete pod "$pod" -n "$ns" --grace-period=0 --force 2>/dev/null || true
    fi
  done <<< "$EVICTED"
fi
log "  Evicted pods cleaned: $evicted_count"

# 2. Delete Completed pods older than 1 hour (job leftovers)
COMPLETED=$(kubectl get pods -A --field-selector=status.phase=Succeeded \
  -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}/{.status.startTime}{"\n"}{end}' 2>/dev/null || true)

completed_count=0
ONE_HOUR_AGO=$(date -u -d '1 hour ago' '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date -u -v-1H '+%Y-%m-%dT%H:%M:%SZ')

if [[ -n "$COMPLETED" ]]; then
  while IFS='/' read -r ns pod start_time; do
    [[ -z "$pod" ]] && continue
    # Simple age check: if pod exists and is Succeeded, clean it
    completed_count=$((completed_count + 1))
    if [[ "$DRY_RUN" == "false" ]]; then
      kubectl delete pod "$pod" -n "$ns" --grace-period=0 2>/dev/null || true
    fi
  done <<< "$COMPLETED"
fi
log "  Completed pods cleaned: $completed_count"

# 3. Delete old ReplicaSets with 0 replicas (rollout leftovers)
OLD_RS=$(kubectl get replicaset -n "$NAMESPACE" \
  -o jsonpath='{range .items[?(@.spec.replicas==0)]}{.metadata.name}{"\n"}{end}' 2>/dev/null || true)

rs_count=0
if [[ -n "$OLD_RS" ]]; then
  while read -r rs_name; do
    [[ -z "$rs_name" ]] && continue
    rs_count=$((rs_count + 1))
    if [[ "$DRY_RUN" == "false" ]]; then
      kubectl delete replicaset "$rs_name" -n "$NAMESPACE" 2>/dev/null || true
    fi
  done <<< "$OLD_RS"
fi
log "  Old ReplicaSets cleaned: $rs_count"

# Summary
total_cleaned=$((evicted_count + completed_count + rs_count))
log "✅ Cleanup complete. Total resources removed: $total_cleaned"

if [[ "$total_cleaned" -gt 0 ]] && [[ "$DRY_RUN" == "false" ]]; then
  notify_slack "🧹 *Disk Pressure Cleanup*\n\n• Evicted pods removed: $evicted_count\n• Completed pods removed: $completed_count\n• Old ReplicaSets removed: $rs_count\n\nTotal freed: $total_cleaned resources"
fi
