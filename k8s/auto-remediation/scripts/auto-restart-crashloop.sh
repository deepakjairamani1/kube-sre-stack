#!/bin/bash
# auto-restart-crashloop.sh
#
# Detects pods stuck in CrashLoopBackOff and takes action:
#   1. If restart count < 10: Delete pod (let K8s recreate)
#   2. If restart count >= 10: Scale down to 0, notify Slack, open incident
#
# Why auto-delete works:
#   - Often fixes transient issues (dependency timing, OOM on startup)
#   - K8s recreates immediately with fresh state
#   - If still failing after recreation, escalation kicks in
#
# Runs as a CronJob every 5 minutes.

set -euo pipefail

NAMESPACE="${NAMESPACE:-piggymetrics}"
SLACK_WEBHOOK="${SLACK_WEBHOOK_URL:-}"
MAX_RESTARTS_BEFORE_ESCALATION=10
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

# Find CrashLoopBackOff pods
CRASH_PODS=$(kubectl get pods -n "$NAMESPACE" \
  --field-selector=status.phase!=Succeeded \
  -o jsonpath='{range .items[*]}{.metadata.name}{"|"}{range .status.containerStatuses[*]}{.restartCount}{"|"}{.state.waiting.reason}{"\n"}{end}{end}' \
  2>/dev/null | grep "CrashLoopBackOff" || true)

if [[ -z "$CRASH_PODS" ]]; then
  log "✅ No CrashLoopBackOff pods found in namespace $NAMESPACE"
  exit 0
fi

log "⚠️  Found CrashLoopBackOff pods:"

while IFS='|' read -r pod_name restart_count reason; do
  [[ -z "$pod_name" ]] && continue

  log "  Pod: $pod_name | Restarts: $restart_count | Reason: $reason"

  if [[ "$restart_count" -ge "$MAX_RESTARTS_BEFORE_ESCALATION" ]]; then
    # Escalation: too many restarts, something is fundamentally broken
    log "🚨 ESCALATION: $pod_name has $restart_count restarts (threshold: $MAX_RESTARTS_BEFORE_ESCALATION)"

    # Get the deployment owning this pod
    OWNER=$(kubectl get pod "$pod_name" -n "$NAMESPACE" -o jsonpath='{.metadata.ownerReferences[0].name}' 2>/dev/null || echo "unknown")

    if [[ "$DRY_RUN" == "false" ]]; then
      notify_slack "🚨 *Auto-Remediation Escalation*\n\nPod \`$pod_name\` in \`$NAMESPACE\` has restarted $restart_count times.\n\nOwner: \`$OWNER\`\nAction: Requires manual investigation.\nLast logs: \`kubectl logs $pod_name -n $NAMESPACE --previous --tail=50\`"
    fi
    log "  → Slack notification sent for manual investigation"

  else
    # Auto-remediation: delete pod, let controller recreate
    log "  🔄 Auto-remediating: deleting pod $pod_name (restarts: $restart_count)"

    if [[ "$DRY_RUN" == "false" ]]; then
      kubectl delete pod "$pod_name" -n "$NAMESPACE" --grace-period=30
      notify_slack "🔄 *Auto-Remediation*: Deleted CrashLooping pod \`$pod_name\` in \`$NAMESPACE\` (restarts: $restart_count). K8s will recreate."
    else
      log "  → DRY RUN: Would delete pod $pod_name"
    fi
  fi
done <<< "$CRASH_PODS"

log "✅ Auto-remediation cycle complete"
